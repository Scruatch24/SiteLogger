class LogsController < ApplicationController
    require "prawn"
    require "prawn/table"
    require_relative "../services/invoice_generator"

    def create
      p = log_params.to_h
      p[:tasks] = JSON.parse(p[:tasks]) rescue p[:tasks] if p[:tasks].is_a?(String)
      p[:credits] = JSON.parse(p[:credits]) rescue p[:credits] if p[:credits].is_a?(String)

      @log = Log.new(p)
      @log.user = current_user if user_signed_in?

      profile = @profile # using the one from HomeController before_filter or set manually
      if !user_signed_in?
        profile = Profile.where(user_id: nil).first || Profile.new

        # Set guest IP for ID scoping
        @log.ip_address = request.remote_ip
        @log.session_id = params[:session_id]

        Rails.logger.info "Checking Guest Limit: IP=#{request.remote_ip}, Session=#{params[:session_id]}"

        # Guest limit: 2 per IP OR per Session per day (Counts ALL logs created, including discarded ones)
        limit = Profile::EXPORT_LIMITS["guest"] || 2

        # Check by IP
        count_ip = Log.where(user_id: nil, ip_address: request.remote_ip)
                      .where("created_at > ?", 24.hours.ago)
                      .count

        # Check by Session ID (Stronger than IP)
        count_session = 0
        if params[:session_id].present? && params[:session_id] != "null"
           count_session = Log.where(user_id: nil, session_id: params[:session_id])
                              .where("created_at > ?", 24.hours.ago)
                              .count
        end

        if count_ip >= limit || count_session >= limit
           Rails.logger.info "Limit HIT: IP Count=#{count_ip}, Session Count=#{count_session}"
           return render json: { status: "error", success: false, message: "Rate limit reached", errors: [ "Guest limit reached (2 per day). Signup to unlock!" ] }, status: :too_many_requests
        end
      end
      @log.billing_mode = profile.billing_mode || "hourly" if @log.billing_mode.blank?

      # Default tax scope (if not provided by frontend)
      @log.tax_scope = profile.tax_scope if @log.tax_scope.blank?

      # Persist appearance settings from profile to the log
      if @log.accent_color.blank? || @log.accent_color == "#EA580C"
        @log.accent_color = profile.accent_color
      end

      if @log.save
        respond_to do |format|
          format.json { render json: { success: true, id: @log.id, display_number: @log.display_number, client: @log.client } }
          format.html { redirect_to history_path }
        end
      else
        respond_to do |format|
          format.json { render json: { success: false, errors: @log.errors.full_messages }, status: :unprocessable_entity }
          format.html {
            flash[:alert] = @log.errors.full_messages.join(", ")
            redirect_to root_path
          }
        end
      end
    end

    def destroy
      @log = if user_signed_in?
        current_user.logs.kept.find(params[:id])
      else
        Log.kept.where(user_id: nil, ip_address: request.remote_ip).find(params[:id])
      end
      @log.discard
      redirect_to history_path
    end

    def update_entry
      @log = if user_signed_in?
        current_user.logs.kept.find(params[:id])
      else
        Log.kept.where(user_id: nil, ip_address: request.remote_ip).find(params[:id])
      end

      # Rule: Paid invoices should be locked: no RENAME available
      if @log.status == "paid" && params[:field] == "client"
        return render json: { success: false, errors: [ "Paid invoices are locked and cannot be renamed." ] }, status: :forbidden
      end

      field = params[:field]
      value = params[:value]

      case field
      when "client"
        @log.client = value
      when "item"
        s_idx = params[:section_index].to_i
        i_idx = params[:item_index].to_i

        # Load tasks safely
        tasks = @log.tasks.is_a?(String) ? JSON.parse(@log.tasks || "[]") : (@log.tasks || [])

        if tasks[s_idx] && tasks[s_idx]["items"] && tasks[s_idx]["items"][i_idx]
          item = tasks[s_idx]["items"][i_idx]
          if item.is_a?(Hash)
            item["desc"] = value
          else
            # If it's a string item
            tasks[s_idx]["items"][i_idx] = value
          end
          # Save back
          @log.tasks = tasks
        end
      when "subcategory"
        s_idx = params[:section_index].to_i
        i_idx = params[:item_index].to_i
        sub_idx = params[:subcategory_index].to_i

        tasks = @log.tasks.is_a?(String) ? JSON.parse(@log.tasks || "[]") : (@log.tasks || [])

        if tasks[s_idx] && tasks[s_idx]["items"] && tasks[s_idx]["items"][i_idx]
          item = tasks[s_idx]["items"][i_idx]
          if item.is_a?(Hash) && item["sub_categories"].is_a?(Array)
             item["sub_categories"][sub_idx] = value
             @log.tasks = tasks
          end
        end
      when "credit"
        c_idx = params[:credit_index].to_i
        credits = @log.credits.is_a?(String) ? JSON.parse(@log.credits || "[]") : (@log.credits || [])
        if credits[c_idx]
          credits[c_idx]["reason"] = value
          @log.credits = credits
        end
      end

      if @log.save
        render json: { success: true }
      else
        render json: { success: false, errors: @log.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update_status
      @log = if user_signed_in?
        current_user.logs.kept.find(params[:id])
      else
        Log.kept.where(user_id: nil, ip_address: request.remote_ip).find(params[:id])
      end

      status = params[:status]
      if Log::STATUSES.include?(status)
        @log.status = status
        if @log.save
          render json: { success: true }
        else
          render json: { success: false, errors: @log.errors.full_messages }, status: :unprocessable_entity
        end
      else
        render json: { success: false, errors: [ "Invalid status" ] }, status: :unprocessable_entity
      end
    end

    def update_categories
      @log = if user_signed_in?
        current_user.logs.kept.find(params[:id])
      else
        Log.kept.where(user_id: nil, ip_address: request.remote_ip).find(params[:id])
      end

      category_ids = params[:category_ids] || []
      @log.category_ids = category_ids
      @log.pinned = params[:pinned] if params.has_key?(:pinned)

      if @log.save
        render json: { success: true }
      else
        render json: { success: false, errors: @log.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def bulk_update_categories
      log_ids = params[:log_ids] || []
      added_ids = (params[:added_category_ids] || []).map(&:to_i)
      removed_ids = (params[:removed_category_ids] || []).map(&:to_i)
      # pinned_action is no longer handled here, use bulk_pin instead

      logs = if user_signed_in?
        current_user.logs.kept.where(id: log_ids)
      else
        Log.kept.where(user_id: nil, ip_address: request.remote_ip, id: log_ids)
      end

      errors = []
      logs.each do |log|
        # Add categories if not already present
        new_ids = log.category_ids + added_ids
        # Remove categories if present
        new_ids = new_ids - removed_ids
        log.category_ids = new_ids.uniq

        unless log.save
          errors << { id: log.id, errors: log.errors.full_messages }
        end
      end

      if errors.empty?
        render json: { success: true }
      else
        render json: { success: false, errors: errors }, status: :unprocessable_entity
      end
    end

    def bulk_pin
      log_ids = params[:log_ids] || []
      category_id = params[:category_id] # nil for global, ID for category
      should_pin = params[:pin] == true

      if user_signed_in?
        current_user.logs.kept.where(id: log_ids)
      else
        Log.kept.where(user_id: nil, ip_address: request.remote_ip, id: log_ids)
      end

      if category_id.present?
        # Category-specific pinning
        # Process sequentialy to ensure distinct timestamps based on selection order
        logs_ordered = log_ids.map { |id| Log.find(id) }
        logs_ordered.each_with_index do |log, index|
          assignment = LogCategoryAssignment.find_or_create_by(log_id: log.id, category_id: category_id)
          # Add micro-delay to ensure database timestamps are distinct if needed,
          # but usually Time.current is enough if processed in a loop.
          # Explicitly setting slightly different times to be safe for sorting.
          ts = should_pin ? (Time.current + index.seconds) : nil
          assignment.update(pinned_at: ts)
        end
      else
        # Global pinning
        logs_ordered = log_ids.map { |id| Log.find(id) }
        logs_ordered.each_with_index do |log, index|
          ts = should_pin ? (Time.current + index.seconds) : nil
          log.update(pinned: should_pin, pinned_at: ts)
        end
      end

      render json: { success: true }
    end

    def clear_all
      if user_signed_in?
        current_user.logs.kept.update_all(deleted_at: Time.current)
      else
        Log.kept.where(user_id: nil, ip_address: request.remote_ip).update_all(deleted_at: Time.current)
      end
      redirect_to history_path
    end



    def download_pdf
      log = if user_signed_in?
        current_user.logs.kept.find(params[:id])
      else
        Log.kept.where(user_id: nil, ip_address: request.remote_ip).find(params[:id])
      end

      profile = if log.user
        log.user.profile || Profile.new(business_name: "My Business", hourly_rate: 0)
      else
        Profile.where(user_id: nil).first || Profile.new(business_name: "My Business", hourly_rate: 0)
      end

      generator = InvoiceGenerator.new(log, profile)
      pdf_data = generator.render
      response.headers["X-PDF-Pages"] = generator.page_count.to_s
      send_data pdf_data, filename: "INV-#{log.display_number}_#{log.client}.pdf", type: "application/pdf", disposition: "inline"
    end

    def preview_pdf
      set_preview_profile
      style = params[:style] || @profile.invoice_style || "classic"
      @profile.invoice_style = style
      profile = @profile

      # Rich Dummy Log Data showcasing ALL features
      log = Log.new(
        id: 1248,
        client: "Stark Industries - R&D Wing",
        time: "12.5",
        date: Date.today.strftime("%b %d, %Y"),
        due_date: (Date.today + 30).strftime("%b %d, %Y"),
        billing_mode: "hourly",
        tax_scope: "labor,materials_only,fees_only",
        labor_taxable: true,
        currency: profile.currency,
        hourly_rate: profile.hourly_rate,
        global_discount_percent: 5.0,
        global_discount_message: "Preferred Client Discount",
        accent_color: params[:accent_color].presence || profile.accent_color,
        credits: [
          { "reason" => "Initial Deposit Paid", "amount" => "500.00" },
          { "reason" => "Referral Credit", "amount" => "50.00" }
        ].to_json,
        tasks: [
          {
            "title" => "Labor & Services",
            "items" => [
              {
                "desc" => "Security System Calibration",
                "price" => "4.5",
                "mode" => "hourly",
                "taxable" => true,
                "discount_percent" => 10,
                "discount_message" => "First hour free promo",
                "currency" => profile.currency,
                "hourly_rate" => profile.hourly_rate,
                "tax_rate" => profile.tax_rate,
                "labor_taxable" => true,
                "global_discount_flat" => 0,
                "sub_categories" => [ "Biometric sync check", "Latency optimization" ]
              },
              { "desc" => "Emergency Response Setup", "price" => "250.0", "mode" => "fixed", "taxable" => true }
            ]
          },
          {
            "title" => "Hardware & Materials",
            "items" => [
              { "desc" => "Shielded Signal Cabling (ft)", "qty" => "50", "price" => "2.50", "taxable" => true, "discount_flat" => 25.0 }
            ]
          },
          {
            "title" => "Project Expenses",
            "items" => [
              { "desc" => "Express Site Logistics", "qty" => "1", "price" => "45.00", "taxable" => false }
            ]
          },
          {
            "title" => "Fees",
            "items" => [
              { "desc" => "Hazardous Disposal Fee", "qty" => "1", "price" => "120.00", "taxable" => true },
              { "desc" => "Mandatory City Permit", "qty" => "1", "price" => "75.00", "taxable" => true }
            ]
          },
          {
            "title" => "Technical Field Notes",
            "items" => [
              "Fiber optic link established at 10Gbps",
              "Backup batteries tested and cycled (100% health)",
              "Master control panel firmware updated to v4.2"
            ]
          }
        ].to_json
      )

      generator = InvoiceGenerator.new(log, profile)
      pdf_data = generator.render
      response.headers["X-PDF-Pages"] = generator.page_count.to_s
      send_data pdf_data, filename: "preview_#{style}.pdf", type: "application/pdf", disposition: "inline"
    end

    # Multi-page test endpoint for verifying pagination
    def preview_pdf_multipage
      set_preview_profile
      style = params[:style] || @profile.invoice_style || "classic"
      @profile.invoice_style = style
      profile = @profile

      # Generate 40+ items for multi-page testing
      material_items = (1..35).map do |i|
        { "desc" => "Material Item ##{i} - Extended description to test text wrapping behavior in PDF",
          "qty" => (rand(1..5)).to_s,
          "price" => (rand(10..200).to_f + rand(0..99)/100.0).to_s,
          "taxable" => i.odd? }
      end

      expense_items = (1..10).map do |i|
        { "desc" => "Expense Item ##{i} - Service charge",
          "qty" => "1",
          "price" => (rand(50..300).to_f).to_s,
          "taxable" => true }
      end

      field_notes = (1..15).map do |i|
        "Field note ##{i}: Checked system component and verified operation"
      end

      log = Log.new(
        id: 9999,
        client: "Multi-Page Test Client",
        time: "8.5",
        date: Date.today.strftime("%b %d, %Y"),
        due_date: (Date.today + 14).strftime("%b %d, %Y"),
        billing_mode: "hourly",
        tax_scope: "all",
        labor_taxable: true,
        currency: profile.currency,
        hourly_rate: profile.hourly_rate,
        global_discount_percent: 5,
        credit_flat: 50,
        credit_reason: "Loyalty discount",
        accent_color: params[:accent_color].presence || profile.accent_color,
        tasks: [
          { "title" => "Labor", "items" => [
            { "desc" => "Initial Site Consultation", "qty" => "2", "price" => "0", "taxable" => false },
            { "desc" => "Installation and Configuration", "qty" => "4", "price" => "0", "taxable" => false },
            { "desc" => "Testing and Quality Assurance", "qty" => "2.5", "price" => "0", "taxable" => false }
          ] },
          { "title" => "Materials", "items" => material_items },
          { "title" => "Expenses", "items" => expense_items },
          { "title" => "Field Notes", "items" => field_notes }
        ].to_json
      )

      generator = InvoiceGenerator.new(log, profile)
      pdf_data = generator.render
      response.headers["X-PDF-Pages"] = generator.page_count.to_s
      send_data pdf_data, filename: "preview_multipage_#{style}.pdf", type: "application/pdf", disposition: "inline"
    end

    def generate_preview
      # Ensure schema is fresh to avoid missing column errors
      Log.reset_column_information

      begin
        p = log_params.to_h
        p[:tasks] = JSON.parse(p[:tasks]) rescue p[:tasks] if p[:tasks].is_a?(String)
        p[:credits] = JSON.parse(p[:credits]) rescue p[:credits] if p[:credits].is_a?(String)

        set_preview_profile
        profile = @profile

        if params[:log_id].present? && params[:log_id] != "null"
          log_id = params[:log_id].to_i
          log = if user_signed_in?
            current_user.logs.kept.find_by(id: log_id)
          else
            # Guest Security Fix: Ensure we ONLY load logs that match IP or Session
            # AND explicitly filter out deleted ones using kept
            Log.kept.where(user_id: nil)
               .where("ip_address = ? OR session_id = ?", request.remote_ip, params[:session_id])
               .find_by(id: log_id)
          end

          if log
            log.assign_attributes(p)
          else
            # Fallback if ID provided but not found
            log = Log.new(p)
            log.user = current_user if user_signed_in?
            log.id = log_id
          end
        else
          log = Log.new(p)
          log.user = current_user if user_signed_in?
          if !user_signed_in?
            log.ip_address = request.remote_ip
            log.session_id = params[:session_id]
          end
        end

        if log.accent_color.blank? || log.accent_color == "#EA580C"
          log.accent_color = profile.accent_color
        end
        log.billing_mode = profile.billing_mode || "hourly" if log.billing_mode.blank?
        log.tax_scope = profile.tax_scope if log.tax_scope.blank?

        generator = InvoiceGenerator.new(log, profile)
        pdf_data = generator.render
        response.headers["X-PDF-Pages"] = generator.page_count.to_s
        response.headers["X-INV-No"] = log.display_number.to_s
        send_data pdf_data, filename: "Preview.pdf", type: "application/pdf", disposition: "inline"
      rescue => e
        Rails.logger.error "Generate Preview Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        # Fallback error response for the client
        render json: { error: e.message }, status: :internal_server_error
      end
    end

    def set_preview_profile
      # Use the global @profile (set in ApplicationController), but ensure it has rich dummy data for the preview if it's a guest
      unless @profile.persisted?
        @profile.business_name = "Titan Automation Solutions"
        @profile.phone = "+1 (555) 042-9988"
        @profile.email = "billing@titan-auto.com"
        @profile.address = "742 Evergreen Terrace\nSuite 101\nSpringfield, IL 62704"
        @profile.tax_id = "EIN-99-8877665"
        @profile.hourly_rate = 125 if @profile.hourly_rate.blank?
        @profile.currency = "USD" if @profile.currency.blank?
        @profile.tax_rate = 8.5 if @profile.tax_rate.blank?
        @profile.payment_instructions = "Please remit payment within 14 days.\nZelle: payments@titan-auto.com\nWire: First National Bank (Routing: 00001234)"
      end
    end

    def log_params
      params.require(:log).permit(:client, :time, :date, :due_date, :tasks, :credits, :billing_mode, :discount_tax_rule, :tax_scope, :labor_taxable, :labor_discount_flat, :labor_discount_percent, :global_discount_flat, :global_discount_percent, :global_discount_message, :credit_flat, :credit_reason, :currency, :hourly_rate, :accent_color, :raw_summary, :tax_rate, :status, :session_id, category_ids: [])
    end
end
