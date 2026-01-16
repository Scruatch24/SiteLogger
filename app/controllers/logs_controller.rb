class LogsController < ApplicationController
    require "prawn"
    require "prawn/table"

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

    def download_pdf
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
      invoice_number = "INV-#{1000 + log.id}"
      orange_color = "F97316"

      # --- PDF RENDERING ---
      pdf.fill_color "000000"
      pdf.text profile.business_name.upcase, size: 24, style: :bold, character_spacing: -0.5

      pdf.fill_color orange_color
      pdf.fill_rectangle [ 0, pdf.cursor - 5 ], 30, 5
      pdf.move_down 20

      pdf.fill_color "666666"
      pdf.text "#{profile.phone}  •  #{profile.email}", size: 9
      pdf.text profile.address, size: 9

      pdf.bounding_box([ pdf.bounds.width - 200, pdf.bounds.height ], width: 200) do
        pdf.fill_color orange_color
        pdf.text "INVOICE", size: 36, style: :bold, align: :right
        pdf.fill_color "000000"
        pdf.text invoice_number, size: 12, style: :bold, align: :right
        pdf.fill_color "666666"
        pdf.text invoice_date, size: 10, align: :right
      end

      pdf.move_down 40
      pdf.fill_color "000000"

      # Added leading: 1 to ensure the bold text sits cleanly
      pdf.text "RECIPIENT", size: 8, style: :bold, character_spacing: 1, leading: 1

      pdf.move_down 5

      # Added leading: 4 to give space for descenders (g, j, y, p, q) in the larger font
      pdf.text log.client.presence || "Valued Client", size: 14, style: :bold, leading: 4

      pdf.move_down 30

      table_data = [ [ "DESCRIPTION", table_qty_header, "UNIT PRICE", "TOTAL" ] ]
      table_data << [ labor_label, qty_label, rate_label, "#{currency}#{'%.2f' % labor_cost}" ]

      billable_items.each do |item|
        m_qty = item[:qty].to_f
        m_qty_label = (m_qty > 0) ? ("%g" % m_qty) : "1"
        table_data << [ item[:desc], m_qty_label, "-", "#{currency}#{'%.2f' % item[:price]}" ]
      end

      pdf.table(table_data, width: pdf.bounds.width) do
        row(0).font_style = :bold
        row(0).background_color = "000000"
        row(0).text_color = "FFFFFF"
        row(0).size = 9
        row(0).padding = [ 10, 12 ]
        cells.borders = [ :bottom ]
        cells.border_width = 0.5
        cells.border_color = "EEEEEE"
        cells.padding = [ 12, 12 ]
        cells.size = 10
        columns(1..3).align = :right
        column(0).width = 250
      end

      pdf.move_down 20

      pdf.bounding_box([ pdf.bounds.width - 250, pdf.cursor ], width: 250) do
        totals = [
          [ "Subtotal", "#{currency}#{'%.2f' % subtotal}" ],
          [ "Total Tax", "#{currency}#{'%.2f' % tax_amount}" ],
          [ "AMOUNT DUE", "#{currency}#{'%.2f' % total_due}" ]
        ]
        pdf.table(totals, width: 250) do
          cells.borders = []; cells.padding = [ 5, 12 ]; cells.align = :right
          column(0).font_style = :bold; column(0).size = 9; column(0).text_color = "666666"
          column(1).size = 11; column(1).font_style = :bold
          row(2).column(0).text_color = "000000"; row(2).column(0).size = 12
          row(2).column(1).text_color = orange_color; row(2).column(1).size = 18
        end
      end

      if profile.payment_instructions.present?
        pdf.move_down 40; pdf.fill_color orange_color; pdf.text "PAYMENT INSTRUCTIONS", size: 14, style: :bold, character_spacing: 1
        pdf.move_down 5; pdf.fill_color "000000"; pdf.text profile.payment_instructions, size: 10, leading: 3
      end

      if report_sections.any?
        pdf.move_down 40
        pdf.stroke_horizontal_rule

        # FIX: Lower threshold from 250 to 100.
        # If we have less than ~1.4 inches left, THEN start a new page.
        if pdf.cursor < 100
          pdf.start_new_page
        else
          pdf.move_down 20
        end

        # Keep the Header and the Column Box start together
        pdf.fill_color orange_color
        pdf.text "FIELD INTELLIGENCE REPORT", size: 12, style: :bold, character_spacing: 0.5
        pdf.move_down 10

        # Calculate available height for the columns on THIS page
        # We subtract the bottom margin to ensure we don't write off the page
        available_height = pdf.cursor - pdf.bounds.bottom

        pdf.column_box([ 0, pdf.cursor ], columns: 2, width: pdf.bounds.width, height: available_height, spacer: 20) do
          report_sections.each do |section|
            pdf.fill_color "000000"
            pdf.text section["title"].upcase, size: 8, style: :bold
            pdf.move_down 2

            section["items"].each do |item|
              desc = item.is_a?(Hash) ? item["desc"] : item
              qty  = item.is_a?(Hash) ? item["qty"].to_f : 0
              text = qty > 0 && qty != 1 ? "– #{desc} (x#{'%g' % qty})" : "– #{desc}"
              pdf.fill_color "444444"
              pdf.text text, size: 9, leading: 2
            end

            pdf.move_down 4
          end
        end
      end



      pdf.number_pages "Page <page> of <total>", at: [ pdf.bounds.right - 150, -10 ], width: 150, align: :right, size: 8, color: "999999"
      send_data pdf.render, filename: "#{invoice_number}_#{log.client}.pdf", type: "application/pdf", disposition: "inline"
    end

    private

    def log_params
      params.require(:log).permit(:client, :time, :date, :tasks, :billing_mode, :tax_scope, :labor_taxable, :labor_discount_flat, :labor_discount_percent)
    end
end
