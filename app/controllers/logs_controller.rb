class LogsController < ApplicationController
    require "prawn"
    require "prawn/table"
    require_relative "../services/invoice_generator"

    def create
      @log = Log.new(log_params)
      profile = Profile.first || Profile.new
      @log.billing_mode = profile.billing_mode || "hourly"

      # Default tax scope (if not provided by frontend)
      @log.tax_scope = profile.tax_scope if @log.tax_scope.blank?

      if @log.save
        render json: { success: true }
      else
        render json: { success: false, errors: @log.errors.full_messages }, status: :unprocessable_entity
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

    def _deprecated_download_pdf
      log = Log.find(params[:id])
      profile = Profile.first || Profile.new(business_name: "My Business", hourly_rate: 0)

      pdf = Prawn::Document.new(page_size: "A4", margin: 40)
      font_path = Rails.root.join("app/assets/fonts")

      # Register Noto Sans which supports the Lari (₾) symbol
      if File.exist?(font_path.join("NotoSans-Regular.ttf"))
        pdf.font_families.update("NotoSans" => {
          normal: font_path.join("NotoSans-Regular.ttf"),
          bold: font_path.join("NotoSans-Bold.ttf")
        })
        pdf.font "NotoSans"
      else
        pdf.font "Helvetica"
      end

      # 2. CURRENCY MAPPING
      symbols = {
        "USD"=>"$", "EUR"=>"€", "GBP"=>"£", "GEL"=>"₾", "JPY"=>"¥", "AUD"=>"A$", "CAD"=>"C$",
        "CHF"=>"Fr", "CNY"=>"¥", "INR"=>"₹", "TRY"=>"₺", "AED"=>"د.إ", "ILS"=>"₪", "SEK"=>"kr",
        "BRL"=>"R$", "MXN"=>"$", "AFN"=>"Af", "ALL"=>"L", "AMD"=>"֏", "AOA"=>"Kz", "ARS"=>"$",
        "AZN"=>"₼", "BDT"=>"৳", "BGN"=>"лв", "BHD"=>".د.ب", "CLP"=>"$", "COP"=>"$", "CZK"=>"Kč",
        "DKK"=>"kr", "EGP"=>"E£", "HKD"=>"HK$", "HUF"=>"Ft", "ISK"=>"kr", "IDR"=>"Rp", "JOD"=>"JD",
        "KES"=>"KSh", "KWD"=>"KD", "KZT"=>"₸", "LBP"=>"L£", "MAD"=>"DH", "MYR"=>"RM", "NGN"=>"₦",
        "NOK"=>"kr", "NZD"=>"NZ$", "OMR"=>"RO", "PHP"=>"₱", "PKR"=>"Rs", "PLN"=>"zł", "QAR"=>"QR",
        "RON"=>"lei", "SAR"=>"SR", "SGD"=>"S$", "THB"=>"฿", "TWD"=>"NT$", "UAH"=>"₴", "VND"=>"₫", "ZAR"=>"R"
      }

      currency = symbols[profile.currency] || profile.currency || "$"

      # 3. PARSE DATA
      raw_sections = JSON.parse(log.tasks || "[]") rescue []
      billable_items = []
      report_sections = []

      # Tax Scope Logic
      tax_scope = log.tax_scope.presence || "all"

      raw_sections.each do |section|
        title = section["title"].to_s
        is_material = /material|part|supply|expense/i.match?(title)
        item_type = is_material ? :material : :task

        report_items = []

        if section["items"]
          section["items"].each do |item|
            desc = item.is_a?(Hash) ? item["desc"] : item
            qty = item.is_a?(Hash) ? item["qty"] : nil
            price = item.is_a?(Hash) ? item["price"].to_f : 0.0
            # Parse taxable flag (default false if missing)
            taxable = item.is_a?(Hash) && item["taxable"] == true
            tax_rate = (item.is_a?(Hash) && item["tax_rate"].present?) ? item["tax_rate"].to_f : nil

            if price > 0
              billable_items << {
                desc: desc,
                qty: qty,
                price: price,
                taxable: taxable,
                tax_rate: tax_rate,
                type: item_type
              }
            else
              report_items << item
            end
          end
        end
        report_sections << { "title" => section["title"], "items" => report_items } if report_items.any?
      end

      # Sort categories by number of items (descending)
      report_sections = report_sections.select { |s| s["items"].any? }
      report_sections.sort_by! { |s| -s["items"].size }

      # 4. BILLING CALCULATIONS
      log_billing_mode = log.billing_mode || "hourly"

      if log_billing_mode == "fixed"
        labor_cost = log.time.to_f
        labor_label = "Fixed Rate Service / Project Fee"
        qty_label = "1"
        rate_label = "#{currency}#{'%.2f' % labor_cost}"
        table_qty_header = "QTY"
      else
        labor_hours = log.time.to_f
        hourly_rate = profile.hourly_rate.to_f
        labor_cost = labor_hours * hourly_rate
        labor_label = "Professional Services / Labor"
        qty_label = ("%g" % labor_hours)
        rate_label = "#{currency}#{'%.2f' % hourly_rate}"
        table_qty_header = "HRS"
      end

      materials_cost = billable_items.sum { |i| i[:price] }
      subtotal = labor_cost + materials_cost

      # TAX CALCULATION (Per-Item Logic)
      global_tax_rate = profile.try(:tax_rate).to_f
      tax_amount = 0.0

      # 1. Service/Labor Tax
      tax_tokens = tax_scope.to_s.split(",").map(&:strip)
      # Apply tax to labor if manual override is ON or if scope includes it (and no manual override OFF)
      is_labor_taxed = log.labor_taxable
      # If labor_taxable is not set (legacy or new log without override), fallback to scope
      if log.labor_taxable.nil?
        is_labor_taxed = tax_tokens.include?("labor") || tax_tokens.include?("all") || tax_tokens.include?("total")
      end

      if is_labor_taxed
        tax_amount += labor_cost * (global_tax_rate / 100.0)
      end

      # 2. Items Tax
      billable_items.each do |item|
        if item[:taxable]
          # Check scope
          in_scope = tax_tokens.include?("all") || tax_tokens.include?("total") ||
                     (tax_tokens.include?("tasks_only") && item[:type] == :task) ||
                     (tax_tokens.include?("materials_only") && item[:type] == :material)

          if in_scope
            rate = item[:tax_rate] || global_tax_rate
            tax_amount += item[:price] * (rate / 100.0)
          end
        end
      end

      # For display in totals, if mixed rates, show "Tax" or "Est. Tax"
      # If uniform, we could show rate, but easier to just show Amount.
      # We'll use the global rate for the label if useful, or just generic.

      total_due = subtotal + tax_amount

      invoice_date = log.date.presence || Date.today.strftime("%b %d, %Y")
      due_date = log.due_date.presence || (Date.parse(invoice_date) + 14.days rescue Date.today + 14).strftime("%b %d, %Y")
      invoice_number = "INV-#{1000 + log.id}"
      orange_color = "F97316"

      # --- PDF RENDERING (PREMIUM RE-CRAFT) ---
      pdf.fill_color "000000"

      # Header Bar with Brand Accents
      pdf.canvas do
        pdf.fill_color orange_color
        pdf.fill_rectangle [ 0, pdf.bounds.top ], pdf.bounds.width, 140

        pdf.fill_color "FFFFFF"
        pdf.font("NotoSans", style: :bold) do
          pdf.text_box profile.business_name.upcase, at: [ 40, pdf.bounds.top - 40 ], size: 28, character_spacing: -0.5
        end

        pdf.font("NotoSans", size: 10) do
          contact_info = [ profile.phone, profile.email ].reject(&:blank?).join("  •  ")
          pdf.text_box contact_info, at: [ 40, pdf.bounds.top - 80 ], width: 300
          pdf.text_box profile.address, at: [ 40, pdf.bounds.top - 95 ], width: 300
        end

        # Invoice Label in the Orange Bar
        pdf.font("NotoSans", style: :bold) do
          pdf.text_box "INVOICE", at: [ pdf.bounds.width - 340, pdf.bounds.top - 40 ], size: 48, align: :right, width: 300, opacity: 0.2
        end
      end

      pdf.move_down 110 # Move past the canvas header

      # Details Row (Invoice #, Date, Due Date, Client)
      pdf.bounding_box([ 0, pdf.cursor ], width: pdf.bounds.width) do
        # Left side: Client Info
        pdf.bounding_box([ 0, pdf.bounds.height ], width: 300) do
          pdf.fill_color "666666"
          pdf.text "BILL TO", size: 8, style: :bold, character_spacing: 1
          pdf.move_down 5
          pdf.fill_color "000000"
          pdf.text log.client.presence || "Valued Client", size: 16, style: :bold, leading: 2
        end

        # Right side: Invoice Meta
        pdf.bounding_box([ pdf.bounds.width - 220, pdf.bounds.height ], width: 220) do
          meta_data = [
            [ "INVOICE NO.", invoice_number ],
            [ "DATE", invoice_date ],
            [ "DUE DATE", due_date ]
          ]

          pdf.table(meta_data, width: 220) do
            cells.borders = []
            cells.padding = [ 2, 0 ]
            column(0).font_style = :bold; column(0).size = 8; column(0).text_color = "666666"; column(0).align = :left
            column(1).font_style = :bold; column(1).size = 10; column(1).text_color = "000000"; column(1).align = :right
          end
        end
      end

      pdf.move_down 30

      # Main Items Table
      table_data = [ [ "DESCRIPTION", table_qty_header, "RATE", "AMOUNT" ] ]
      table_data << [ labor_label, qty_label, rate_label, "#{currency}#{'%.2f' % labor_cost}" ]

      billable_items.each do |item|
        m_qty = item[:qty].to_f
        m_qty_label = (m_qty > 0) ? ("%g" % m_qty) : "1"
        table_data << [ item[:desc], m_qty_label, "-", "#{currency}#{'%.2f' % item[:price]}" ]
      end

      pdf.table(table_data, width: pdf.bounds.width, cell_style: { border_color: "EEEEEE", border_width: 0.5 }) do
        row(0).font_style = :bold
        row(0).background_color = "F9F9F9"
        row(0).text_color = "333333"
        row(0).size = 8
        row(0).padding = [ 12, 10 ]
        row(0).borders = [ :bottom ]
        row(0).border_width = 1.5
        row(0).border_color = "000000"

        cells.borders = [ :bottom ]
        cells.padding = [ 12, 10 ]
        cells.size = 10

        columns(1..3).align = :right
        column(0).width = 300

        # Zebra striping
        rows(1..-1).each_with_index do |_, i|
          row(i + 1).background_color = "FAFAFA" if i.odd?
        end
      end

      pdf.move_down 30

      # Summary and Totals
      pdf.bounding_box([ pdf.bounds.width - 250, pdf.cursor ], width: 250) do
        totals = [
          [ "SUBTOTAL", "#{currency}#{'%.2f' % subtotal}" ],
          [ "TAX", "#{currency}#{'%.2f' % tax_amount}" ],
          [ "TOTAL DUE", "#{currency}#{'%.2f' % total_due}" ]
        ]

        pdf.table(totals, width: 250) do
          cells.borders = []
          cells.padding = [ 6, 10 ]
          cells.align = :right

          column(0).font_style = :bold; column(0).size = 8; column(0).text_color = "666666"
          column(1).font_style = :bold; column(1).size = 11; column(1).text_color = "000000"

          # Final Total Highlight
          row(2).background_color = orange_color
          row(2).column(0).text_color = "FFFFFF"
          row(2).column(1).text_color = "FFFFFF"
          row(2).column(1).size = 16
          row(2).padding = [ 10, 10 ]
        end
      end

      # Payment Instructions
      if profile.payment_instructions.present?
        pdf.move_down 40
        pdf.fill_color orange_color
        pdf.text "PAYMENT INSTRUCTIONS", size: 9, style: :bold, character_spacing: 1
        pdf.move_down 8
        pdf.fill_color "444444"
        pdf.text profile.payment_instructions, size: 9, leading: 4
      end

      # Field Report Section (if any)
      if report_sections.any?
        # Check if we need a new page due to lack of space (if less than 150pt left)
        if pdf.cursor < 150
          pdf.start_new_page
          pdf.move_down 20
        else
          pdf.move_down 50
        end

        # Report Section Header (Same Page Style)
        pdf.fill_color "F3F4F6"
        pdf.fill_rectangle [ 0, pdf.cursor ], pdf.bounds.width, 30
        pdf.fill_color orange_color
        pdf.font("NotoSans", style: :bold) do
          pdf.text_box "FIELD INTELLIGENCE REPORT", at: [ 10, pdf.cursor - 8 ], size: 11, character_spacing: 1
        end

        pdf.move_down 45

        pdf.column_box([ 0, pdf.cursor ], columns: 2, width: pdf.bounds.width, spacer: 25) do
          report_sections.each do |section|
            pdf.fill_color "000000"
            pdf.font("NotoSans", style: :bold) do
              pdf.text section["title"].upcase, size: 9, leading: 2
            end
            pdf.stroke_color orange_color
            pdf.stroke_horizontal_line 0, 40
            pdf.move_down 8

            section["items"].each do |item|
              desc = item.is_a?(Hash) ? item["desc"] : item
              qty  = item.is_a?(Hash) ? item["qty"].to_f : 0
              text = qty > 0 && qty != 1 ? "#{desc} (x#{'%g' % qty})" : desc

              pdf.fill_color "444444"
              pdf.indent(5) do
                pdf.text "• #{text}", size: 9, leading: 4
              end
            end
            pdf.move_down 20
          end
        end
      end

      # Footer
      pdf.page_count.times do |i|
        pdf.go_to_page(i + 1)
        pdf.fill_color "999999"
        pdf.text_box "Generated by TALKINVOICE  •  Page #{i+1} of #{pdf.page_count}",
                     at: [ pdf.bounds.left, -10 ],
                     width: pdf.bounds.width,
                     align: :center,
                     size: 7
      end

      send_data pdf.render, filename: "#{invoice_number}_#{log.client}.pdf", type: "application/pdf", disposition: "inline"
    end


    def download_pdf
      log = Log.find(params[:id])
      profile = Profile.first || Profile.new(business_name: "My Business", hourly_rate: 0)

      pdf_data = InvoiceGenerator.new(log, profile).render

      send_data pdf_data, filename: "INV-#{1000 + log.id}_#{log.client}.pdf", type: "application/pdf", disposition: "inline"
    end

    def preview_pdf
      style = params[:style] || "professional"

      # Cache Key based on style and profile updated_at to invalidate on profile changes
      profile = Profile.first || Profile.new(business_name: "TalkInvoice Demo")
      cache_key = "preview_pdf_#{style}_#{profile.updated_at.to_i}"

      pdf_data = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
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

        InvoiceGenerator.new(log, profile).render
      end

      send_data pdf_data, filename: "preview_#{style}.pdf", type: "application/pdf", disposition: "inline"
    end

    private

    def log_params
      params.require(:log).permit(:client, :time, :date, :due_date, :tasks, :billing_mode, :tax_scope, :labor_taxable, :labor_discount_flat, :labor_discount_percent)
    end
end
