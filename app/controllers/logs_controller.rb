class LogsController < ApplicationController
    require "prawn"
    require "prawn/table"
    require_relative "../services/invoice_generator"

    def create
      p = log_params.to_h
      p[:tasks] = JSON.parse(p[:tasks]) rescue p[:tasks] if p[:tasks].is_a?(String)
      p[:credits] = JSON.parse(p[:credits]) rescue p[:credits] if p[:credits].is_a?(String)

      @log = Log.new(p)
      profile = Profile.first || Profile.new
      @log.billing_mode = profile.billing_mode || "hourly" if @log.billing_mode.blank?

      # Default tax scope (if not provided by frontend)
      @log.tax_scope = profile.tax_scope if @log.tax_scope.blank?

      if @log.save
        respond_to do |format|
          format.json { render json: { success: true } }
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
      @log = Log.find(params[:id])
      @log.destroy
      redirect_to history_path
    end

    def clear_all
      Log.destroy_all
      redirect_to history_path
    end



    def download_pdf
      log = Log.find(params[:id])
      profile = Profile.first || Profile.new(business_name: "My Business", hourly_rate: 0)

      pdf_data = InvoiceGenerator.new(log, profile).render

      send_data pdf_data, filename: "INV-#{1000 + log.id}_#{log.client}.pdf", type: "application/pdf", disposition: "inline"
    end

    def preview_pdf
      style = params[:style] || "professional"

      # No caching to prevent binary corruption issues
      profile = Profile.first || Profile.new(
        business_name: "TalkInvoice Demo",
        phone: "555-0123",
        email: "demo@talkinvoice.com",
        address: "123 Innovation Dr, Tech City",
        hourly_rate: 100,
        currency: "USD",
        tax_rate: 10,
        payment_instructions: "Please pay via Bank Transfer to Account #123456789"
      )
      profile.invoice_style = style

      # Dummy Log Data
      log = Log.new(
        id: 999,
        client: "Acme Corp",
        time: "4.5",
        date: Date.today.strftime("%b %d, %Y"),
        due_date: (Date.today + 14).strftime("%b %d, %Y"),
        billing_mode: "hourly",
        tax_scope: "all",
        labor_taxable: true,
        currency: profile.currency,
        hourly_rate: profile.hourly_rate,
        tasks: [
          { "title" => "Labor", "items" => [
            { "desc" => "Initial Site Consultation", "qty" => "1.5", "price" => "150.0", "taxable" => true },
            { "desc" => "Installation Work", "qty" => "3.0", "price" => "300.0", "taxable" => true }
          ] },
          { "title" => "Materials", "items" => [
            { "desc" => "High-grade Sensor", "qty" => "2", "price" => "200.0", "taxable" => true },
            { "desc" => "Cabling & Fixtures", "qty" => "1", "price" => "75.50", "taxable" => true }
          ] },
          { "title" => "Field Notes", "items" => [
             "checked voltage levels - all nominal",
             "customer requested follow-up next week"
          ] }
        ].to_json
      )

      pdf_data = InvoiceGenerator.new(log, profile).render

      send_data pdf_data, filename: "preview_#{style}.pdf", type: "application/pdf", disposition: "inline"
    end

    # Multi-page test endpoint for verifying pagination
    def preview_pdf_multipage
      style = params[:style] || "professional"

      profile = Profile.first || Profile.new(
        business_name: "TalkInvoice Demo",
        phone: "555-0123",
        email: "demo@talkinvoice.com",
        address: "123 Innovation Dr, Tech City",
        hourly_rate: 100,
        currency: "USD",
        tax_rate: 10,
        payment_instructions: "Please pay via Bank Transfer to Account #123456789"
      )
      profile.invoice_style = style

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

      pdf_data = InvoiceGenerator.new(log, profile).render

      send_data pdf_data, filename: "preview_multipage_#{style}.pdf", type: "application/pdf", disposition: "inline"
    end

    def generate_preview
      p = log_params.to_h
      p[:tasks] = JSON.parse(p[:tasks]) rescue p[:tasks] if p[:tasks].is_a?(String)
      p[:credits] = JSON.parse(p[:credits]) rescue p[:credits] if p[:credits].is_a?(String)

      # Extract currency and billing mode from top level if needed
      # but they should be in log_params

      log = Log.new(p)
      profile = Profile.first || Profile.new
      log.billing_mode = profile.billing_mode || "hourly" if log.billing_mode.blank?
      log.tax_scope = profile.tax_scope if log.tax_scope.blank?

      pdf_data = InvoiceGenerator.new(log, profile).render

      send_data pdf_data, filename: "Preview.pdf", type: "application/pdf", disposition: "inline"
    end

    private

    def log_params
      params.require(:log).permit(:client, :time, :date, :due_date, :tasks, :credits, :billing_mode, :discount_tax_rule, :tax_scope, :labor_taxable, :labor_discount_flat, :labor_discount_percent, :global_discount_flat, :global_discount_percent, :global_discount_message, :credit_flat, :credit_reason, :currency, :hourly_rate)
    end
end
