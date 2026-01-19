class InvoiceGenerator
  require "prawn"
  require "prawn/table"
  require_relative "page_manager"

  def initialize(log, profile)
    @log = log
    @profile = profile
    @pdf = Prawn::Document.new(page_size: "A4", margin: 40)
    @font_path = Rails.root.join("app/assets/fonts")

    # Currency mapping
    @symbols = {
      "USD"=>"$", "EUR"=>"€", "GBP"=>"£", "GEL"=>"₾", "JPY"=>"¥", "AUD"=>"A$", "CAD"=>"C$",
      "CHF"=>"Fr", "CNY"=>"¥", "INR"=>"₹", "TRY"=>"₺", "AED"=>"د.إ", "ILS"=>"₪", "SEK"=>"kr",
      "BRL"=>"R$", "MXN"=>"$", "AFN"=>"Af", "ALL"=>"L", "AMD"=>"֏", "AOA"=>"Kz", "ARS"=>"$",
      "AZN"=>"₼", "BDT"=>"৳", "BGN"=>"лв", "BHD"=>".د.ب", "CLP"=>"$", "COP"=>"$", "CZK"=>"Kč",
      "DKK"=>"kr", "EGP"=>"E£", "HKD"=>"HK$", "HUF"=>"Ft", "ISK"=>"kr", "IDR"=>"Rp", "JOD"=>"JD",
      "KES"=>"KSh", "KWD"=>"KD", "KZT"=>"₸", "LBP"=>"L£", "MAD"=>"DH", "MYR"=>"RM", "NGN"=>"₦",
      "NOK"=>"kr", "NZD"=>"NZ$", "OMR"=>"RO", "PHP"=>"₱", "PKR"=>"Rs", "PLN"=>"zł", "QAR"=>"QR",
      "RON"=>"lei", "SAR"=>"SR", "SGD"=>"S$", "THB"=>"฿", "TWD"=>"NT$", "UAH"=>"₴", "VND"=>"₫", "ZAR"=>"R"
    }
    @currency_code = @log.try(:currency).presence || @profile.currency.presence || "USD"
    @currency_data = currencies_data.find { |c| c[:c] == @currency_code }
    @currency = @currency_data ? @currency_data[:s] : (@symbols[@currency_code] || @currency_code || "$")
    @currency_pos = @currency_data ? @currency_data[:p] : "pre"
    @orange_color = "F97316"

    setup_fonts
    prepare_data
    setup_page_manager
  end

  def format_money(amount)
    val = "%.2f" % (amount || 0)
    @currency_pos == "suf" ? "#{val} #{@currency}" : "#{@currency}#{val}"
  end

  def currencies_data
    # Re-use the same list from ApplicationHelper for consistency
    [
      { n: "US Dollar", c: "USD", s: "$", i: "us", p: "pre" },
      { n: "British Pound", c: "GBP", s: "£", i: "gb", p: "pre" },
      { n: "Japanese Yen", c: "JPY", s: "¥", i: "jp", p: "pre" },
      { n: "Australian Dollar", c: "AUD", s: "A$", i: "au", p: "pre" },
      { n: "Canadian Dollar", c: "CAD", s: "C$", i: "ca", p: "pre" },
      { n: "Chinese Yuan", c: "CNY", s: "¥", i: "cn", p: "pre" },
      { n: "Indian Rupee", c: "INR", s: "₹", i: "in", p: "pre" },
      { n: "Brazilian Real", c: "BRL", s: "R$", i: "br", p: "pre" },
      { n: "Mexican Peso", c: "MXN", s: "$", i: "mx", p: "pre" },
      { n: "Argentine Peso", c: "ARS", s: "$", i: "ar", p: "pre" },
      { n: "Chilean Peso", c: "CLP", s: "$", i: "cl", p: "pre" },
      { n: "Colombian Peso", c: "COP", s: "$", i: "co", p: "pre" },
      { n: "Hong Kong Dollar", c: "HKD", s: "HK$", i: "hk", p: "pre" },
      { n: "Egyptian Pound", c: "EGP", s: "E£", i: "eg", p: "pre" },
      { n: "New Zealand Dollar", c: "NZD", s: "NZ$", i: "nz", p: "pre" },
      { n: "Singapore Dollar", c: "SGD", s: "S$", i: "sg", p: "pre" },
      { n: "Thai Baht", c: "THB", s: "฿", i: "th", p: "pre" },
      { n: "Taiwan Dollar", c: "TWD", s: "NT$", i: "tw", p: "pre" },
      { n: "Philippine Peso", c: "PHP", s: "₱", i: "ph", p: "pre" },
      { n: "South African Rand", c: "ZAR", s: "R", i: "za", p: "pre" },
      { n: "Nigerian Naira", c: "NGN", s: "₦", i: "ng", p: "pre" },
      { n: "Kenyan Shilling", c: "KES", s: "KSh", i: "ke", p: "pre" },
      { n: "Malaysian Ringgit", c: "MYR", s: "RM", i: "my", p: "pre" },
      { n: "Indonesian Rupiah", c: "IDR", s: "Rp", i: "id", p: "pre" },
      { n: "Euro", c: "EUR", s: "€", i: "eu", p: "suf" },
      { n: "Georgian Lari", c: "GEL", s: "₾", i: "ge", p: "suf" },
      { n: "Turkish Lira", c: "TRY", s: "₺", i: "tr", p: "suf" },
      { n: "Swedish Krona", c: "SEK", s: "kr", i: "se", p: "suf" },
      { n: "Danish Krone", c: "DKK", s: "kr", i: "dk", p: "suf" },
      { n: "Norwegian Krone", c: "NOK", s: "kr", i: "no", p: "suf" },
      { n: "Icelandic Króna", c: "ISK", s: "kr", i: "is", p: "suf" },
      { n: "Polish Zloty", c: "PLN", s: "zł", i: "pl", p: "suf" },
      { n: "Hungarian Forint", c: "HUF", s: "Ft", i: "hu", p: "suf" },
      { n: "Czech Koruna", c: "CZK", s: "Kč", i: "cz", p: "suf" },
      { n: "Romanian Leu", c: "RON", s: "lei", i: "ro", p: "suf" },
      { n: "Vietnamese Dong", c: "VND", s: "₫", i: "vn", p: "suf" },
      { n: "Ukrainian Hryvnia", c: "UAH", s: "₴", i: "ua", p: "suf" },
      { n: "Bulgarian Lev", c: "BGN", s: "лв", i: "bg", p: "suf" },
      { n: "Albanian Lek", c: "ALL", s: "L", i: "al", p: "suf" },
      { n: "Angolan Kwanza", c: "AOA", s: "Kz", i: "ao", p: "suf" },
      { n: "Afghan Afghani", c: "AFN", s: "Af", i: "af", p: "suf" },
      { n: "Azerbaijani Manat", c: "AZN", s: "₼", i: "az", p: "suf" },
      { n: "Kazakhstani Tenge", c: "KZT", s: "₸", i: "kz", p: "suf" },
      { n: "Moroccan Dirham", c: "MAD", s: "DH", i: "ma", p: "suf" },
      { n: "Swiss Franc", c: "CHF", s: "Fr", i: "ch", p: "suf" },
      { n: "UAE Dirham", c: "AED", s: "د.إ", i: "ae", p: "suf" },
      { n: "Bahraini Dinar", c: "BHD", s: ".د.ب", i: "bh", p: "suf" },
      { n: "Jordanian Dinar", c: "JOD", s: "JD", i: "jo", p: "suf" },
      { n: "Kuwaiti Dinar", c: "KWD", s: "KD", i: "kw", p: "suf" },
      { n: "Omani Rial", c: "OMR", s: "RO", i: "om", p: "suf" },
      { n: "Qatari Rial", c: "QAR", s: "QR", i: "qa", p: "suf" },
      { n: "Saudi Riyal", c: "SAR", s: "SR", i: "sa", p: "suf" },
      { n: "Israeli Shekel", c: "ILS", s: "₪", i: "il", p: "suf" },
      { n: "Lebanese Pound", c: "LBP", s: "L£", i: "lb", p: "suf" },
      { n: "Pakistan Rupee", c: "PKR", s: "Rs", i: "pk", p: "suf" },
      { n: "Bangladeshi Taka", c: "BDT", s: "৳", i: "bd", p: "suf" },
      { n: "Armenian Dram", c: "AMD", s: "֏", i: "am", p: "suf" }
    ]
  end

  def render
    style = @profile.invoice_style.presence || "professional"
    case style
    when "modern" then render_modern
    when "classic" then render_classic
    when "bold" then render_bold
    when "minimal" then render_minimal
    else render_professional
    end

    add_footer unless style == "bold" # Bold handles its own footer
    @pdf.render
  end

  private

  def setup_fonts
    if File.exist?(@font_path.join("NotoSans-Regular.ttf"))
      @pdf.font_families.update("NotoSans" => {
        normal: @font_path.join("NotoSans-Regular.ttf"),
        bold: @font_path.join("NotoSans-Bold.ttf")
      })
      @pdf.font "NotoSans"
    else
      @pdf.font "Helvetica"
    end
  end

  def setup_page_manager
    @page_manager = PageManager.new(@pdf,
      header_renderer: -> { render_continuation_header },
      currency_formatter: ->(amount) { format_money(amount) },
      orange_color: @orange_color
    )
  end

  def render_continuation_header
    # Simplified header for continuation pages
    @pdf.fill_color @orange_color
    @pdf.text @profile.business_name.upcase, size: 14, style: :bold
    @pdf.fill_color "666666"
    @pdf.text "#{@invoice_number} - Continued", size: 10
    @pdf.move_down 10
    @pdf.stroke_color "EEEEEE"
    @pdf.stroke_horizontal_rule
    @pdf.move_down 15
    @pdf.fill_color "000000"
  end

  def prepare_data
    # Re-use logic for parsing sections, items, taxes
    raw_sections = JSON.parse(@log.tasks || "[]") rescue []
    @billable_items = []
    @report_sections = []

    tax_scope = @log.tax_scope.presence || "all"

    raw_sections.each do |section|
      title = section["title"].to_s.downcase
      report_items = []

      # Determine item type based on section title
      item_type = case title
      when /labor|service/ then :labor_service
      when /material/ then :material
      when /expense/ then :expense
      when /fee/ then :fee
      else :other
      end

      if section["items"]
        section["items"].each do |item|
          desc = item.is_a?(Hash) ? item["desc"] : item
          qty = item.is_a?(Hash) ? item["qty"] : nil
          price = item.is_a?(Hash) ? item["price"].to_f : 0.0
          taxable = item.is_a?(Hash) && item["taxable"] == true
          tax_rate = (item.is_a?(Hash) && item["tax_rate"].present?) ? item["tax_rate"].to_f : nil

          # Previously Labor/Service items never had a price. Now we allow it if price > 0.
          if price <= 0
            report_items << item
          else
            @billable_items << { desc: desc, qty: qty, price: price, taxable: taxable, tax_rate: tax_rate, type: item_type }
          end
        end
      end
      @report_sections << { "title" => section["title"], "items" => report_items } if report_items.any?
    end

    # Calculations
    log_billing_mode = @log.billing_mode || "hourly"
    if log_billing_mode == "fixed"
      @labor_cost = @log.time.to_f
      @labor_label = "Fixed Rate Service / Project Fee"
      @qty_label = "1"
      @rate_label = format_money(@labor_cost)
      @table_qty_header = "QTY"
    else
      labor_hours = @log.time.to_f
      hourly_rate = @log.try(:hourly_rate).present? ? @log.try(:hourly_rate).to_f : @profile.hourly_rate.to_f
      @labor_cost = labor_hours * hourly_rate
      @labor_label = "Professional Services / Labor"
      @qty_label = ("%g" % labor_hours)
      @rate_label = format_money(hourly_rate)
      @table_qty_header = "HRS"
    end

    materials_cost = @billable_items.sum { |i| i[:price] }
    @subtotal = @labor_cost + materials_cost

    # Tax Calc with new 4-category tokens
    tax_tokens = tax_scope.to_s.split(",").map(&:strip)
    global_tax_rate = @profile.try(:tax_rate).to_f
    @tax_amount = 0.0

    is_labor_taxed = @log.try(:labor_taxable)
    if @log.try(:labor_taxable).nil?
      is_labor_taxed = tax_tokens.include?("labor") || tax_tokens.include?("all") || tax_tokens.include?("total")
    end
    @tax_amount += @labor_cost * (global_tax_rate / 100.0) if is_labor_taxed

    @billable_items.each do |item|
      if item[:taxable]
        in_scope = tax_tokens.include?("all") || tax_tokens.include?("total") ||
                   (tax_tokens.include?("materials_only") && item[:type] == :material) ||
                   (tax_tokens.include?("fees_only") && item[:type] == :fee) ||
                   (tax_tokens.include?("expenses_only") && item[:type] == :expense)
        if in_scope
          rate = item[:tax_rate] || global_tax_rate
          @tax_amount += item[:price] * (rate / 100.0)
        end
      end
    end


    # Global Discount Calculation
    g_flat = @log.try(:global_discount_flat).to_f
    g_percent = @log.try(:global_discount_percent).to_f
    @global_discount_amount = g_flat + (@subtotal * (g_percent / 100.0))

    pre_total = @subtotal + @tax_amount
    @global_discount_amount = pre_total if @global_discount_amount > pre_total

    # Credit Calculation (applied after discount, can make total negative)
    @credit_amount = @log.try(:credit_flat).to_f
    @credit_reason = @log.try(:credit_reason).presence

    @total_due = pre_total - @global_discount_amount - @credit_amount
    @invoice_date = @log.date.presence || Date.today.strftime("%b %d, %Y")
    @due_date = @log.due_date.presence || (Date.parse(@invoice_date) + 14.days rescue Date.today + 14).strftime("%b %d, %Y")
    @invoice_number = "INV-#{1000 + @log.id}"
  end

  # ===========================================
  # PROFESSIONAL STYLE (with deterministic pagination)
  # ===========================================
  def render_professional
    @pdf.fill_color "000000"

    @pdf.canvas do
      @pdf.fill_color @orange_color
      @pdf.fill_rectangle [ 0, @pdf.bounds.top ], @pdf.bounds.width, 140

      @pdf.fill_color "FFFFFF"
      @pdf.font("NotoSans", style: :bold) do
        @pdf.text_box @profile.business_name.upcase, at: [ 40, @pdf.bounds.top - 40 ], size: 28, character_spacing: -0.5
      end

      @pdf.font("NotoSans", size: 10) do
        contact_info = [ @profile.phone, @profile.email ].reject(&:blank?).join("  •  ")
        @pdf.text_box contact_info, at: [ 40, @pdf.bounds.top - 80 ], width: 300
        @pdf.text_box @profile.address, at: [ 40, @pdf.bounds.top - 95 ], width: 300
      end

      @pdf.font("NotoSans", style: :bold) do
        @pdf.text_box "INVOICE", at: [ @pdf.bounds.width - 340, @pdf.bounds.top - 40 ], size: 48, align: :right, width: 300, opacity: 0.2
      end
    end

    @pdf.move_down 110

    @pdf.bounding_box([ 0, @pdf.cursor ], width: @pdf.bounds.width) do
      @pdf.bounding_box([ 0, @pdf.bounds.height ], width: 300) do
        @pdf.fill_color "666666"
        @pdf.text "BILL TO", size: 8, style: :bold, character_spacing: 1
        @pdf.move_down 5
        @pdf.fill_color "000000"
        @pdf.text @log.client.presence || "Valued Client", size: 16, style: :bold, leading: 2
      end

      @pdf.bounding_box([ @pdf.bounds.width - 220, @pdf.bounds.height ], width: 220) do
        meta_data = [ [ "INVOICE NO.", @invoice_number ], [ "DATE", @invoice_date ], [ "DUE DATE", @due_date ] ]
        @pdf.table(meta_data, width: 220) do
          cells.borders = []
          cells.padding = [ 2, 0 ]
          column(0).font_style = :bold; column(0).size = 8; column(0).text_color = "666666"; column(0).align = :left
          column(1).font_style = :bold; column(1).size = 10; column(1).text_color = "000000"; column(1).align = :right
        end
      end
    end

    @pdf.move_down 30

    # Use deterministic table rendering
    render_table_deterministic(header_bg: "F9F9F9", header_text: "333333", border: true)
    render_totals_protected(highlight: true)
    render_payment_instructions
    render_field_report_paginated
  end

  # ===========================================
  # DETERMINISTIC TABLE RENDERING
  # ===========================================
  def render_table_deterministic(options = {})
    table_width = options[:simple] ? 380 : @pdf.bounds.width

    # Column widths
    col_desc = table_width * 0.58
    col_qty = table_width * 0.12
    col_rate = table_width * 0.15
    col_amount = table_width * 0.15

    # Render table header
    render_table_header_row(col_desc, col_qty, col_rate, col_amount, options)

    # Track row index for zebra striping
    row_index = 0

    # Render labor row first (only if cost > 0)
    if @labor_cost > 0
      labor_row_height = @page_manager.compute_row_height(@labor_label)
      @page_manager.ensure_space(labor_row_height)
      render_item_row(@labor_label, @qty_label, @rate_label, format_money(@labor_cost),
                      col_desc, col_qty, col_rate, col_amount, row_index, options)
      @page_manager.add_to_subtotal(@labor_cost)
      row_index += 1
    end

    # Render billable items
    @billable_items.each do |item|
      row_height = @page_manager.compute_row_height(item[:desc])

      # Check if we need a new page
      if @page_manager.ensure_space(row_height + PageManager::TABLE_HEADER_HEIGHT)
        # Re-render table header on new page
        render_table_header_row(col_desc, col_qty, col_rate, col_amount, options)
      end

      m_qty = item[:qty].to_f
      m_qty_label = (m_qty > 0) ? ("%g" % m_qty) : "1"

      render_item_row(item[:desc], m_qty_label, "-", format_money(item[:price]),
                      col_desc, col_qty, col_rate, col_amount, row_index, options)
      @page_manager.add_to_subtotal(item[:price])
      row_index += 1
    end

    # Render credit as negative line item if present
    if @credit_amount > 0
      credit_desc = @credit_reason.present? ? "CREDIT: #{@credit_reason}" : "CREDIT"
      row_height = @page_manager.compute_row_height(credit_desc)

      if @page_manager.ensure_space(row_height + PageManager::TABLE_HEADER_HEIGHT)
        render_table_header_row(col_desc, col_qty, col_rate, col_amount, options)
      end

      render_item_row(credit_desc, "1", "-", "-#{format_money(@credit_amount)}",
                      col_desc, col_qty, col_rate, col_amount, row_index, options.merge(credit: true))
    end
  end

  def render_table_header_row(col_desc, col_qty, col_rate, col_amount, options = {})
    header_height = PageManager::TABLE_HEADER_HEIGHT
    y_pos = @pdf.cursor
    table_width = options[:simple] ? 380 : @pdf.bounds.width

    # Background
    if options[:header_bg]
      @pdf.fill_color options[:header_bg]
      @pdf.fill_rectangle [ 0, y_pos ], table_width, header_height
    end

    # Borders
    @pdf.stroke_color "EEEEEE"
    if options[:grid]
      @pdf.stroke_rectangle [ 0, y_pos ], table_width, header_height
    end

    @pdf.stroke_color "000000"
    if options[:minimal]
      @pdf.line_width = 2
      @pdf.stroke_line [ 0, y_pos - header_height ], [ table_width, y_pos - header_height ]
    else
      @pdf.line_width = 1.5
      @pdf.stroke_line [ 0, y_pos - header_height ], [ table_width, y_pos - header_height ]
    end
    @pdf.line_width = 0.5

    # Header text
    text_y = y_pos - 12
    text_color = options[:header_text] || "333333"
    @pdf.fill_color text_color

    @pdf.font("NotoSans", style: :bold, size: 8) do
      @pdf.text_box "DESCRIPTION", at: [ 10, text_y ], width: col_desc - 10, height: 20
      @pdf.text_box @table_qty_header, at: [ col_desc, text_y ], width: col_qty, height: 20, align: :right
      @pdf.text_box "RATE", at: [ col_desc + col_qty, text_y ], width: col_rate, height: 20, align: :right
      @pdf.text_box "AMOUNT", at: [ col_desc + col_qty + col_rate, text_y ], width: col_amount - 10, height: 20, align: :right
    end

    @pdf.move_down header_height
    @pdf.fill_color "000000"
  end

  def render_item_row(desc, qty, rate, amount, col_desc, col_qty, col_rate, col_amount, row_index, options = {})
    row_height = @page_manager.compute_row_height(desc)
    y_pos = @pdf.cursor
    table_width = options[:simple] ? 380 : @pdf.bounds.width

    # Zebra striping
    if row_index.odd? && !options[:minimal]
      @pdf.fill_color "FAFAFA"
      @pdf.fill_rectangle [ 0, y_pos ], table_width, row_height
    end

    # Credit row styling (red)
    if options[:credit]
      @pdf.fill_color "FEE2E2"
      @pdf.fill_rectangle [ 0, y_pos ], table_width, row_height
    end

    # Borders
    @pdf.stroke_color "EEEEEE"
    if options[:grid]
      @pdf.stroke_rectangle [ 0, y_pos ], table_width, row_height
    else
      @pdf.stroke_line [ 0, y_pos - row_height ], [ table_width, y_pos - row_height ]
    end

    # Row content
    text_y = y_pos - 10
    text_color = options[:credit] ? "DC2626" : "000000"
    @pdf.fill_color text_color

    @pdf.font("NotoSans", size: 10) do
      # Description (can wrap)
      @pdf.text_box desc.to_s, at: [ 10, text_y ], width: col_desc - 20, height: row_height - 10, overflow: :truncate

      # Qty, Rate, Amount (right-aligned)
      @pdf.text_box qty.to_s, at: [ col_desc, text_y ], width: col_qty, height: 20, align: :right
      @pdf.text_box rate.to_s, at: [ col_desc + col_qty, text_y ], width: col_rate, height: 20, align: :right
      @pdf.text_box amount.to_s, at: [ col_desc + col_qty + col_rate, text_y ], width: col_amount - 10, height: 20, align: :right
    end

    @pdf.move_down row_height
    @pdf.fill_color "000000"
  end

  # ===========================================
  # PROTECTED TOTALS BLOCK
  # ===========================================
  def render_totals_protected(options = {})
    totals_height = @page_manager.calculate_totals_height(
      has_discount: @global_discount_amount > 0,
      has_credit: false # Credit is now shown in table
    )

    @page_manager.ensure_space(totals_height + 30)

    @pdf.move_down 20
    width = options[:simple] ? 380 : 250
    x_pos = options[:simple] ? 0 : @pdf.bounds.width - width

    @pdf.bounding_box([ x_pos, @pdf.cursor ], width: width) do
      totals = [
        [ "SUBTOTAL", format_money(@subtotal) ],
        [ "TAX", format_money(@tax_amount) ]
      ]

      if @global_discount_amount > 0
        totals << [ "DISCOUNT", "-#{format_money(@global_discount_amount)}" ]
      end

      # Credit is now shown in table, not in totals
      # But we still account for it in total
      if @credit_amount > 0
        credit_label = @credit_reason.present? ? "CREDIT (#{@credit_reason})" : "CREDIT"
        totals << [ credit_label, "-#{format_money(@credit_amount)}" ]
      end

      totals << [ "TOTAL", format_money(@total_due) ]

      @pdf.table(totals, width: width) do
        cells.borders = []
        cells.align = :right
        cells.padding = [ 5, 10 ]
        column(0).font_style = :bold
        last_idx = totals.size - 1
        row(last_idx).size = 14
        if options[:highlight]
          row(last_idx).background_color = @orange_color
          row(last_idx).text_color = "FFFFFF"
        elsif options[:line_item]
          row(last_idx).borders = [ :top ]
          row(last_idx).border_color = "000000"
        end
      end
    end
  end

  # ===========================================
  # PAGINATED FIELD REPORT
  # ===========================================
  def render_field_report_paginated(options = {})
    return unless @report_sections.any?

    # Calculate minimum space needed: header + at least one section with one item
    min_report_space = PageManager::FIELD_REPORT_HEADER_HEIGHT +
                       PageManager::FIELD_REPORT_SECTION_HEIGHT +
                       PageManager::FIELD_REPORT_ITEM_HEIGHT

    @page_manager.ensure_space(min_report_space)

    @pdf.move_down 30

    # Report header
    @pdf.fill_color "F3F4F6"
    @pdf.fill_rectangle [ 0, @pdf.cursor ], @pdf.bounds.width, 20
    @pdf.fill_color @orange_color
    @pdf.text_box "FIELD INTELLIGENCE REPORT", at: [ 8, @pdf.cursor - 5 ], size: 9, style: :bold
    @pdf.move_down 28

    @report_sections.each do |section|
      # Check if section header + first item fits
      first_item = section["items"].first
      first_item_desc = first_item.is_a?(Hash) ? first_item["desc"] : first_item
      first_item_height = @page_manager.compute_row_height(first_item_desc.to_s, chars_per_line: 70)
      section_space = PageManager::FIELD_REPORT_SECTION_HEIGHT + first_item_height

      if @page_manager.ensure_space(section_space)
        # Re-render report header on new page
        @pdf.fill_color "F3F4F6"
        @pdf.fill_rectangle [ 0, @pdf.cursor ], @pdf.bounds.width, 20
        @pdf.fill_color @orange_color
        @pdf.text_box "FIELD INTELLIGENCE REPORT (continued)", at: [ 8, @pdf.cursor - 5 ], size: 9, style: :bold
        @pdf.move_down 28
      end

      # Section title
      @pdf.fill_color "000000"
      @pdf.text section["title"].to_s.upcase, size: 9, style: :bold
      @pdf.stroke_color @orange_color
      @pdf.stroke_horizontal_line 0, 40
      @pdf.move_down 5

      # Section items
      section["items"].each do |item|
        desc = item.is_a?(Hash) ? item["desc"] : item
        qty  = item.is_a?(Hash) ? item["qty"].to_f : 0
        text = qty > 0 && qty != 1 ? "#{desc} (x#{'%g' % qty})" : desc

        item_height = PageManager::FIELD_REPORT_ITEM_HEIGHT
        @page_manager.ensure_space(item_height)

        @pdf.fill_color "444444"
        @pdf.indent(5) { @pdf.text "• #{text}", size: 9 }
      end
      @pdf.move_down 8
    end
  end

  def render_payment_instructions
    return unless @profile.payment_instructions.present?

    payment_height = PageManager::PAYMENT_INSTRUCTIONS_HEIGHT
    @page_manager.ensure_space(payment_height)

    @pdf.move_down 20
    @pdf.text "PAYMENT INSTRUCTIONS", size: 9, style: :bold
    @pdf.fill_color "444444"
    @pdf.text @profile.payment_instructions, size: 9, leading: 2
    @pdf.fill_color "000000"
  end

  # ===========================================
  # OTHER STYLES (keep using pdf.table for now, will migrate later)
  # ===========================================
  def render_modern
    # Style 2: Modern (Sidebar)
    @pdf.canvas do
      @pdf.fill_color "F8F9FA"
      @pdf.fill_rectangle [ 0, @pdf.bounds.top ], 180, @pdf.bounds.height
    end

    @pdf.fill_color "000000"

    @pdf.bounding_box([ 0, @pdf.bounds.top - 30 ], width: 165) do
      @pdf.font("NotoSans", style: :bold) do
        @pdf.text "INVOICE", size: 20, character_spacing: 1
      end
      @pdf.move_down 30

      @pdf.fill_color "666666"
      @pdf.text "FROM", size: 8, style: :bold
      @pdf.fill_color "000000"
      @pdf.text @profile.business_name, size: 10, style: :bold
      @pdf.text @profile.address, size: 9

      @pdf.move_down 20

      @pdf.fill_color "666666"
      @pdf.text "BILL TO", size: 8, style: :bold
      @pdf.fill_color "000000"
      @pdf.text @log.client.presence || "Valued Client", size: 12, style: :bold

      @pdf.move_down 20

      @pdf.fill_color "666666"
      @pdf.text "DETAILS", size: 8, style: :bold
      @pdf.fill_color "000000"
      @pdf.text "NO: #{@invoice_number}", size: 9
      @pdf.text "DATE: #{@invoice_date}", size: 9
      @pdf.text "DUE: #{@due_date}", size: 9
    end

    # Sidebar width is 180, so we start content at 195 (15pt gap)
    @pdf.bounding_box([ 195, @pdf.bounds.top - 30 ], width: 320) do
      render_table_deterministic(simple: true)
      @pdf.move_down 10
      render_totals_protected(simple: true)
      @pdf.move_down 10
      render_payment_instructions
      render_field_report_paginated(simple: true)
    end
  end

  def render_classic
    @pdf.text @profile.business_name.upcase, align: :center, size: 20, style: :bold
    @pdf.text [ @profile.address, @profile.phone ].join(" | "), align: :center, size: 9, color: "666666"
    @pdf.move_down 20
    @pdf.stroke_horizontal_rule
    @pdf.move_down 20

    @pdf.text "INVOICE", align: :center, size: 16, style: :bold, character_spacing: 3
    @pdf.move_down 30

    y_pos = @pdf.cursor
    @pdf.bounding_box([ 0, y_pos ], width: 250) do
      @pdf.text "BILL TO:", size: 8, style: :bold
      @pdf.text @log.client, size: 11
    end

    @pdf.bounding_box([ 300, y_pos ], width: 200) do
      @pdf.text "Invoice #: #{@invoice_number}", align: :right, size: 10
      @pdf.text "Date: #{@invoice_date}", align: :right, size: 10
      @pdf.text "Due Date: #{@due_date}", align: :right, size: 10
    end

    @pdf.move_down 30
    render_table_deterministic(grid: true)
    render_totals_protected(line_item: true)
    render_payment_instructions
    render_field_report_paginated(grid: true, align: :left)
  end

  def render_bold
    @pdf.canvas do
      @pdf.fill_color "111827"
      @pdf.fill_rectangle [ 0, @pdf.bounds.top ], @pdf.bounds.width, 160
    end

    @pdf.fill_color "FFFFFF"
    @pdf.move_down 20
    @pdf.text "INVOICE", align: :right, size: 40, style: :bold, character_spacing: 1

    @pdf.move_down 5
    @pdf.text @profile.business_name, size: 18, style: :bold
    @pdf.text @profile.address, size: 9

    @pdf.move_down 65
    @pdf.fill_color "000000"

    y_pos = @pdf.cursor
    @pdf.text_box "BILL TO", at: [ 0, y_pos ], size: 8, style: :bold, color: "9CA3AF"
    @pdf.text_box @log.client, at: [ 0, y_pos - 15 ], size: 14, style: :bold

    @pdf.text_box "DETAILS", at: [ 300, y_pos ], size: 8, style: :bold, color: "9CA3AF"
    @pdf.text_box "##{@invoice_number} | #{@invoice_date}", at: [ 300, y_pos - 15 ], size: 10

    @pdf.move_down 35
    render_table_deterministic(header_bg: "111827", header_text: "FFFFFF")
    @pdf.move_down 10
    render_totals_protected
    render_payment_instructions

    render_field_report_paginated(bold: true)

    @pdf.page_count.times do |i|
      @pdf.go_to_page(i + 1)
      @pdf.canvas do
        @pdf.fill_color "111827"
        @pdf.fill_rectangle [ 0, 40 ], @pdf.bounds.width, 40
        @pdf.fill_color "FFFFFF"
        @pdf.text_box "Generated by TALKINVOICE", at: [ 0, 25 ], width: @pdf.bounds.width, align: :center, size: 8
      end
    end
  end

  def render_minimal
    @pdf.font_size 10
    @pdf.text @profile.business_name.upcase, style: :bold, size: 12
    @pdf.text "INVOICE #{@invoice_number}", align: :right, style: :bold, size: 12
    @pdf.move_down 40
    @pdf.text @log.client, size: 18, style: :bold
    @pdf.text "Due: #{@due_date}", size: 10, color: "666666"
    @pdf.move_down 40
    render_table_deterministic(minimal: true)
    render_totals_protected(minimal: true)
    render_payment_instructions
    render_field_report_paginated(minimal: true)
  end


  def add_footer
    @pdf.page_count.times do |i|
      @pdf.go_to_page(i + 1)
      @pdf.fill_color "999999"
      @pdf.text_box "Generated by TALKINVOICE  •  Page #{i+1} of #{@pdf.page_count}",
                    at: [ @pdf.bounds.left, -10 ], width: @pdf.bounds.width, align: :center, size: 7
    end
  end
end
