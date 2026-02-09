class InvoiceGenerator
  require "prawn"
  require "prawn/table"
  require_relative "page_manager"

  CURRENCIES_DATA = [
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

  # IMPORTANT: Math logic remains consistent with the previous implementation.
  # Subtotal is Gross. Discounts are applied after subtotal. Credits after tax.

  def initialize(log, profile, style: nil)
    @log = log
    @profile = profile
    @style = (style.presence || @log.try(:invoice_style).presence || @profile.invoice_style.presence || "classic").to_s.downcase
    @document_language = (@profile.try(:document_language).presence || "en").to_s.downcase
    @base_font_name = (@document_language == "ka") ? "NotoSansGeorgian" : "NotoSans"
    @pdf = Prawn::Document.new(page_size: "A4", margin: 40)
    @font_path = Rails.root.join("app/assets/fonts")

    # Currency mapping list
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
    @currency_data = CURRENCIES_DATA.find { |c| c[:c] == @currency_code }
    @currency = @currency_data ? @currency_data[:s] : (@symbols[@currency_code] || @currency_code || "$")
    @currency_pos = @currency_data ? @currency_data[:p] : "pre"

    # Style Palettes
    @orange_color = (@log.try(:accent_color).presence || @profile.try(:accent_color).presence || "F97316").to_s.gsub("#", "")
    @charcoal     = "333333"
    @dark_charcoal = "111111"
    @soft_gray    = "D1D5DB"
    @mid_gray     = "666666"
    @green_tag    = "16A34A"
    @black_tag    = "000000"

    # New Style Specifics
    @navy         = "1E3A8A"
    @slate        = "475569"
    @professional_blue = "2563EB"
    @modern_gray  = "F3F4F6"
    @deep_red     = "991B1B"

    setup_fonts
    prepare_data
    setup_page_manager
  end

  def labels
    @labels ||= if @document_language == "ka"
      {
        invoice: "ინვოისი",
        billed_to: "გადამხდელი",
        from: "გამგზავნი",
        issued: "გაცემული",
        due: "ვადა",
        type: "ტიპი",
        description: "აღწერა",
        price: "ფასი",
        qty: "რაოდ.",
        amount: "ჯამი",
        discount: "ფასდაკლება",
        tax: "დღგ",
        subtotal: "შუალედური ჯამი",
        tax_total: "დღგ",
        total_due: "გადასახდელი ბალანსი",
        labor: "პროფესიონალური მომსახურება",
        material: "მასალა",
        fee: "მოსაკრებელი",
        expense: "ხარჯი",
        other: "სხვა",
        credit: "კრედიტი",
        client: "კლიენტი",
        sender: "გამომგზავნი",
        date: "თარიღი",
        due_date: "ვადა",
        bill_to: "ადრესატი",
        balance_due: "გადასახდელი",
        items_total: "ნივთების ჯამი",
        item_discounts: "ნივთების ფასდაკლება",
        taxable_total: "დასაბეგრი ჯამი",
        invoice_discount: "ინვოისის ფასდაკლება",
        total_before_credit: "ჯამი კრედიტამდე",
        credit_applied: "კრედიტი",
        payment_details: "გადახდის დეტალები",
        page: "გვერდი",
        of: "სულ",
        tax_id_label: "ID ნომერი",
        valued_client: "ძვირფასი კლიენტი",
        invoice_prefix: "INV",
        num: "ნომერი"
      }
    else
      {
        invoice: "INVOICE",
        billed_to: "BILLED TO",
        from: "FROM",
        issued: "ISSUED",
        due: "DUE",
        type: "TYPE",
        description: "DESCRIPTION",
        price: "PRICE",
        qty: "QTY",
        amount: "AMOUNT",
        discount: "DISCOUNT",
        tax: "Tax",
        subtotal: "SUBTOTAL",
        tax_total: "Tax",
        total_due: "TOTAL DUE",
        labor: "Service",
        material: "Material",
        fee: "Fee",
        expense: "Expense",
        other: "Other",
        credit: "CREDIT",
        client: "CLIENT",
        sender: "SENDER",
        date: "DATE",
        due_date: "DUE DATE",
        bill_to: "BILL TO",
        balance_due: "BALANCE DUE",
        items_total: "Items Total",
        item_discounts: "Item Discounts",
        taxable_total: "Taxable Total",
        invoice_discount: "Invoice Discount",
        total_before_credit: "Total Before Credit",
        credit_applied: "Credit Applied",
        payment_details: "PAYMENT DETAILS",
        page: "PAGE",
        of: "OF",
        tax_id_label: "ID Number",
        valued_client: "VALUED CLIENT",
        invoice_prefix: "INV",
        num: "NUM"
      }
    end
  end

  def render
    case @style
    when "professional"
      render_professional
    when "modern"
      render_modern
    when "bold"
      render_bold
    when "minimal"
      render_minimal
    else
      render_classic
    end

    add_footer
    @pdf.render
  end

  def page_count
    @pdf.page_count
  end

  def render_classic
    @pdf.fill_color "000000"

    # -- 1. Clean Minimal Header (White Bar with Logo \u0026 Divider) --
    @pdf.canvas do
      page_top = @pdf.bounds.top
      page_width = @pdf.bounds.width
      header_height = 100

      @pdf.fill_color "FFFFFF"
      # Rectangle covers the top 100pt of the page
      @pdf.fill_rectangle [ 0, page_top ], page_width, header_height

      # Bottom Divider Line
      @pdf.stroke_color @soft_gray
      @pdf.line_width(0.5)
      @pdf.stroke_horizontal_line 0, page_width, at: page_top - header_height

      # Logo on the left side of the header
      if @profile.logo.attached?
        begin
          # Position logo with padding from left edge, vertically centered
          logo_height = 70
          logo_y = page_top - (header_height - logo_height) / 2
          @pdf.image StringIO.new(@profile.logo.download), at: [ 50, logo_y ], height: logo_height
        rescue => _e
        end
      end

      # INVOICE text on the right
      @pdf.fill_color @charcoal
      @pdf.font(@base_font_name, style: :bold) do
        @pdf.text_box labels[:invoice], at: [ page_width - 250, page_top ], size: 24, height: header_height, valign: :center, align: :right, width: 200, character_spacing: 8
      end
    end

    # Advance document cursor past the absolute header - moving BILLED TO higher
    @pdf.move_down 80

    # -- 2. Clean Correspondence Layout --
    # Left: Client (Billed To) + Sender (From)
    # Right: Dates + Logo (centered)

    y_start = @pdf.cursor

    # Calculate column widths (50% split with a gap)
    total_width = @pdf.bounds.width
    gap = 20
    col_width = (total_width - gap) / 2

    # -- LEFT COLUMN: BILLED TO + FROM --
    @pdf.bounding_box([ 0, y_start ], width: col_width) do
      # 1. BILLED TO
      pill_width = 60
      pill_height = 15

      # Pill
      @pdf.fill_color @orange_color
      @pdf.fill_rounded_rectangle [ 0, @pdf.cursor ], pill_width, pill_height, 2
      @pdf.fill_color "FFFFFF"
      @pdf.font(@base_font_name, size: 6, style: :bold) do
        @pdf.text_box labels[:billed_to], at: [ 0, @pdf.cursor - 4 ], width: pill_width, height: pill_height, align: :center, character_spacing: 0.5
      end

      @pdf.move_down 25

      # Client Content
      @pdf.fill_color @dark_charcoal
      @pdf.font(@base_font_name, style: :bold, size: 10) do
        client_name = (@log.client.presence || labels[:valued_client]).upcase
        @pdf.text client_name, leading: 2
      end

      @pdf.move_down 25

      # 2. FROM (Under Billed To)
      pill_width_from = 40

      # Pill
      @pdf.fill_color @soft_gray
      @pdf.fill_rounded_rectangle [ 0, @pdf.cursor ], pill_width_from, pill_height, 2
      @pdf.fill_color @dark_charcoal
      @pdf.font(@base_font_name, size: 6, style: :bold) do
        @pdf.text_box labels[:from], at: [ 0, @pdf.cursor - 4 ], width: pill_width_from, height: pill_height, align: :center, character_spacing: 0.5
      end

      @pdf.move_down 25

      # Sender Content (Left Aligned)
      @pdf.fill_color @dark_charcoal
      @pdf.font(@base_font_name, size: 9) do
        # Company Name + Black Dot + Tax ID
        name_text = []
        name_text << { text: @profile.business_name, styles: [ :bold ], color: @dark_charcoal }
        if @profile.tax_id.present?
           name_text << { text: "  ", color: @dark_charcoal }
           name_text << { text: "•", color: "000000" }
           name_text << { text: "  #{labels[:tax_id_label]}: ", color: @dark_charcoal, styles: [ :bold ] }
           name_text << { text: @profile.tax_id.to_s, color: @dark_charcoal, styles: [ :bold ] }
        end
        @pdf.formatted_text name_text, leading: 2
        @pdf.fill_color @mid_gray
        @pdf.text @profile.address.to_s, leading: 2

        # Phone + Orange Dot + Email
        contact_text = []
        if @profile.phone.present?
          contact_text << { text: "#{@profile.phone}  ", color: @mid_gray }
          contact_text << { text: "•", color: "000000" }
          contact_text << { text: "  ", color: @mid_gray }
        end
        contact_text << { text: @profile.email.to_s, color: @mid_gray }

        @pdf.formatted_text contact_text, leading: 2
      end
      @left_column_height = @pdf.bounds.top - @pdf.cursor
    end

    # -- RIGHT COLUMN: DATES + LOGO (Right aligned) --
    @pdf.bounding_box([ col_width + gap, y_start ], width: col_width) do
      pill_height = 15
      pill_width = 45
      date_val_width = 100
      x_edge = @pdf.bounds.width
      x_pill = x_edge - pill_width
      x_value = x_pill - date_val_width - 10

      current_y = @pdf.cursor

      # 1. ISSUED section (right aligned)
      @pdf.fill_color @soft_gray
      @pdf.fill_rounded_rectangle [ x_pill, current_y ], pill_width, pill_height, 2
      @pdf.fill_color @dark_charcoal
      @pdf.font(@base_font_name, size: 6, style: :bold) do
        @pdf.text_box labels[:issued], at: [ x_pill, current_y - 4 ], width: pill_width, height: pill_height, align: :center, character_spacing: 0.5
      end

      # ISSUED value
      @pdf.fill_color @dark_charcoal
      @pdf.font(@base_font_name, size: 9) do
        @pdf.text_box @invoice_date, at: [ x_value, current_y - 2.5 ], width: date_val_width, align: :right
      end

      @pdf.move_down 22
      current_y = @pdf.cursor

      # 2. DUE section (below ISSUED, right aligned)
      @pdf.fill_color @orange_color
      @pdf.fill_rounded_rectangle [ x_pill, current_y ], pill_width, pill_height, 2
      @pdf.fill_color "FFFFFF"
      @pdf.font(@base_font_name, size: 6, style: :bold) do
        @pdf.text_box labels[:due], at: [ x_pill, current_y - 4 ], width: pill_width, height: pill_height, align: :center, character_spacing: 0.5
      end

      # DUE value
      @pdf.fill_color @dark_charcoal
      @pdf.font(@base_font_name, size: 9) do
        @pdf.text_box @due_date, at: [ x_value, current_y - 2.5 ], width: date_val_width, align: :right
      end

      @pdf.move_down 22
      current_y = @pdf.cursor

      # 3. NUM section (below DUE, right aligned) - Invoice Number
      @pdf.fill_color @soft_gray
      @pdf.fill_rounded_rectangle [ x_pill, current_y ], pill_width, pill_height, 2
      @pdf.fill_color @dark_charcoal
      @pdf.font(@base_font_name, size: 6, style: :bold) do
        @pdf.text_box labels[:num] || "NUM", at: [ x_pill, current_y - 4 ], width: pill_width, height: pill_height, align: :center, character_spacing: 0.5
      end

      # NUM value (invoice number) - Orange text (always Latin, use NotoSans for bold)
      @pdf.fill_color @orange_color
      @pdf.font("NotoSans", size: 9, style: :bold) do
        @pdf.text_box @invoice_number, at: [ x_value, current_y - 2.5 ], width: date_val_width, align: :right
      end
    end

    # Dynamic transition: use the height used by the FROM column + 15pt gap
    @pdf.move_cursor_to y_start - @left_column_height - 15
    render_classic_flow_table
    render_classic_summary
  end

  def render_classic_flow_table
    table_width = @pdf.bounds.width
    @table_widths = calculate_column_widths(table_width)

    # Corner radius for classic style tables
    @table_corner_radius = (@style == "classic") ? 8 : 0

    # Ensure there is room for at least the header + a small row cushion
    check_new_page_needed(60)

    render_table_header(table_width, @table_widths)

    categories = [
        { key: :labor, title: labels[:labor] },
        { key: :material, title: labels[:material] },
        { key: :fee, title: labels[:fee] },
        { key: :expense, title: labels[:expense] },
        { key: :other, title: labels[:other] }
    ]

    categories.each do |cat|
      items = @categorized_items[cat[:key]]
      next if items.empty?

      items.each do |item|
        render_classic_row(item, table_width, @table_widths[:desc], @table_widths[:qty], @table_widths[:rate], @table_widths[:disc], @table_widths[:tax], @table_widths[:amnt], is_credit: false)
      end
    end

    if @credits.any?
      @credits.each do |credit|
        credit_data = {
          desc: credit[:reason],
          price: -credit[:amount],
          qty: 1,
          computed_tax_amount: 0,
          item_discount_amount: 0
        }
        render_classic_row(credit_data, table_width, @table_widths[:desc], @table_widths[:qty], @table_widths[:rate], @table_widths[:disc], @table_widths[:tax], @table_widths[:amnt], is_credit: true)
      end
    end

    # Apply rounded bottom corners to the table
    apply_table_bottom_rounded_corners(table_width, @pdf.cursor, @table_corner_radius)
  end

  def render_table_header(table_width, widths)
    w_desc = widths[:desc]
    w_rate = widths[:rate]
    w_qty  = widths[:qty]
    w_amnt = widths[:amnt]
    w_disc = widths[:disc]
    w_tax  = widths[:tax]

    # Corner radius for classic style
    corner_radius = (@style == "classic") ? 8 : 0

    # Store table header start position for rounded corners
    @table_header_top = @pdf.cursor

    # Header Colors based on Style
    header_base_color = case @style
    when "professional" then @charcoal
    when "modern"       then @dark_charcoal
    when "bold"         then "000000"
    when "minimal"      then @mid_gray
    else @charcoal
    end

    header_accent_color = case @style
    when "professional" then @navy
    when "modern"       then @slate
    when "bold"         then "000000"
    when "minimal"      then @mid_gray
    else @orange_color
    end

    header_h = 25

    if corner_radius > 0
      # Draw header with rounded top corners only
      # 1. Draw the base header (right portion) with rounded top-right corner
      @pdf.fill_color header_base_color
      draw_top_rounded_rect(w_desc, @pdf.cursor, table_width - w_desc, header_h, corner_radius, round_left: false, round_right: true)

      # 2. Draw the accent header (left portion - DESCRIPTION) with rounded top-left corner
      @pdf.fill_color header_accent_color
      draw_top_rounded_rect(0, @pdf.cursor, w_desc, header_h, corner_radius, round_left: true, round_right: false)

      # No top border stroke - the rounded filled rectangles provide the visual edge
    else
      # Top Border Line
      @pdf.stroke_color @soft_gray
      @pdf.line_width(1.0)
      @pdf.stroke_horizontal_line 0, table_width, at: @pdf.cursor

      # 1. Base Header
      @pdf.fill_color header_base_color
      @pdf.fill_rectangle [ 0, @pdf.cursor ], table_width, header_h

      # 2. DESCRIPTION Anchor Box (Now starts at x=0)
      @pdf.fill_color header_accent_color
      @pdf.fill_rectangle [ 0, @pdf.cursor ], w_desc, header_h
    end

    font_name = (@document_language == "ka") ? "NotoSansGeorgian" : "NotoSans"
    @pdf.font(font_name, style: :bold, size: 7.5) do
      @pdf.fill_color "FFFFFF"

      # DESCRIPTION (Left) and other columns
      @pdf.text_box labels[:description], at: [ 10, @pdf.cursor ], width: w_desc - 20, height: header_h, align: :left, valign: :center
      @pdf.text_box labels[:price], at: [ w_desc, @pdf.cursor ], width: w_rate, height: header_h, align: :center, valign: :center
      @pdf.text_box labels[:qty], at: [ w_desc + w_rate, @pdf.cursor ], width: w_qty, height: header_h, align: :center, valign: :center
      @pdf.text_box labels[:amount], at: [ w_desc + w_rate + w_qty, @pdf.cursor ], width: w_amnt, height: header_h, align: :center, valign: :center
      @pdf.text_box labels[:discount], at: [ w_desc + w_rate + w_qty + w_amnt, @pdf.cursor ], width: w_disc, height: header_h, align: :center, valign: :center
      @pdf.text_box labels[:tax], at: [ w_desc + w_rate + w_qty + w_amnt + w_disc, @pdf.cursor ], width: w_tax, height: header_h, align: :center, valign: :center
    end

    # Header Vertical Dividers (Standardized)
    header_divider_color = "E5E7EB"
    @pdf.stroke_color header_divider_color
    @pdf.line_width(1.0)
    @pdf.stroke do
      x_positions = [ 0, w_desc, w_desc + w_rate, w_desc + w_rate + w_qty, w_desc + w_rate + w_qty + w_amnt, w_desc + w_rate + w_qty + w_amnt + w_disc, table_width ]
      x_positions.each do |x|
        # Skip outer edges when using rounded corners (they're handled by the rounded rectangle borders)
        next if corner_radius > 0 && (x == 0 || x == table_width)
        # 25pt header
        @pdf.vertical_line @pdf.cursor, @pdf.cursor - 25, at: x
      end
    end
    @pdf.line_width(1.0)

    # Bottom Header Border Line (Outline)
    unless @style == "classic"
      @pdf.stroke_color "E5E7EB"
      @pdf.line_width(1.0)
      current_cursor = @pdf.cursor
      @pdf.stroke_horizontal_line 0, table_width, at: current_cursor - 25
    end

    # Move to the bottom of the header bar (25pt)
    @pdf.move_down 25
  end

  def render_classic_row(item, total_width, w_desc, w_qty, w_rate, w_disc, w_tax, w_amnt, is_credit: false)
    # 1. Prepare Data & Arrays
    desc_text = item[:desc].to_s
    main_text = desc_text
    main_text += ":" if item[:sub_categories].present?

    desc_color = is_credit ? "DC2626" : @dark_charcoal
    # Keep identical layout for all document languages
    line_leading = 1
    font_name = (@document_language == "ka") ? "NotoSansGeorgian" : "NotoSans"

    desc_array = [ { text: main_text, styles: [ :bold ], size: 9, color: desc_color, font: font_name } ]

    sub_array = []
    if item[:sub_categories].present?
      cleaned_subs = item[:sub_categories].map { |s| s.to_s.strip }.reject(&:blank?)
      sub_block = "\n" + cleaned_subs.map { |s| "• #{s}" }.join("\n")
      sub_array = [ { text: sub_block, size: 9, color: (is_credit ? "DC2626" : @mid_gray), font: font_name } ]
    end

    # 2. Accurate Height Calculation
    measure_width = w_desc - 30
    content_h = 0
    @pdf.font(font_name) do
      combined_text = main_text
      combined_text += sub_block if sub_array.any?
      content_h = @pdf.height_of(combined_text, width: measure_width, size: 9, leading: line_leading)
    end

    min_h = 10
    content_h = [ content_h, min_h ].max

    # Standardized padding for cleaner vertical centering
    v_pad = 12
    row_h = v_pad + content_h

    check_new_page_needed(row_h)
    start_y = @pdf.cursor

    # 3. Render Description (Centered Vertically, Left Aligned Horizontally)
    @pdf.formatted_text_box(desc_array + sub_array,
      at: [ 10, start_y ],
      width: w_desc - 20,
      height: row_h,
      align: :left,
      valign: :center,
      leading: line_leading
    )

    # 4. Numeric Columns (Centered Vertically and Horizontally)
    m_qty = item[:qty].to_f
    m_qty_label = (m_qty > 0 && m_qty != 1) ? ("%g" % m_qty) : "1"
    unit_price = (item[:qty].to_f > 0) ? (item[:price].to_f / item[:qty].to_f) : item[:price].to_f

    @pdf.fill_color is_credit ? "DC2626" : @dark_charcoal
    @pdf.font(font_name, size: 9) do
      # PRICE
      p_color = is_credit ? @soft_gray : (is_credit ? "DC2626" : @dark_charcoal)
      @pdf.fill_color p_color
      p_text = is_credit ? "—" : format_money(unit_price)
      @pdf.text_box p_text, at: [ w_desc, start_y ], width: w_rate, height: row_h, align: :center, valign: :center, overflow: :shrink_to_fit, min_font_size: 7

      # QTY
      @pdf.fill_color is_credit ? "DC2626" : @dark_charcoal
      @pdf.text_box m_qty_label.to_s, at: [ w_desc + w_rate, start_y ], width: w_qty, height: row_h, align: :center, valign: :center, overflow: :shrink_to_fit, min_font_size: 7

      # AMOUNT
      @pdf.font(font_name, style: :bold) do
        @pdf.text_box format_money(item[:price].to_f), at: [ w_desc + w_rate + w_qty, start_y ], width: w_amnt, height: row_h, align: :center, valign: :center, overflow: :shrink_to_fit, min_font_size: 7
      end

      # DISCOUNT
      if !is_credit && item[:item_discount_amount].to_f > 0
        @pdf.fill_color @green_tag
        disc_val = "-#{format_money(item[:item_discount_amount])}"
        disc_val += " (#{item[:discount_percent].to_f.round(1).to_s.sub(/\.0$/, '')}%)" if item[:discount_percent].to_f > 0
        @pdf.text_box disc_val, at: [ w_desc + w_rate + w_qty + w_amnt, start_y ], width: w_disc, height: row_h, align: :center, valign: :center, style: :bold, overflow: :shrink_to_fit
      else
        @pdf.fill_color @soft_gray
        @pdf.text_box "—", at: [ w_desc + w_rate + w_qty + w_amnt, start_y ], width: w_disc, height: row_h, align: :center, valign: :center
      end

      # TAX
      @pdf.fill_color is_credit ? "DC2626" : @dark_charcoal
      if !is_credit && item[:computed_tax_amount].to_f > 0
        tax_val = "+#{format_money(item[:computed_tax_amount])}"
        tax_val += " (#{item[:tax_rate].to_f.round(1).to_s.sub(/\.0$/, '')}%)" if item[:tax_rate].to_f > 0
        @pdf.text_box tax_val, at: [ w_desc + w_rate + w_qty + w_amnt + w_disc, start_y ], width: w_tax, height: row_h, align: :center, valign: :center, overflow: :shrink_to_fit
      else
        @pdf.fill_color @soft_gray
        @pdf.text_box "—", at: [ w_desc + w_rate + w_qty + w_amnt + w_disc, start_y ], width: w_tax, height: row_h, align: :center, valign: :center
      end
    end

    @pdf.move_down row_h
    end_y = @pdf.cursor
    divider_color = "E5E7EB"
    outer_border_color = (@style == "classic") ? @orange_color : divider_color

    # Inner dividers
    @pdf.stroke_color divider_color
    @pdf.line_width(0.5)

    x_positions = [ 0, w_desc, w_desc + w_rate, w_desc + w_rate + w_qty, w_desc + w_rate + w_qty + w_amnt, w_desc + w_rate + w_qty + w_amnt + w_disc, total_width ]
    inner_positions = x_positions[1..-2]
    inner_positions.each { |x| @pdf.stroke_vertical_line start_y, end_y, at: x }

    # Outer border: accent only until DESCRIPTION ends; remainder charcoal
    border_inset = (@style == "classic") ? 0.5 : 0
    left_edge = 0 + border_inset
    right_edge = total_width - border_inset
    desc_edge = left_edge + w_desc

    # Left vertical (accent)
    @pdf.stroke_color outer_border_color
    @pdf.line_width(1.0)
    @pdf.stroke_vertical_line start_y, end_y, at: left_edge
    # Right vertical (charcoal)
    base_border_color = @charcoal
    @pdf.stroke_color base_border_color
    @pdf.stroke_vertical_line start_y, end_y, at: right_edge
    # Row separator/bottom line stays neutral to avoid accent on internal horizontals
    @pdf.stroke_color divider_color
    @pdf.line_width(0.5)
    @pdf.stroke_horizontal_line left_edge, right_edge, at: end_y
  end

  def calculate_column_widths(table_width)
    calc_results = {}

    @pdf.font("NotoSans", size: 7.5, style: :bold) do
      w_rate = @pdf.width_of(labels[:price]) + 25
      w_qty  = @pdf.width_of(labels[:qty]) + 15
      w_amnt = @pdf.width_of(labels[:amount]) + 25
      w_disc = @pdf.width_of(labels[:discount]) + 30
      w_tax  = @pdf.width_of(labels[:tax]) + 30

      # Sweep all items to find max widths
      all_items = @categorized_items.values.flatten
      if @credits.any?
        @credits.each { |c| all_items << { price: -c[:amount], qty: 1 } }
      end

      # Temp switch to measurement font size
      @pdf.font("NotoSans", size: 9) do
        all_items.each do |item|
          q_f = item[:qty].to_f > 0 ? item[:qty].to_f : 1.0
          p_v = (item[:price].to_f / q_f)

          w_rate = [ w_rate, @pdf.width_of(format_money(p_v)) + 20 ].max
          w_qty  = [ w_qty, @pdf.width_of((q_f != 1 ? ("%g" % q_f) : "1")) + 15 ].max
          w_amnt = [ w_amnt, @pdf.width_of(format_money(item[:price])) + 20 ].max

          if item[:item_discount_amount].to_f > 0
            d_s = "-#{format_money(item[:item_discount_amount])}"
            d_s += " (#{item[:discount_percent].to_f.round(1).to_s.sub(/\.0$/, '')}%)" if item[:discount_percent].to_f > 0
            w_disc = [ w_disc, @pdf.width_of(d_s) + 25 ].max
          end

          if item[:computed_tax_amount].to_f > 0
            t_s = "+#{format_money(item[:computed_tax_amount])}"
            t_s += " (#{item[:tax_rate].to_f.round(1).to_s.sub(/\.0$/, '')}%)" if item[:tax_rate].to_f > 0
            w_tax = [ w_tax, @pdf.width_of(t_s) + 25 ].max
          end
        end
      end

      fixed_total = w_rate + w_qty + w_amnt + w_disc + w_tax
      w_desc = table_width - fixed_total

      if w_desc < 180
         # Proportional scaling to preserve a minimum 180pt Description column
         scale = (table_width - 180) / fixed_total
         w_rate *= scale; w_qty *= scale; w_amnt *= scale; w_disc *= scale; w_tax *= scale
         w_desc = 180
      end

      calc_results = { prod: 0, desc: w_desc, rate: w_rate, qty: w_qty, amnt: w_amnt, disc: w_disc, tax: w_tax }
    end

    calc_results
  end

  def render_classic_summary
    # 1. Logic-Driven Row Construction (Matching Exact Requirements)
    # Order: Items Total(B) -> Item Discounts(G) -> div -> Subtotal(B) -> Inv Disc(G) -> div -> Taxable Total(B) -> Tax -> div -> Total Before Credit(B) -> Credit Applied(R) -> Big Div -> Balance Due
    rows = []

    # Tier 1: Item-level breakdown
    if @item_discount_total > 0
      rows << { label: labels[:items_total], value: format_money(@gross_subtotal), style: :bold }
      rows << { label: labels[:item_discounts], value: "-#{format_money(@item_discount_total)}", color: @green_tag, label_color: @green_tag, style: :bold }
      rows << { divider: true }
    end

    # Tier 2: The Core Subtotal
    rows << { label: labels[:subtotal], value: format_money(@net_subtotal + @global_discount_amount), style: :bold }

    # Tier 3: Invoice-level Discount
    if @global_discount_amount > 0
      disc_label = labels[:invoice_discount]
      if @log.try(:global_discount_percent).to_f > 0
        disc_label += " (-#{@log.global_discount_percent.to_f.round(1).to_s.sub(/\.0$/, '')}%)"
      end
      rows << { label: disc_label, value: "-#{format_money(@global_discount_amount)}", color: @green_tag, label_color: @green_tag, style: :bold }
      rows << { divider: true }
      rows << { label: labels[:taxable_total], value: format_money(@net_subtotal), style: :bold }
    end

    # Tier 4: Tax
    if @final_tax > 0
      rows << { label: labels[:tax], value: format_money(@final_tax), style: :bold }
      rows << { divider: true }
    end

    # Tier 5: Post-Tax Adjustments (Credits)
    if @total_credits > 0
      # Ensure there's a divider if we didn't just add one
      rows << { divider: true } unless rows.last&.dig(:divider)
      rows << { label: labels[:total_before_credit], value: format_money(@total_before_credits), style: :bold }
      rows << { label: labels[:credit_applied], value: "-#{format_money(@total_credits)}", color: "DC2626", label_color: "DC2626", style: :bold }
    end

    # Remove trailing divider if any (prevents double divider with the Big Divider)
    rows.pop while rows.last&.dig(:divider)

    # 2. Geometry & Spacing Logic
    # Tighter layout if we have many rows (item discounts + global + credits)
    # EXCEPTION: If we are not on the first page, we always use normal sizing.
    is_compact = rows.count > 6 && @pdf.page_number == 1
    # Further tighten the compact mode to free space when many summary rows are present
    row_h = is_compact ? 13.5 : 18
    divider_space = is_compact ? 4 : 8
    summary_font_size = is_compact ? 8 : 9

    summary_width = 240
    table_width = @pdf.bounds.width
    instructions_width = table_width - summary_width - 40

    # Dynamic Accent Color for Divider & Banner
    accent_color = case @style
    when "professional" then @navy
    when "modern"       then @slate
    when "bold"         then "000000"
    when "minimal"      then @mid_gray
    else @orange_color
    end

    # Calculate required height dynamically
    divider_count = rows.count { |r| r[:divider] }
    content_rows_count = rows.count { |r| !r[:divider] }
    # Match the grand total section height to: Banner (45) + Total Gaps + Extra bottom spacing (20px from footer)
    grand_total_h = 65 + (divider_space * 4.0)
    h_totals = (content_rows_count * row_h) + (divider_count * divider_space) + grand_total_h

    # Calculate instructions height to center it
    instr_block_h = 0
    @pdf.font(@base_font_name) do
      if @profile.payment_instructions.present?
        p_title_h = @pdf.height_of(labels[:payment_details], width: instructions_width, size: 10, style: :bold, character_spacing: 1)
        p_text_h = @pdf.height_of(@profile.payment_instructions, width: instructions_width, size: 9, leading: 3)
        instr_block_h += p_title_h + 5 + 2 + 10 + p_text_h
      end

      if @profile.respond_to?(:note) && @profile.note.present?
        note_gap = @profile.payment_instructions.present? ? 20 : 0
        n_text_h = @pdf.height_of(@profile.note.upcase, width: instructions_width, size: 12, style: :bold, leading: 3)
        instr_block_h += note_gap + n_text_h
      end
    end

    # 3. SIMPLE FLOW LOGIC (Dynamic gap from table)
    page_center = @pdf.bounds.top / 2
    # If cursor is above center (used less than half page), use 75px. if below (more than half), use 35px.
    item_gap = (@pdf.cursor > page_center) ? 75 : 35

    header_gap = 35
    h_final = [ h_totals, instr_block_h ].max

    # Decide if we stay on current page or move to next
    is_fresh = @pdf.cursor > (@pdf.bounds.top - 50)
    @pdf.move_down(is_fresh ? header_gap : item_gap)

    # Check if we have enough room for the summary (no extra bottom cushion)
    if @pdf.cursor < h_final
      @pdf.start_new_page
      render_continuation_header
      @pdf.move_down header_gap
    end

    # 4. Render Bounding Box
    @pdf.bounding_box([ 0, @pdf.cursor ], width: table_width, height: h_final) do
      # -- A. PAYMENT INSTRUCTIONS & NOTE --
      if @profile.payment_instructions.present? || (@profile.respond_to?(:note) && @profile.note.present?)
        # Fixed alignment: follow the top of the summary area
        @pdf.bounding_box([ 0, h_final ], width: instructions_width, height: instr_block_h) do
          if @profile.payment_instructions.present?
            @pdf.fill_color @dark_charcoal
            @pdf.font(@base_font_name, style: :bold, size: 10) { @pdf.text labels[:payment_details], character_spacing: 1 }
            @pdf.move_down 5
            @pdf.stroke_color accent_color
            @pdf.line_width(2)
            @pdf.stroke_horizontal_line 0, 50
            @pdf.move_down 10
            @pdf.fill_color @mid_gray
            @pdf.font(@base_font_name, size: 9) { @pdf.text @profile.payment_instructions, leading: 3 }
          end

          if @profile.respond_to?(:note) && @profile.note.present?
            @pdf.move_down 20 if @profile.payment_instructions.present?
            @pdf.fill_color accent_color
            @pdf.font(@base_font_name, style: :bold, size: 12) do
              @pdf.text @profile.note.upcase, leading: 3
            end
          end
        end
      end

      # -- B. HIERARCHICAL TOTALS --
      # Align with top of payment details (h_final), not h_totals
      left_x = table_width - summary_width
      current_y = h_final

      rows.each do |row|
        if row[:divider]
          current_y -= (divider_space / 2.0)
          @pdf.stroke_color "E5E7EB"
          @pdf.line_width(0.5)
          @pdf.stroke_horizontal_line left_x, table_width, at: current_y
          current_y -= (divider_space / 2.0)
          next
        end

        # Label
        @pdf.fill_color row[:label_color] || @mid_gray
        @pdf.font(@base_font_name, size: summary_font_size, style: row[:style] || :normal) do
          @pdf.text_box row[:label], at: [ left_x, current_y ], width: 140, height: row_h, align: :left, valign: :center
        end

        # Value
        @pdf.fill_color row[:color] || @dark_charcoal
        @pdf.font(@base_font_name, style: :bold, size: summary_font_size) do
          @pdf.text_box row[:value], at: [ left_x + 100, current_y ], width: 140, height: row_h, align: :right, valign: :center
        end

        current_y -= row_h
      end

      # Grand Total Section (Industrial High-Impact Banner)
      # Position dynamically after summary rows
      banner_h = 45
      banner_radius = 8  # Same radius as table corners

      # 1. Big Divider (with breathing room after summary rows)
      current_y -= (divider_space + 2.5)
      @pdf.stroke_color @charcoal
      @pdf.line_width(1.5)
      @pdf.stroke_horizontal_line left_x, table_width, at: current_y
      current_y -= (divider_space + 2.5)

      # 2. Fill Accent Banner
      @pdf.fill_color accent_color
      if @style == "classic"
        draw_bottom_rounded_rect_fill(left_x, current_y, summary_width, banner_h, banner_radius)
      else
        @pdf.fill_rectangle [ left_x, current_y ], summary_width, banner_h
      end

      # "BALANCE DUE" Label + Value (same line, vertically centered in banner)
      @pdf.fill_color "FFFFFF"
      @pdf.font(@base_font_name, style: :bold, size: 8) do
        @pdf.text_box labels[:balance_due].upcase,
                      at: [ left_x + 12, current_y ],
                      width: 130,
                      height: banner_h,
                      align: :left,
                      valign: :center,
                      character_spacing: 1.5
      end

      @pdf.font(@base_font_name, style: :bold, size: 20) do
        @pdf.text_box format_money(@total_due.to_f),
                      at: [ left_x + 10, current_y + 3 ],
                      width: summary_width - 20,
                      height: banner_h,
                      align: :right,
                      valign: :center,
                      overflow: :shrink_to_fit,
                      min_font_size: 10
      end
    end
  end

  def render_item_tag(text, bg_color, x_pos)
    tw = 0
    @pdf.font(@base_font_name, size: 7, style: :bold) do
      tw = @pdf.width_of(text) + 10
      th = 12

      # Draw box
      @pdf.fill_color bg_color
      @pdf.fill_rectangle [ x_pos, @pdf.cursor ], tw, th

      # Draw text (centered with a 1pt upward nudge for visual balance)
      @pdf.fill_color "FFFFFF"
      @pdf.text_box text, at: [ x_pos, @pdf.cursor + 1 ], width: tw, height: th, align: :center, valign: :center
    end
    tw
  end

  def sanitize_description(desc)
    d = desc.to_s.strip
    d = d.gsub(/Labor:?/i, "").gsub(/Hourly service:?/i, "").gsub(/^Service\s*-\s*/i, "").gsub(/^Fee:?/i, "").strip
    if d =~ /^I (?:re)?installed/i
      d = d.sub(/^I (?:re)?installed/i, "Installation of")
    elsif d =~ /replaced/i
      d = d.sub(/replaced/i, "Replacement of")
    elsif d =~ /fix(ed|ing)/i
      d = d.sub(/fix(ed|ing)/i, "Repair of")
    end
    d
  end

  def format_money(amount)
    amt = amount || 0
    sign = amt < 0 ? "-" : ""
    val = "%.2f" % amt.abs
    @currency_pos == "suf" ? "#{sign}#{val} #{@currency}" : "#{sign}#{@currency}#{val}"
  end

  def format_pdf_date(date)
    return date.to_s unless date.respond_to?(:strftime)

    if @document_language == "ka"
      # Georgian Month Abbreviations (Matched to ka.yml)
      months = [ "იან", "თებ", "მარ", "აპრ", "მაი", "ივნ", "ივლ", "აგვ", "სექ", "ოქტ", "ნოე", "დეკ" ]
      "#{months[date.month - 1]} #{date.day}, #{date.year}"
    else
      # Default to English format
      date.strftime("%b %d, %Y")
    end
  end



  private

  def setup_fonts
    # 1. Register Primary Fonts (Standard Noto Sans or Helvetica)
    # If the document language is Georgian, we prioritize it as the main font to avoid fallback issues
    primary_font_name = (@document_language == "ka") ? "NotoSansGeorgian" : "NotoSans"

    if File.exist?(@font_path.join("NotoSans-Regular.ttf"))
      @pdf.font_families.update("NotoSans" => {
        normal: @font_path.join("NotoSans-Regular.ttf"),
        bold: @font_path.join("NotoSans-Bold.ttf"),
        italic: @font_path.join("NotoSans-Italic.ttf"),
        bold_italic: @font_path.join("NotoSans-BoldItalic.ttf")
      })
      @pdf.font "NotoSans" # Default
    end

    if File.exist?(@font_path.join("NotoSansGeorgian-Regular.ttf"))
      @pdf.font_families.update("NotoSansGeorgian" => {
        normal: @font_path.join("NotoSansGeorgian-Regular.ttf"),
        bold: @font_path.join("NotoSansGeorgian-Bold.ttf")
      })
    end

    @pdf.font primary_font_name if @pdf.font_families.has_key?(primary_font_name)

    # 2. Register Global Fallbacks for Symbols & Mixed Languages
    additional_fonts = {
      "NotoSans"         => [ "NotoSans-Regular.ttf", "NotoSans-Bold.ttf" ],
      "NotoSansGeorgian" => [ "NotoSansGeorgian-Regular.ttf", "NotoSansGeorgian-Bold.ttf" ],
      "NotoSansArabic"   => [ "NotoSansArabic-Regular.ttf" ],
      "NotoSansArmenian" => [ "NotoSansArmenian-Regular.ttf" ],
      "NotoSansBengali"  => [ "NotoSansBengali-Regular.ttf" ],
      "NotoSansHebrew"   => [ "NotoSansHebrew-Regular.ttf" ]
    }

    fallbacks = []
    additional_fonts.each do |name, files|
      regular_file = files[0]
      bold_file = files[1] || files[0] # Fallback to regular if bold doesn't exist

      if File.exist?(@font_path.join(regular_file))
        @pdf.font_families.update(name => {
          normal: @font_path.join(regular_file),
          bold: @font_path.join(bold_file)
        })
        fallbacks << name
      end
    end

    @pdf.fallback_fonts(fallbacks) if fallbacks.any?
  end

  def setup_page_manager
    @page_manager = PageManager.new(@pdf,
      header_renderer: -> { render_continuation_header },
      currency_formatter: ->(amount) { format_money(amount) },
      orange_color: @orange_color
    )
  end

  def render_continuation_header
    @pdf.move_down 5

    # 1. Industrial Accent Square
    @pdf.fill_color @orange_color
    @pdf.fill_rectangle [ 0, @pdf.cursor ], 4, 16

    # 2. Tech Typography (Clean & Minimal)
    @pdf.indent(12) do
      @pdf.fill_color @dark_charcoal
      if @document_language == "ka"
        parts = [
          { text: "#{labels[:page]} მე-", font: "NotoSansGeorgian", styles: [:bold], size: 9, color: @dark_charcoal, character_spacing: 1.2 },
          { text: "#{@pdf.page_number}", font: "NotoSans", styles: [:bold], size: 9, color: @dark_charcoal, character_spacing: 1.2 },
          { text: "  ·  #{@invoice_number}  ·  #{@profile.business_name.upcase}", font: "NotoSans", styles: [:bold], size: 9, color: @dark_charcoal, character_spacing: 1.2 }
        ]
        @pdf.formatted_text parts
      else
        @pdf.font(@base_font_name, style: :bold, size: 9) do
          info_text = "#{labels[:page]} #{@pdf.page_number}  ·  #{@invoice_number}  ·  #{@profile.business_name.upcase}"
          @pdf.text info_text, character_spacing: 1.2
        end
      end
    end

    @pdf.move_down 15
    @pdf.fill_color "000000"
  end

  def prepare_data
    @categorized_items = { labor: [], material: [], fee: [], expense: [], other: [] }
    @item_discount_total = 0.0
    @tax_amount = 0.0

    raw_sections = if @log.tasks.is_a?(String)
                     JSON.parse(@log.tasks || "[]") rescue []
    else
                     @log.tasks || []
    end


    global_tax_rate = @profile.try(:tax_rate).to_f

    raw_sections.each do |section|
      title = section["title"].to_s.downcase
      category_key = case title
      when /labor|service|სამუშაო|მომსახურება/i then :labor
      when /material|მასალ/i then :material
      when /expense|ხარჯ/i then :expense
      when /fee|მოსაკრებ|საკომისიო|შესაკრებ/i then :fee
      else :other
      end

      if section["items"]
        section["items"].each do |item|
          raw_desc = item.is_a?(Hash) ? item["desc"] : item
          desc = sanitize_description(raw_desc)
          if desc.blank?
            if I18n.locale.to_s == "ka"
              desc = case category_key
              when :labor then "პროფესიონალური მომსახურება"
              when :material then "მასალა"
              when :expense then "ხარჯი"
              when :fee then "მოსაკრებელი"
              else "სხვა"
              end
            else
              desc = labels[category_key] || labels[:other]
            end
          end
          qty = 1.0; price = 0.0; gross_price = 0.0

          if item.is_a?(Hash)
            raw_qty = item["qty"].to_f
            raw_price = item["price"].to_f
            log_billing_mode = @log.billing_mode || "hourly"
            mode = item["mode"].presence || log_billing_mode

            if category_key == :labor
               if mode == "hourly"
                 hours = raw_price > 0 ? raw_price : (raw_qty > 0 ? raw_qty : 1.0)
                 effective_rate = item["rate"].present? ? item["rate"].to_f : (@log.try(:hourly_rate).present? ? @log.hourly_rate.to_f : @profile.hourly_rate.to_f)
                 qty = hours; price = hours * effective_rate; gross_price = price
               else
                 qty = 1; price = raw_price; gross_price = raw_price
               end
            else
               qty = raw_qty > 0 ? raw_qty : 1.0
               if qty == 1.0 && desc.present?
                 if match = desc.match(/[\(\s]x?(\d+)[\)]?$/i) || desc.match(/^(\d+)\s*x\s+/i)
                   qty = match[1].to_f
                 end
               end
               price = raw_price; gross_price = price * qty
            end

            taxable = item["taxable"] == true
            tax_rate = item["tax_rate"].present? ? item["tax_rate"].to_f : nil
            sub_categories = item["sub_categories"].is_a?(Array) ? item["sub_categories"] : []

            disc_flat = item["discount_flat"].to_f
            disc_pct = item["discount_percent"].to_f
            item_discount_amount = (disc_flat + (gross_price * disc_pct / 100.0)).round(2)
            item_discount_amount = gross_price if item_discount_amount > gross_price
            @item_discount_total += item_discount_amount

            computed_tax = 0.0
            if taxable
              effective_rate = tax_rate || global_tax_rate
              computed_tax = ([ gross_price - item_discount_amount, 0.0 ].max * (effective_rate / 100.0)).round(2)
              @tax_amount += computed_tax
            end

            @categorized_items[category_key] << {
              desc: desc, qty: qty, price: gross_price, taxable: taxable,
              tax_rate: (tax_rate || global_tax_rate),
              item_discount_amount: item_discount_amount,
              discount_percent: disc_pct,
              discount_message: item["discount_message"],
              computed_tax_amount: computed_tax,
              sub_categories: sub_categories, category: category_key
            }
          end
        end
      end
    end

    # Sum of items (Gross)
    @gross_subtotal = @categorized_items.values.flatten.sum { |i| i[:price] }

    # Global Discount logic
    g_disc_item_net_base = [ @gross_subtotal - @item_discount_total, 0 ].max
    @global_discount_amount = [ (@log.try(:global_discount_flat).to_f + (g_disc_item_net_base * @log.try(:global_discount_percent).to_f / 100.0)).round(2), g_disc_item_net_base ].min

    @final_total_discount = @item_discount_total + @global_discount_amount
    @net_subtotal = [ @gross_subtotal - @final_total_discount, 0 ].max

    # Apply Tax Rule (Pre-Tax vs Post-Tax)
    rule = @log.respond_to?(:discount_tax_rule) ? (@log.discount_tax_rule.presence || "post_tax") : (@profile.try(:discount_tax_rule).presence || "post_tax")
    @final_tax = @tax_amount
    if rule == "pre_tax"
       taxable_sum = @gross_subtotal - @item_discount_total
       if taxable_sum > 0
          @final_tax = (@tax_amount * (@net_subtotal.to_f / taxable_sum)).round(2)
       end
    end

    @credits = []
    raw_credits = if @log.respond_to?(:credits) && @log.credits.present?
                    @log.credits.is_a?(String) ? (JSON.parse(@log.credits) rescue []) : @log.credits
    else
                    []
    end

    if raw_credits.is_a?(Array) && raw_credits.present?
      raw_credits.each { |c| @credits << { reason: c["reason"].presence || I18n.t("courtesy_credit", default: "Courtesy Credit"), amount: c["amount"].to_f } if c["amount"].to_f > 0 }
    elsif (c_amt = @log.try(:credit_flat).to_f) > 0
      @credits << { reason: @log.try(:credit_reason).presence || I18n.t("courtesy_credit", default: "Courtesy Credit"), amount: c_amt }
    end

    @total_credits = @credits.sum { |c| c[:amount] }
    @total_before_credits = @net_subtotal + @final_tax
    @total_due = @total_before_credits - @total_credits

    # Standardize incoming date strings (ISO or English) and format for PDF language
    raw_date = @log.date.presence || Date.today.to_s
    parsed_date = Date.parse(raw_date.to_s) rescue Date.today
    @invoice_date = format_pdf_date(parsed_date)

    raw_due = @log.due_date.presence || (parsed_date + 14.days).to_s
    parsed_due = Date.parse(raw_due.to_s) rescue (parsed_date + 14.days)
    @due_date = format_pdf_date(parsed_due)

    @invoice_id_display = @log.display_number
    @invoice_number = "#{labels[:invoice_prefix]}-#{@invoice_id_display}"
  end

  def check_new_page_needed(needed_height)
    # Footer occupies approximately 25pt from the bottom (footer text at footer_y=35, with margin padding)
    footer_reserved_space = 25

    # Prawn's cursor 0 is at the bottom margin.
    # If the cursor is less than what we need PLUS footer space, break to new page.
    if @pdf.cursor < (needed_height + footer_reserved_space)
       # Before breaking to new page, apply rounded bottom corners to the current page's table portion
       if @style == "classic" && @table_widths.present? && @table_corner_radius.to_i > 0
         apply_table_bottom_rounded_corners(@pdf.bounds.width, @pdf.cursor, @table_corner_radius)
       end

       @pdf.start_new_page
       render_continuation_header
       # If we are in the middle of a table, repeat the header
       if @table_widths.present?
         @pdf.move_down 10
         render_table_header(@pdf.bounds.width, @table_widths)
       end
    end
  end

  def render_professional
    @pdf.fill_color "000000"

    # -- 1. Corporate Bleed Header --
    @pdf.canvas do
      page_top = @pdf.bounds.top
      page_width = @pdf.bounds.width

      @pdf.fill_color @navy
      @pdf.fill_rectangle [ 0, page_top ], page_width, 70

      @pdf.fill_color "FFFFFF"
      @pdf.font(@base_font_name, style: :bold) do
        @pdf.text_box labels[:invoice], at: [ 50, page_top + 4 ], size: 30, height: 70, valign: :center, character_spacing: 2
      end

      @pdf.font(@base_font_name, style: :bold) do
        @pdf.text_box @invoice_number, at: [ page_width - 250, page_top + 4 ], size: 18, height: 70, valign: :center, align: :right, width: 200
      end
    end

    @pdf.move_down 65

    y_start = @pdf.cursor
    total_width = @pdf.bounds.width
    gap = 20
    col_width = (total_width - gap) / 2

    # Left: Client Info
    @pdf.bounding_box([ 0, y_start ], width: col_width) do
      @pdf.fill_color @navy
      @pdf.font(@base_font_name, size: 7, style: :bold) do
        @pdf.text labels[:client], character_spacing: 1
      end
      @pdf.move_down 8
      @pdf.fill_color "000000"
      @pdf.font(@base_font_name, style: :bold, size: 11) do
        @pdf.text (@log.client.presence || "VALUED CLIENT").upcase, leading: 2
      end
      @pdf.move_down 5
      @pdf.fill_color @mid_gray
      @pdf.font(@base_font_name, size: 9) do
        @pdf.text (@log.try(:address).presence || "").to_s, leading: 2
      end
    end

    # Right: Sender & Dates
    @pdf.bounding_box([ col_width + gap, y_start ], width: col_width) do
      @pdf.fill_color @navy
      @pdf.font(@base_font_name, size: 7, style: :bold) do
        @pdf.text labels[:sender], character_spacing: 1, align: :right
      end
      @pdf.move_down 8
      @pdf.fill_color "000000"
      @pdf.font(@base_font_name, style: :bold, size: 10) do
        @pdf.text @profile.business_name, align: :right, leading: 2
      end
      @pdf.font(@base_font_name, size: 8) do
        @pdf.fill_color @mid_gray
        @pdf.text @profile.address.to_s, align: :right, leading: 1
        @pdf.text "#{@profile.phone}  |  #{@profile.email}", align: :right, leading: 1
      end

      @pdf.move_down 15
      @pdf.stroke_color @soft_gray
      @pdf.stroke_horizontal_line col_width - 150, col_width, at: @pdf.cursor
      @pdf.move_down 10

      @pdf.fill_color "000000"
      @pdf.font(@base_font_name, size: 8) do
        @pdf.text_box "#{labels[:date]}:", at: [ col_width - 150, @pdf.cursor ], width: 70, align: :left, style: :bold
        @pdf.text_box @invoice_date, at: [ col_width - 80, @pdf.cursor ], width: 80, align: :right
        @pdf.move_down 12
        @pdf.text_box "#{labels[:due_date]}:", at: [ col_width - 150, @pdf.cursor ], width: 70, align: :left, style: :bold, color: @navy
        @pdf.text_box @due_date, at: [ col_width - 80, @pdf.cursor ], width: 80, align: :right, color: @navy
      end
    end

    @pdf.move_cursor_to y_start - 160
    render_classic_flow_table # We'll start with classic table but maybe tweak it
    render_classic_summary
  end
  def render_modern
    @pdf.fill_color "000000"

    # -- 1. Minimalist Geometric Header --
    y_header = @pdf.cursor
    @pdf.font(@base_font_name, style: :bold) do
      @pdf.fill_color @soft_gray
      @pdf.text labels[:invoice], size: 42, character_spacing: 1
    end

    @pdf.move_cursor_to y_header + 5
    @pdf.font(@base_font_name, style: :bold) do
      @pdf.fill_color @dark_charcoal
      @pdf.text @invoice_number, size: 10, align: :right, character_spacing: 1
      @pdf.move_down 2
      @pdf.fill_color @mid_gray
      @pdf.text "#{labels[:issued]}: #{@invoice_date}", size: 7, align: :right, character_spacing: 0.5
    end

    @pdf.move_down 50

    # Layout
    y_start = @pdf.cursor
    col_width = (@pdf.bounds.width - 20) / 2

    @pdf.bounding_box([ 0, y_start ], width: col_width) do
      @pdf.fill_color "000000"
      @pdf.font(@base_font_name, size: 7, style: :bold) do
        @pdf.text labels[:bill_to], character_spacing: 2
      end
      @pdf.move_down 10
      @pdf.font(@base_font_name, style: :bold, size: 12) do
        @pdf.text (@log.client.presence || "CLIENT").upcase
      end
      @pdf.move_down 4
      @pdf.font(@base_font_name, size: 9) do
        @pdf.fill_color @mid_gray
        @pdf.text (@log.try(:address).presence || "").to_s
      end
    end

    @pdf.bounding_box([ col_width + 20, y_start ], width: col_width) do
      @pdf.fill_color "000000"
      @pdf.font(@base_font_name, size: 7, style: :bold) do
        @pdf.text labels[:from], character_spacing: 2, align: :right
      end
      @pdf.move_down 10
      @pdf.font(@base_font_name, style: :bold, size: 10) do
        @pdf.text @profile.business_name, align: :right
      end
      @pdf.font(@base_font_name, size: 8) do
        @pdf.fill_color @mid_gray
        @pdf.text @profile.email.to_s, align: :right
        @pdf.text @profile.phone.to_s, align: :right
      end
    end

    @pdf.move_down 30

    # Modern "Summary" Bar before table
    @pdf.fill_color @modern_gray
    @pdf.fill_rectangle [ 0, @pdf.cursor ], @pdf.bounds.width, 40
    @pdf.fill_color @black_tag
    @pdf.font(@base_font_name, style: :bold, size: 7) do
      @pdf.text_box labels[:due_date], at: [ 15, @pdf.cursor - 10 ], width: 100
      @pdf.text_box labels[:balance_due], at: [ @pdf.bounds.width - 110, @pdf.cursor - 10 ], width: 100, align: :right
    end
    @pdf.font(@base_font_name, style: :bold, size: 11) do
      @pdf.text_box @due_date, at: [ 15, @pdf.cursor - 22 ], width: 150
      @pdf.text_box format_money(@total_due), at: [ @pdf.bounds.width - 160, @pdf.cursor - 22 ], width: 150, align: :right
    end

    @pdf.move_down 60
    render_classic_flow_table
    render_classic_summary
  end

  def render_bold
    @pdf.fill_color "000000"

    # -- 1. High-Contrast Brutalist Header --
    @pdf.font(@base_font_name, style: :bold) do
      @pdf.text labels[:invoice], size: 64, character_spacing: -2, leading: -10
    end

    @pdf.move_down 5
    @pdf.line_width(5)
    @pdf.stroke_horizontal_line 0, @pdf.bounds.width
    @pdf.move_down 30

    y_start = @pdf.cursor
    col_width = (@pdf.bounds.width - 40) / 2

    @pdf.bounding_box([ 0, y_start ], width: col_width) do
      @pdf.font(@base_font_name, size: 10, style: :bold) do
        @pdf.text labels[:billed_to], character_spacing: 1
      end
      @pdf.move_down 5
      @pdf.font(@base_font_name, style: :bold, size: 16) do
        @pdf.text (@log.client.presence || "CLIENT").upcase, leading: 2
      end
    end

    @pdf.bounding_box([ col_width + 40, y_start ], width: col_width) do
      @pdf.font(@base_font_name, size: 8, style: :bold) do
        @pdf.text "#{labels[:from]}: #{@profile.business_name.upcase}", align: :right, leading: 2
        @pdf.text "INV: #{@invoice_number}", align: :right, leading: 2
        @pdf.text "#{labels[:date]}: #{@invoice_date}", align: :right, leading: 2
        @pdf.text "#{labels[:due]}: #{@due_date}", align: :right, leading: 2, color: @orange_color
      end
    end

    @pdf.move_down 40

    # Bold Table - customize line width temporarily
    old_width = @pdf.line_width
    @pdf.line_width(2)
    render_classic_flow_table
    @pdf.line_width(old_width)

    render_classic_summary
  end

  def render_minimal
    @pdf.fill_color @mid_gray

    # -- 1. Clean Understated Header --
    @pdf.font(@base_font_name, style: :bold) do
      @pdf.text labels[:invoice], size: 16, character_spacing: 5
    end

    @pdf.move_down 5
    @pdf.stroke_color @soft_gray
    @pdf.line_width(0.5)
    @pdf.stroke_horizontal_line 0, @pdf.bounds.width
    @pdf.move_down 30

    y_start = @pdf.cursor
    col_width = (@pdf.bounds.width - 20) / 2

    @pdf.bounding_box([ 0, y_start ], width: col_width) do
      @pdf.font(@base_font_name, size: 8, style: :bold) do
        @pdf.text "#{labels[:billed_to]}:", character_spacing: 1
      end
      @pdf.move_down 5
      @pdf.font(@base_font_name, style: :bold, size: 10) do
        @pdf.fill_color "000000"
        @pdf.text (@log.client.presence || "CLIENT").upcase, leading: 2
      end
      @pdf.font(@base_font_name, size: 8) do
        @pdf.fill_color @mid_gray
        @pdf.text (@log.try(:address).presence || "").to_s
      end
    end

    @pdf.bounding_box([ col_width + 20, y_start ], width: col_width) do
      @pdf.font(@base_font_name, size: 8, style: :bold) do
        @pdf.text @profile.business_name, align: :right, leading: 2
      end
      @pdf.fill_color @mid_gray
      @pdf.font(@base_font_name, size: 7, style: :bold) do
        @pdf.text "No. #{@invoice_number}", align: :right, leading: 1
      end
      @pdf.font(@base_font_name, size: 7) do
        @pdf.text "Issued: #{@invoice_date}", align: :right, leading: 1
        @pdf.text "Due: #{@due_date}", align: :right, leading: 1
      end
    end

    @pdf.move_down 40

    # Table - thinner line
    old_width = @pdf.line_width
    @pdf.line_width(0.3)
    render_classic_flow_table
    @pdf.line_width(old_width)

    render_classic_summary
  end

  # Helper method to draw a rectangle with only top corners rounded
  def draw_top_rounded_rect(x, y, width, height, radius, round_left: true, round_right: true)
    @pdf.save_graphics_state
    # Bezier approximation constant for quarter circle
    k = 0.5522847498
    # Start from bottom-left
    @pdf.move_to(x, y - height)
    # Bottom line (left to right)
    @pdf.line_to(x + width, y - height)
    # Right side up
    if round_right
      @pdf.line_to(x + width, y - radius)
      # Top-right rounded corner: curve from right side up and to the left
      @pdf.curve_to([ x + width - radius, y ], bounds: [ [ x + width, y - radius * (1 - k) ], [ x + width - radius * (1 - k), y ] ])
    else
      @pdf.line_to(x + width, y)
    end
    # Top line (right to left)
    if round_left
      @pdf.line_to(x + radius, y)
      # Top-left rounded corner: curve from top line down and to the left
      @pdf.curve_to([ x, y - radius ], bounds: [ [ x + radius * (1 - k), y ], [ x, y - radius * (1 - k) ] ])
    else
      @pdf.line_to(x, y)
    end
    # Left side down to start
    @pdf.line_to(x, y - height)
    @pdf.fill
    @pdf.restore_graphics_state
  end

  # Helper method to draw a FILLED rectangle with only bottom corners rounded
  def draw_bottom_rounded_rect_fill(x, y, width, height, radius)
    @pdf.save_graphics_state
    # Bezier approximation constant for quarter circle
    k = 0.5522847498
    # Start from top-left
    @pdf.move_to(x, y)
    # Top line (left to right)
    @pdf.line_to(x + width, y)
    # Right side down
    @pdf.line_to(x + width, y - height + radius)
    # Bottom-right rounded corner
    @pdf.curve_to([ x + width - radius, y - height ], bounds: [ [ x + width, y - height + radius * (1 - k) ], [ x + width - radius * (1 - k), y - height ] ])
    # Bottom line (right to left)
    @pdf.line_to(x + radius, y - height)
    # Bottom-left rounded corner
    @pdf.curve_to([ x, y - height + radius ], bounds: [ [ x + radius * (1 - k), y - height ], [ x, y - height + radius * (1 - k) ] ])
    # Left side up to start
    @pdf.line_to(x, y)
    @pdf.fill
    @pdf.restore_graphics_state
  end

  # Helper method to draw a rectangle with only bottom corners rounded
  def draw_bottom_rounded_rect_border(x, y, width, height, radius)
    @pdf.save_graphics_state
    # Start from top-left
    @pdf.move_to(x, y)
    # Left side down
    @pdf.line_to(x, y - height + radius)
    # Bottom-left rounded corner
    @pdf.curve_to([ x + radius, y - height ], bounds: [ [ x, y - height ], [ x + radius, y - height ] ])
    # Bottom line (left to right)
    @pdf.line_to(x + width - radius, y - height)
    # Bottom-right rounded corner
    @pdf.curve_to([ x + width, y - height + radius ], bounds: [ [ x + width - radius, y - height ], [ x + width, y - height ] ])
    # Right side up
    @pdf.line_to(x + width, y)
    @pdf.stroke
    @pdf.restore_graphics_state
  end

  # Helper method to draw top border with rounded corners
  def draw_top_rounded_border(x, y, width, radius)
    @pdf.save_graphics_state
    # Bezier approximation constant for quarter circle
    k = 0.5522847498
    # Start from left side, below where the curve begins
    @pdf.move_to(x, y - radius)
    # Top-left rounded corner: curve from left side up and to the right
    @pdf.curve_to([ x + radius, y ], bounds: [ [ x, y - radius * (1 - k) ], [ x + radius * (1 - k), y ] ])
    # Top line (left to right)
    @pdf.line_to(x + width - radius, y)
    # Top-right rounded corner: curve from top line down and to the right
    @pdf.curve_to([ x + width, y - radius ], bounds: [ [ x + width - radius * (1 - k), y ], [ x + width, y - radius * (1 - k) ] ])
    @pdf.stroke
    @pdf.restore_graphics_state
  end

  # Helper method to draw bottom border with rounded corners
  def draw_bottom_rounded_border(x, y, width, radius)
    @pdf.save_graphics_state
    # Bezier approximation constant for quarter circle
    k = 0.5522847498
    # Start from left side, at the point where the curve will begin (above the corner)
    @pdf.move_to(x, y + radius)
    # Bottom-left rounded corner: curve from left side down and to the right
    @pdf.curve_to([ x + radius, y ], bounds: [ [ x, y + radius * (1 - k) ], [ x + radius * (1 - k), y ] ])
    # Bottom line (left to right)
    @pdf.line_to(x + width - radius, y)
    # Bottom-right rounded corner: curve from bottom line up and to the right
    @pdf.curve_to([ x + width, y + radius ], bounds: [ [ x + width - radius * (1 - k), y ], [ x + width, y + radius * (1 - k) ] ])
    @pdf.stroke
    @pdf.restore_graphics_state
  end

  # Helper to apply rounded bottom corners overlay (covers sharp corners with white fills and redraws rounded)
  def apply_table_bottom_rounded_corners(table_width, table_bottom_y, radius)
    return unless @style == "classic" && radius > 0

    divider_color = "E5E7EB"
    outer_border_color = (@style == "classic") ? @orange_color : divider_color

    border_inset = 0.5
    left_edge = 0 + border_inset
    right_edge = table_width - border_inset
    width_adjusted = table_width - (border_inset * 2)
    desc_edge = left_edge + (@table_widths[:desc] || 0)
    base_border_color = @charcoal
    k = 0.5522847498

    # 1. Use white fills to mask the sharp bottom corners
    @pdf.fill_color "FFFFFF"

    # Bottom-left corner mask - positioned at the very corner, not extending into content
    # Only extends inward by the radius amount to cover the corner intersection
    @pdf.fill_rectangle [ -1 + border_inset, table_bottom_y + radius + 1 ], radius + 2, radius + 2

    # Bottom-right corner mask
    @pdf.fill_rectangle [ right_edge - radius + (border_inset - 1), table_bottom_y + radius + 1 ], radius + 2, radius + 2

    # 2. Redraw the vertical side borders from above the mask down to where the curve starts
    @pdf.stroke_color outer_border_color
    @pdf.line_width(1.0)
    # Left vertical line - short segment connecting to the rounded corner
    @pdf.stroke_vertical_line table_bottom_y + radius + 2, table_bottom_y + radius, at: left_edge
    # Right vertical line
    @pdf.stroke_color base_border_color
    @pdf.stroke_vertical_line table_bottom_y + radius + 2, table_bottom_y + radius, at: right_edge

    # 3. Draw the bottom border split: accent through DESCRIPTION, charcoal for remainder
    # Left segment with left rounded corner (accent)
    @pdf.save_graphics_state
    @pdf.stroke_color outer_border_color
    @pdf.line_width(1.0)
    @pdf.move_to(left_edge, table_bottom_y + radius)
    @pdf.curve_to([ left_edge + radius, table_bottom_y ], bounds: [ [ left_edge, table_bottom_y + radius * (1 - k) ], [ left_edge + radius * (1 - k), table_bottom_y ] ])
    @pdf.line_to(desc_edge, table_bottom_y)
    @pdf.stroke
    @pdf.restore_graphics_state

    # Right segment including right rounded corner (charcoal)
    @pdf.save_graphics_state
    @pdf.stroke_color base_border_color
    @pdf.line_width(1.0)
    @pdf.move_to(desc_edge, table_bottom_y)
    @pdf.line_to(right_edge - radius, table_bottom_y)
    @pdf.curve_to([ right_edge, table_bottom_y + radius ], bounds: [ [ right_edge - radius * (1 - k), table_bottom_y ], [ right_edge, table_bottom_y + radius * (1 - k) ] ])
    @pdf.stroke
    @pdf.restore_graphics_state
  end

  def add_footer
    @pdf.page_count.times do |i|
      @pdf.go_to_page(i + 1)

      @pdf.canvas do
        footer_y = 35
        page_w = @pdf.bounds.width
        margin = 40

        # Divider
        @pdf.stroke_color @soft_gray
        @pdf.line_width(0.5)
        @pdf.stroke_horizontal_line margin, page_w - margin, at: footer_y + 12

        # Color Accent
        accent_color = case @style
        when "professional" then @navy
        when "modern" then @black_tag
        when "bold" then "000000"
        when "minimal" then @soft_gray
        else @orange_color
        end
        @pdf.fill_color accent_color
        @pdf.fill_rectangle [ margin, footer_y + 12 ], 8, 2

        @pdf.fill_color @mid_gray
        @pdf.font(@base_font_name, size: 6.5, style: :bold) do
          @pdf.text_box @profile.business_name.upcase,
            at: [ margin, footer_y ], width: 200, align: :left, character_spacing: 0.5
        end

        @pdf.fill_color @dark_charcoal
        if @document_language == "ka"
          next if @pdf.page_count == 1
          parts = if (i + 1) == 1
            [
              { text: "#{@pdf.page_count}", font: "NotoSans", styles: [:bold], size: 7, color: @dark_charcoal, character_spacing: 1 },
              { text: " გვერდიდან ", font: "NotoSansGeorgian", styles: [:bold], size: 7, color: @dark_charcoal, character_spacing: 1 },
              { text: "1", font: "NotoSans", styles: [:bold], size: 7, color: @dark_charcoal, character_spacing: 1 },
              { text: "-ლი #{labels[:page]}", font: "NotoSansGeorgian", styles: [:bold], size: 7, color: @dark_charcoal, character_spacing: 1 }
            ]
          else
            [
              { text: "#{@pdf.page_count}", font: "NotoSans", styles: [:bold], size: 7, color: @dark_charcoal, character_spacing: 1 },
              { text: " გვერდიდან მე-", font: "NotoSansGeorgian", styles: [:bold], size: 7, color: @dark_charcoal, character_spacing: 1 },
              { text: "#{i + 1}", font: "NotoSans", styles: [:bold], size: 7, color: @dark_charcoal, character_spacing: 1 },
              { text: " #{labels[:page]}", font: "NotoSansGeorgian", styles: [:bold], size: 7, color: @dark_charcoal, character_spacing: 1 }
            ]
          end
          @pdf.formatted_text_box parts, at: [ page_w - margin - 150, footer_y ], width: 150, height: 10, align: :right
        else
          @pdf.font(@base_font_name, style: :bold, size: 7) do
            page_text = "#{labels[:page]} #{i + 1} #{labels[:of]} #{@pdf.page_count}"
            @pdf.text_box page_text, at: [ page_w - margin - 150, footer_y ], width: 150, align: :right, character_spacing: 1
          end
        end
      end
    end
  end
end
