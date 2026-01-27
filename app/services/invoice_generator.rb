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
    @orange_color = "F97316"
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

  def render_classic
    @pdf.fill_color "000000"

    # -- 1. High-Impact Bleed Header (Full Width Bar) --
    @pdf.canvas do
      page_top = @pdf.bounds.top
      page_width = @pdf.bounds.width

      @pdf.fill_color @charcoal
      # Rectangle covers the top 80pt of the page
      @pdf.fill_rectangle [ 0, page_top ], page_width, 80

      @pdf.fill_color "FFFFFF"
      @pdf.font("NotoSans", style: :bold) do
        # Optical Correction: Nudged UP for better visual centering in the 80pt bar
        @pdf.text_box "INVOICE", at: [ 50, page_top + 6 ], size: 36, height: 80, valign: :center, character_spacing: 8
      end

      @pdf.fill_color @orange_color
      @pdf.font("NotoSans", style: :bold) do
        # Optical Correction: Nudged UP to match the primary label alignment
        @pdf.text_box @invoice_number, at: [ page_width - 250, page_top + 6 ], size: 24, height: 80, valign: :center, align: :right, width: 200
      end
    end

    # Advance document cursor past the absolute header
    @pdf.move_down 75

    # -- 2. Clean Correspondence Layout --
    # Left: Client (The primary focus)
    # Right: Sender & Dates (Meta info, right-aligned)

    y_start = @pdf.cursor

    # Calculate column widths (50% split with a gap)
    total_width = @pdf.bounds.width
    gap = 20
    col_width = (total_width - gap) / 2

    # -- LEFT COLUMN: BILLED TO + FROM (Stacked) --
    @pdf.bounding_box([ 0, y_start ], width: col_width) do
      # 1. BILLED TO
      pill_width = 60
      pill_height = 15

      # Pill
      @pdf.fill_color @orange_color
      @pdf.fill_rounded_rectangle [ 0, @pdf.cursor ], pill_width, pill_height, 2
      @pdf.fill_color "FFFFFF"
      @pdf.font("NotoSans", size: 6, style: :bold) do
        @pdf.text_box "BILLED TO", at: [ 0, @pdf.cursor - 4 ], width: pill_width, height: pill_height, align: :center, character_spacing: 0.5
      end

      @pdf.move_down 20

      # Client Content
      @pdf.fill_color @dark_charcoal
      @pdf.font("NotoSans", style: :bold, size: 10) do
        client_name = (@log.client.presence || "VALUED CLIENT").upcase
        @pdf.text client_name, leading: 2
      end

      @pdf.move_down 25

      # 2. FROM (Under Billed To)
      pill_width_from = 40

      # Pill
      @pdf.fill_color @soft_gray
      @pdf.fill_rounded_rectangle [ 0, @pdf.cursor ], pill_width_from, pill_height, 2
      @pdf.fill_color @dark_charcoal
      @pdf.font("NotoSans", size: 6, style: :bold) do
        @pdf.text_box "FROM", at: [ 0, @pdf.cursor - 4 ], width: pill_width_from, height: pill_height, align: :center, character_spacing: 0.5
      end

      @pdf.move_down 20

      # Sender Content (Left Aligned now)
      @pdf.fill_color @dark_charcoal
      @pdf.font("NotoSans", size: 9) do
        # Company Name + Black Dot + Tax ID
        name_text = []
        name_text << { text: @profile.business_name, styles: [ :bold ], color: @dark_charcoal }
        if @profile.tax_id.present?
           name_text << { text: "  ", color: @dark_charcoal }
           name_text << { text: "•", color: "000000" }
           name_text << { text: "  Tax ID: #{@profile.tax_id}", color: @dark_charcoal }
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
    end

    # -- RIGHT COLUMN: DATES (ISSUED / DUE) --
    # Right-aligned content
    @pdf.bounding_box([ col_width + gap, y_start ], width: col_width) do
      date_pill_width = 45
      date_val_width = 100
      pill_height = 15

      # 1. ISSUED
      # Calculate X positions for right alignment
      # [Date Value] [Pill] | (Right Edge)
      x_edge = @pdf.bounds.width
      x_pill = x_edge - date_pill_width
      x_value = x_pill - date_val_width - 10

      current_y = @pdf.cursor

      # Background Pill
      @pdf.fill_color @soft_gray
      @pdf.fill_rounded_rectangle [ x_pill, current_y ], date_pill_width, pill_height, 2

      # Label
      @pdf.fill_color @dark_charcoal
      @pdf.font("NotoSans", size: 6, style: :bold) do
        @pdf.text_box "ISSUED", at: [ x_pill, current_y - 4 ], width: date_pill_width, height: pill_height, align: :center, character_spacing: 0.5
      end

      # Value
      @pdf.fill_color @dark_charcoal
      @pdf.font("NotoSans", size: 9, style: :bold) do
        @pdf.text_box @invoice_date, at: [ x_value, current_y - 2.5 ], width: date_val_width, align: :right
      end

      @pdf.move_down 25
      current_y = @pdf.cursor

      # 2. DUE
      # Background Pill
      @pdf.fill_color @orange_color
      @pdf.fill_rounded_rectangle [ x_pill, current_y ], date_pill_width, pill_height, 2

      # Label
      @pdf.fill_color "FFFFFF"
      @pdf.font("NotoSans", size: 6, style: :bold) do
        @pdf.text_box "DUE", at: [ x_pill, current_y - 4 ], width: date_pill_width, height: pill_height, align: :center, character_spacing: 0.5
      end

      # Value
      @pdf.fill_color @dark_charcoal
      @pdf.font("NotoSans", size: 9, style: :bold) do
        @pdf.text_box @due_date, at: [ x_value, current_y - 2.5 ], width: date_val_width, align: :right
      end

      @pdf.move_down 20

      # Logo Integration (Right Aligned under DUE)
      if @profile.logo.attached?
        begin
            @pdf.image StringIO.new(@profile.logo.download), height: 120, position: :right
        rescue => _e
        end
      end
    end

    @pdf.move_cursor_to y_start - 180
    render_classic_flow_table
    render_classic_summary
  end

  def render_classic_flow_table
    table_width = @pdf.bounds.width

    widths = calculate_column_widths(table_width)
    w_prod = widths[:prod]
    w_desc = widths[:desc]
    w_rate = widths[:rate]
    w_qty  = widths[:qty]
    w_amnt = widths[:amnt]
    w_disc = widths[:disc]
    w_tax  = widths[:tax]

    # Ensure there is room for at least the header + a small row cushion
    check_new_page_needed(60)

    # Top Border Line
    @pdf.stroke_color @soft_gray
    @pdf.line_width(1.0)
    @pdf.stroke_horizontal_line 0, table_width, at: @pdf.cursor

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

    # 1. Base Header
    @pdf.fill_color header_base_color
    @pdf.fill_rectangle [ 0, @pdf.cursor ], table_width, 25

    # 2. DESCRIPTION Anchor Box
    @pdf.fill_color header_accent_color
    @pdf.fill_rectangle [ w_prod, @pdf.cursor ], w_desc, 25

    header_h = 25
    @pdf.font("NotoSans", style: :bold, size: 7.5) do
      @pdf.fill_color "FFFFFF"

      # TYPE (Centered) and DESCRIPTION (Left)
      @pdf.text_box "TYPE", at: [ 0, @pdf.cursor ], width: w_prod, height: header_h, align: :center, valign: :center
      @pdf.text_box "DESCRIPTION", at: [ w_prod + 10, @pdf.cursor ], width: w_desc - 20, height: header_h, align: :left, valign: :center
      @pdf.text_box "PRICE", at: [ w_prod + w_desc, @pdf.cursor ], width: w_rate, height: header_h, align: :center, valign: :center
      @pdf.text_box "QTY", at: [ w_prod + w_desc + w_rate, @pdf.cursor ], width: w_qty, height: header_h, align: :center, valign: :center
      @pdf.text_box "AMOUNT", at: [ w_prod + w_desc + w_rate + w_qty, @pdf.cursor ], width: w_amnt, height: header_h, align: :center, valign: :center
      @pdf.text_box "DISCOUNT", at: [ w_prod + w_desc + w_rate + w_qty + w_amnt, @pdf.cursor ], width: w_disc, height: header_h, align: :center, valign: :center
      @pdf.text_box "TAX", at: [ w_prod + w_desc + w_rate + w_qty + w_amnt + w_disc, @pdf.cursor ], width: w_tax, height: header_h, align: :center, valign: :center
    end

    # Header Vertical Dividers (Standardized)
    @pdf.stroke_color "E5E7EB"
    @pdf.line_width(0.5)
    @pdf.stroke do
      x_positions = [ 0, w_prod, w_prod + w_desc, w_prod + w_desc + w_rate, w_prod + w_desc + w_rate + w_qty, w_prod + w_desc + w_rate + w_qty + w_amnt, w_prod + w_desc + w_rate + w_qty + w_amnt + w_disc, table_width ]
      x_positions.each do |x|
        # 25pt header
        @pdf.vertical_line @pdf.cursor, @pdf.cursor - 25, at: x
      end
    end
    @pdf.line_width(1.0)

    # Bottom Header Border Line (Outline)
    @pdf.stroke_color "E5E7EB"
    @pdf.line_width(1.0)
    current_cursor = @pdf.cursor
    @pdf.stroke_horizontal_line 0, table_width, at: current_cursor - 25

    # Move to the bottom of the header bar (25pt)
    @pdf.move_down 25

    categories = [
       { key: :labor, title: "Service" },
       { key: :material, title: "Material" },
       { key: :fee, title: "Fee" },
       { key: :expense, title: "Expense" },
       { key: :other, title: "Other" }
    ]

    categories.each do |cat|
      items = @categorized_items[cat[:key]]
      next if items.empty?

      items.each do |item|
        render_classic_row(item, table_width, w_prod, w_desc, w_qty, w_rate, w_disc, w_tax, w_amnt, cat[:title].upcase)
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
        render_classic_row(credit_data, table_width, w_prod, w_desc, w_qty, w_rate, w_disc, w_tax, w_amnt, "CREDIT", is_credit: true)
      end
    end
  end

  def render_classic_row(item, total_width, w_prod, w_desc, w_qty, w_rate, w_disc, w_tax, w_amnt, category_title, is_credit: false)
    # 1. Calculate dynamic height
    desc_text = item[:desc].to_s
    main_text = desc_text
    main_text += ":" if item[:sub_categories].present?

    # Calculate main description height (size 9)
    # Reduced leading from 2 to 1 for a tighter industrial feel
    desc_h = @pdf.height_of(main_text, width: w_desc - 20, size: 9, style: :bold, leading: 1)

    sub_h = 0
    if item[:sub_categories].present?
      cleaned_subs = item[:sub_categories].map { |s| s.to_s.strip }.reject(&:blank?)
      sub_block = "\n" + cleaned_subs.map { |s| "• #{s}" }.join("\n")
      # Use leading: 1 to match the formatted_text_box render for accurate measurement
      sub_h = @pdf.height_of(sub_block, width: w_desc - 20, size: 9, leading: 1)
    end

    content_h = [ desc_h + sub_h, 10 ].max
    # Total row height: content + 8pt vertical padding (4 top, 4 bottom)
    row_h = 8 + content_h

    check_new_page_needed(row_h)
    start_y = @pdf.cursor
    # available_h is the space from our top padding to the bottom line
    # We used to offset by 4, but for valign: :center we use the full row_h
    available_h = row_h

    # 2. TYPE (Centered Vertically and Horizontally)
    @pdf.fill_color is_credit ? "DC2626" : "000000"
    @pdf.text_box category_title, at: [ 0, start_y ], width: w_prod, height: available_h, align: :center, valign: :center, size: 8, style: :bold, character_spacing: 0.5

    # 3. DESCRIPTION (Top Aligned via formatted_text_box)
    desc_color = is_credit ? "DC2626" : @dark_charcoal
    main_text = desc_text
    main_text += ":" if item[:sub_categories].present?
    desc_array = [ { text: main_text, styles: [ :bold ], size: 9, color: desc_color } ]

    if item[:sub_categories].present?
      cleaned_subs = item[:sub_categories].map { |s| s.to_s.strip }.reject(&:blank?)
      sub_block = "\n" + cleaned_subs.map { |s| "• #{s}" }.join("\n")
      desc_array << { text: sub_block, size: 9, color: (is_credit ? "DC2626" : @mid_gray) }
    end

    @pdf.formatted_text_box(desc_array,
      at: [ w_prod + 10, start_y ],
      width: w_desc - 20,
      height: available_h,
      align: :left,
      valign: :center,
      leading: 1
    )

    # 4. Right-side Numeric Columns (Now Top Aligned)
    m_qty = item[:qty].to_f
    m_qty_label = (m_qty > 0 && m_qty != 1) ? ("%g" % m_qty) : "1"
    unit_price = (item[:qty].to_f > 0) ? (item[:price].to_f / item[:qty].to_f) : item[:price].to_f

    @pdf.fill_color is_credit ? "DC2626" : @dark_charcoal
    @pdf.font("NotoSans", size: 9) do
      # PRICE
      if is_credit
        @pdf.fill_color @soft_gray
        @pdf.text_box "—", at: [ w_prod + w_desc, start_y ], width: w_rate, height: available_h, align: :center, valign: :center
      else
        @pdf.text_box format_money(unit_price), at: [ w_prod + w_desc, start_y ], width: w_rate, height: available_h, align: :center, valign: :center
      end

      # QTY
      @pdf.fill_color is_credit ? "DC2626" : @dark_charcoal
      @pdf.text_box m_qty_label.to_s, at: [ w_prod + w_desc + w_rate, start_y ], width: w_qty, height: available_h, align: :center, valign: :center

      # AMOUNT
      @pdf.font("NotoSans", style: :bold) do
        @pdf.text_box format_money(item[:price].to_f), at: [ w_prod + w_desc + w_rate + w_qty, start_y ], width: w_amnt, height: available_h, align: :center, valign: :center
      end

      # DISCOUNT
      if !is_credit && item[:item_discount_amount].to_f > 0
        @pdf.fill_color @green_tag
        disc_val = "-#{format_money(item[:item_discount_amount])}"
        if item[:discount_percent].to_f > 0
          disc_val += " (#{item[:discount_percent].to_f.round(1).to_s.sub(/\.0$/, '')}%)"
        end
        @pdf.text_box disc_val, at: [ w_prod + w_desc + w_rate + w_qty + w_amnt, start_y ], width: w_disc, height: available_h, align: :center, valign: :center, style: :bold, overflow: :shrink_to_fit
        @pdf.fill_color @dark_charcoal
      else
        @pdf.fill_color @soft_gray
        @pdf.text_box "—", at: [ w_prod + w_desc + w_rate + w_qty + w_amnt, start_y ], width: w_disc, height: available_h, align: :center, valign: :center
      end

      # TAX
      @pdf.fill_color is_credit ? "DC2626" : @dark_charcoal
      if !is_credit && item[:computed_tax_amount].to_f > 0
        tax_val = "+#{format_money(item[:computed_tax_amount])}"
        if item[:tax_rate].to_f > 0
          tax_val += " (#{item[:tax_rate].to_f.round(1).to_s.sub(/\.0$/, '')}%)"
        end
        @pdf.text_box tax_val, at: [ w_prod + w_desc + w_rate + w_qty + w_amnt + w_disc, start_y ], width: w_tax, height: available_h, align: :center, valign: :center, overflow: :shrink_to_fit
      else
        @pdf.fill_color @soft_gray
        @pdf.text_box "—", at: [ w_prod + w_desc + w_rate + w_qty + w_amnt + w_disc, start_y ], width: w_tax, height: available_h, align: :center, valign: :center
      end
    end

    # 5. Advance cursor & Draw Dividers
    @pdf.move_down row_h
    end_y = @pdf.cursor

    # Use a sharper, refined color for dividers (industrial gray)
    @pdf.stroke_color "E5E7EB" # Gray-200 equivalent
    @pdf.line_width(0.5)

    # Vertical Lines (Pinned to exact coordinates)
    x_positions = [ 0, w_prod, w_prod + w_desc, w_prod + w_desc + w_rate, w_prod + w_desc + w_rate + w_qty, w_prod + w_desc + w_rate + w_qty + w_amnt, w_prod + w_desc + w_rate + w_qty + w_amnt + w_disc, total_width ]
    x_positions.each do |x|
      @pdf.stroke_vertical_line start_y, end_y, at: x
    end

    # Horizontal Line
    @pdf.stroke_horizontal_line 0, total_width, at: end_y
    @pdf.line_width(1.0)
  end

  def calculate_column_widths(table_width)
    calc_results = {}

    @pdf.font("NotoSans", size: 7.5, style: :bold) do
      w_prod = @pdf.width_of("TYPE") + 25
      w_rate = @pdf.width_of("PRICE") + 25
      w_qty  = @pdf.width_of("QTY") + 15
      w_amnt = @pdf.width_of("AMOUNT") + 25
      w_disc = @pdf.width_of("DISCOUNT") + 30
      w_tax  = @pdf.width_of("TAX") + 30

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

      w_prod = [ w_prod, 60 ].max
      fixed_total = w_prod + w_rate + w_qty + w_amnt + w_disc + w_tax
      w_desc = table_width - fixed_total

      if w_desc < 180
         # Proportional scaling to preserve a minimum 180pt Description column
         scale = (table_width - 180) / fixed_total
         w_prod *= scale; w_rate *= scale; w_qty *= scale; w_amnt *= scale; w_disc *= scale; w_tax *= scale
         w_desc = 180
      end

      calc_results = { prod: w_prod, desc: w_desc, rate: w_rate, qty: w_qty, amnt: w_amnt, disc: w_disc, tax: w_tax }
    end

    calc_results
  end

  def render_classic_summary
    # 1. Logic-Driven Row Construction (Matching Exact Requirements)
    # Order: Items Total(B) -> Item Discounts(G) -> div -> Subtotal(B) -> Inv Disc(G) -> div -> Taxable Total(B) -> Tax -> div -> Total Before Credit(B) -> Credit Applied(R) -> Big Div -> Balance Due
    rows = []

    # Tier 1: Item-level breakdown
    if @item_discount_total > 0
      rows << { label: "Items Total", value: format_money(@gross_subtotal), style: :bold }
      rows << { label: "Item Discounts", value: "-#{format_money(@item_discount_total)}", color: @green_tag, label_color: @green_tag }
      rows << { divider: true }
    end

    # Tier 2: The Core Subtotal
    rows << { label: "Subtotal", value: format_money(@net_subtotal + @global_discount_amount), style: :bold }

    # Tier 3: Invoice-level Discount
    if @global_discount_amount > 0
      disc_label = "Invoice Discount"
      if @log.try(:global_discount_percent).to_f > 0
        disc_label += " (-#{@log.global_discount_percent.to_f.round(1).to_s.sub(/\.0$/, '')}%)"
      end
      rows << { label: disc_label, value: "-#{format_money(@global_discount_amount)}", color: @green_tag, label_color: @green_tag }
      rows << { divider: true }
      rows << { label: "Taxable Total", value: format_money(@net_subtotal), style: :bold }
    end

    # Tier 4: Tax
    if @final_tax > 0
      rows << { label: "Tax", value: format_money(@final_tax) }
      rows << { divider: true }
    end

    # Tier 5: Post-Tax Adjustments (Credits)
    if @total_credits > 0
      # Ensure there's a divider if we didn't just add one
      rows << { divider: true } unless rows.last&.dig(:divider)
      rows << { label: "Total Before Credit", value: format_money(@total_before_credits), style: :bold }
      rows << { label: "Credit Applied", value: "-#{format_money(@total_credits)}", color: "DC2626", label_color: "DC2626" }
    end

    # Remove trailing divider if any (prevents double divider with the Big Divider)
    rows.pop while rows.last&.dig(:divider)

    # 2. Geometry & Spacing Logic
    row_h = 22
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
    # grand_total_h: big divider (8) + padding (15) + Balance Due value (approx 30)
    grand_total_h = 60
    h_content = (content_rows_count * row_h) + (divider_count * 10) + grand_total_h

    # 3. STICKY BOTTOM / PAGE OVERFLOW LOGIC
    # Prawn cursor '0' is at the bottom of the margin box.
    bottom_padding = 20 # 20pt above the bottom margin

    if @pdf.cursor < h_content
      @pdf.start_new_page
      render_continuation_header
    else
      # If we have enough space to move to the bottom, do it.
      # Box top should be at (height + footer_padding) to end at footer_padding.
      target_top = h_content + bottom_padding
      if @pdf.cursor > target_top
        @pdf.move_cursor_to(target_top)
      end
    end

    # 4. Render Bounding Box
    @pdf.bounding_box([ 0, @pdf.cursor ], width: table_width, height: h_content) do
      # -- A. PAYMENT INSTRUCTIONS (Left) --
      if @profile.payment_instructions.present?
        @pdf.bounding_box([ 0, h_content ], width: instructions_width) do
          @pdf.fill_color @dark_charcoal
          @pdf.font("NotoSans", style: :bold, size: 10) { @pdf.text "PAYMENT DETAILS", character_spacing: 1 }
          @pdf.move_down 5
          @pdf.stroke_color accent_color
          @pdf.line_width(2)
          @pdf.stroke_horizontal_line 0, 50
          @pdf.move_down 10
          @pdf.fill_color @mid_gray
          @pdf.font("NotoSans", size: 9) { @pdf.text @profile.payment_instructions, leading: 3 }
        end
      end

      # -- B. HIERARCHICAL TOTALS (Right) --
      left_x = table_width - summary_width
      current_y = h_content - 5

      rows.each do |row|
        if row[:divider]
          current_y -= 5
          @pdf.stroke_color "E5E7EB"
          @pdf.line_width(0.5)
          @pdf.stroke_horizontal_line left_x, table_width, at: current_y
          current_y -= 5
          next
        end

        # Label
        @pdf.fill_color row[:label_color] || @mid_gray
        @pdf.font("NotoSans", size: 9, style: row[:style] || :normal) do
          @pdf.text_box row[:label], at: [ left_x, current_y ], width: 140, height: row_h, align: :left, valign: :center
        end

        # Value
        @pdf.fill_color row[:color] || @dark_charcoal
        @pdf.font("NotoSans", style: :bold, size: 9) do
          @pdf.text_box row[:value], at: [ left_x + 100, current_y ], width: 140, height: row_h, align: :right, valign: :center
        end

        current_y -= row_h
      end

      # Grand Total Section (Industrial High-Impact Banner)
      # 1. Big Divider
      current_y -= 8
      @pdf.stroke_color @charcoal
      @pdf.line_width(1.5)
      @pdf.stroke_horizontal_line left_x, table_width, at: current_y

      # 2. Fill Accent Banner
      current_y -= 15
      banner_h = 45

      # Fill Accent Banner
      @pdf.fill_color accent_color
      @pdf.fill_rectangle [ left_x, current_y ], summary_width, banner_h

      # "BALANCE DUE" Label (Negative Space in Banner)
      @pdf.fill_color "FFFFFF"
      @pdf.font("NotoSans", style: :bold, size: 8) do
        @pdf.text_box "BALANCE DUE",
                      at: [ left_x + 10, current_y - 17 ],
                      width: 100,
                      height: 20,
                      align: :left,
                      valign: :top,
                      character_spacing: 1.5
      end

      # Value (High-Impact White)
      @pdf.font("NotoSans", style: :bold, size: 22) do
        @pdf.text_box format_money(@total_due),
                      at: [ left_x + 90, current_y - 8 ],
                      width: 140,
                      height: banner_h,
                      align: :right,
                      valign: :top,
                      overflow: :shrink_to_fit
      end
    end
  end

  def render_item_tag(text, bg_color, x_pos)
    tw = 0
    @pdf.font("NotoSans", size: 7, style: :bold) do
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
    d = "Work performed" if d.blank?
    d
  end

  def format_money(amount)
    amt = amount || 0
    sign = amt < 0 ? "-" : ""
    val = "%.2f" % amt.abs
    @currency_pos == "suf" ? "#{sign}#{val} #{@currency}" : "#{sign}#{@currency}#{val}"
  end



  private

  def setup_fonts
    if File.exist?(@font_path.join("NotoSans-Regular.ttf"))
      family = {
        normal: @font_path.join("NotoSans-Regular.ttf"),
        bold: @font_path.join("NotoSans-Bold.ttf")
      }

      # Optional styles
      family[:italic] = @font_path.join("NotoSans-Italic.ttf") if File.exist?(@font_path.join("NotoSans-Italic.ttf"))
      family[:bold_italic] = @font_path.join("NotoSans-BoldItalic.ttf") if File.exist?(@font_path.join("NotoSans-BoldItalic.ttf"))

      @pdf.font_families.update("NotoSans" => family)
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
    @pdf.move_down 5

    # 1. Industrial Accent Square
    @pdf.fill_color @orange_color
    @pdf.fill_rectangle [ 0, @pdf.cursor ], 4, 16

    # 2. Tech Typography (Clean & Minimal)
    @pdf.indent(12) do
      @pdf.fill_color @dark_charcoal
      @pdf.font("NotoSans", style: :bold, size: 9) do
        # Format: PAGE 02  ·  #INV-1075  ·  BUSINESS NAME
        info_text = "PAGE 0#{@pdf.page_number}  ·  #{@invoice_number}  ·  #{@profile.business_name.upcase}"
        @pdf.text info_text, character_spacing: 1.2
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

    tax_scope = @log.tax_scope.presence || "all"
    tax_tokens = tax_scope.to_s.split(",").map(&:strip)
    global_tax_rate = @profile.try(:tax_rate).to_f

    raw_sections.each do |section|
      title = section["title"].to_s.downcase
      category_key = case title
      when /labor|service/ then :labor
      when /material/ then :material
      when /expense/ then :expense
      when /fee/ then :fee
      else :other
      end

      if section["items"]
        section["items"].each do |item|
          raw_desc = item.is_a?(Hash) ? item["desc"] : item
          desc = sanitize_description(raw_desc)
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
              in_scope = tax_tokens.include?("all") || tax_tokens.include?("total") ||
                         ((tax_tokens.include?("materials") || tax_tokens.include?("parts") || tax_tokens.include?("materials_only")) && category_key == :material) ||
                         ((tax_tokens.include?("fees") || tax_tokens.include?("fees_only")) && category_key == :fee) ||
                         ((tax_tokens.include?("expenses") || tax_tokens.include?("expenses_only")) && category_key == :expense) ||
                         (tax_tokens.include?("labor") && category_key == :labor)

              if in_scope
                effective_rate = tax_rate || global_tax_rate
                computed_tax = ([ gross_price - item_discount_amount, 0.0 ].max * (effective_rate / 100.0)).round(2)
                @tax_amount += computed_tax
              end
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
      raw_credits.each { |c| @credits << { reason: c["reason"].presence || "Courtesy Credit", amount: c["amount"].to_f } if c["amount"].to_f > 0 }
    elsif (c_amt = @log.try(:credit_flat).to_f) > 0
      @credits << { reason: @log.try(:credit_reason).presence || "Courtesy Credit", amount: c_amt }
    end

    @total_credits = @credits.sum { |c| c[:amount] }
    @total_before_credits = @net_subtotal + @final_tax
    @total_due = @total_before_credits - @total_credits
    @invoice_date = @log.date.presence || Date.today.strftime("%b %d, %Y")
    @due_date = @log.due_date.presence || (Date.parse(@invoice_date) + 14.days rescue Date.today + 14).strftime("%b %d, %Y")
    next_id = Log.maximum(:id).to_i + 1
    @invoice_id_display = @log.id.present? ? (1000 + @log.id) : (1000 + next_id)
    @invoice_number = "INV-#{@invoice_id_display}"
  end

  def check_new_page_needed(needed_height)
    # Prawn's cursor 0 is at the bottom margin.
    # If the cursor is less than what we need, break.
    if @pdf.cursor < needed_height
       @pdf.start_new_page
       render_continuation_header
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
      @pdf.font("NotoSans", style: :bold) do
        @pdf.text_box "INVOICE", at: [ 50, page_top + 4 ], size: 30, height: 70, valign: :center, character_spacing: 2
      end

      @pdf.font("NotoSans", style: :bold) do
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
      @pdf.font("NotoSans", size: 7, style: :bold) do
        @pdf.text "CLIENT", character_spacing: 1
      end
      @pdf.move_down 8
      @pdf.fill_color "000000"
      @pdf.font("NotoSans", style: :bold, size: 11) do
        @pdf.text (@log.client.presence || "VALUED CLIENT").upcase, leading: 2
      end
      @pdf.move_down 5
      @pdf.fill_color @mid_gray
      @pdf.font("NotoSans", size: 9) do
        @pdf.text (@log.try(:address).presence || "").to_s, leading: 2
      end
    end

    # Right: Sender & Dates
    @pdf.bounding_box([ col_width + gap, y_start ], width: col_width) do
      @pdf.fill_color @navy
      @pdf.font("NotoSans", size: 7, style: :bold) do
        @pdf.text "SENDER", character_spacing: 1, align: :right
      end
      @pdf.move_down 8
      @pdf.fill_color "000000"
      @pdf.font("NotoSans", style: :bold, size: 10) do
        @pdf.text @profile.business_name, align: :right, leading: 2
      end
      @pdf.font("NotoSans", size: 8) do
        @pdf.fill_color @mid_gray
        @pdf.text @profile.address.to_s, align: :right, leading: 1
        @pdf.text "#{@profile.phone}  |  #{@profile.email}", align: :right, leading: 1
      end

      @pdf.move_down 15
      @pdf.stroke_color @soft_gray
      @pdf.stroke_horizontal_line col_width - 150, col_width, at: @pdf.cursor
      @pdf.move_down 10

      @pdf.fill_color "000000"
      @pdf.font("NotoSans", size: 8) do
        @pdf.text_box "DATE:", at: [ col_width - 150, @pdf.cursor ], width: 70, align: :left, style: :bold
        @pdf.text_box @invoice_date, at: [ col_width - 80, @pdf.cursor ], width: 80, align: :right
        @pdf.move_down 12
        @pdf.text_box "DUE DATE:", at: [ col_width - 150, @pdf.cursor ], width: 70, align: :left, style: :bold, color: @navy
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
    @pdf.font("NotoSans", style: :bold) do
      @pdf.fill_color @soft_gray
      @pdf.text "INVOICE", size: 42, character_spacing: 1
    end

    @pdf.move_cursor_to y_header + 5
    @pdf.font("NotoSans", style: :bold) do
      @pdf.fill_color @dark_charcoal
      @pdf.text @invoice_number, size: 10, align: :right, character_spacing: 1
      @pdf.move_down 2
      @pdf.fill_color @mid_gray
      @pdf.text "ISSUED: #{@invoice_date}", size: 7, align: :right, character_spacing: 0.5
    end

    @pdf.move_down 50

    # Layout
    y_start = @pdf.cursor
    col_width = (@pdf.bounds.width - 20) / 2

    @pdf.bounding_box([ 0, y_start ], width: col_width) do
      @pdf.fill_color "000000"
      @pdf.font("NotoSans", size: 7, style: :bold) do
        @pdf.text "BILL TO", character_spacing: 2
      end
      @pdf.move_down 10
      @pdf.font("NotoSans", style: :bold, size: 12) do
        @pdf.text (@log.client.presence || "CLIENT").upcase
      end
      @pdf.move_down 4
      @pdf.font("NotoSans", size: 9) do
        @pdf.fill_color @mid_gray
        @pdf.text (@log.try(:address).presence || "").to_s
      end
    end

    @pdf.bounding_box([ col_width + 20, y_start ], width: col_width) do
      @pdf.fill_color "000000"
      @pdf.font("NotoSans", size: 7, style: :bold) do
        @pdf.text "FROM", character_spacing: 2, align: :right
      end
      @pdf.move_down 10
      @pdf.font("NotoSans", style: :bold, size: 10) do
        @pdf.text @profile.business_name, align: :right
      end
      @pdf.font("NotoSans", size: 8) do
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
    @pdf.font("NotoSans", style: :bold, size: 7) do
      @pdf.text_box "DUE DATE", at: [ 15, @pdf.cursor - 10 ], width: 100
      @pdf.text_box "BALANCE DUE", at: [ @pdf.bounds.width - 110, @pdf.cursor - 10 ], width: 100, align: :right
    end
    @pdf.font("NotoSans", style: :bold, size: 11) do
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
    @pdf.font("NotoSans", style: :bold) do
      @pdf.text "INVOICE", size: 64, character_spacing: -2, leading: -10
    end

    @pdf.move_down 5
    @pdf.line_width(5)
    @pdf.stroke_horizontal_line 0, @pdf.bounds.width
    @pdf.move_down 30

    y_start = @pdf.cursor
    col_width = (@pdf.bounds.width - 40) / 2

    @pdf.bounding_box([ 0, y_start ], width: col_width) do
      @pdf.font("NotoSans", size: 10, style: :bold) do
        @pdf.text "BILLED TO", character_spacing: 1
      end
      @pdf.move_down 5
      @pdf.font("NotoSans", style: :bold, size: 16) do
        @pdf.text (@log.client.presence || "CLIENT").upcase, leading: 2
      end
    end

    @pdf.bounding_box([ col_width + 40, y_start ], width: col_width) do
      @pdf.font("NotoSans", size: 8, style: :bold) do
        @pdf.text "FROM: #{@profile.business_name.upcase}", align: :right, leading: 2
        @pdf.text "INV: #{@invoice_number}", align: :right, leading: 2
        @pdf.text "DATE: #{@invoice_date}", align: :right, leading: 2
        @pdf.text "DUE: #{@due_date}", align: :right, leading: 2, color: @orange_color
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
    @pdf.font("NotoSans", style: :bold) do
      @pdf.text "INVOICE", size: 16, character_spacing: 5
    end

    @pdf.move_down 5
    @pdf.stroke_color @soft_gray
    @pdf.line_width(0.5)
    @pdf.stroke_horizontal_line 0, @pdf.bounds.width
    @pdf.move_down 30

    y_start = @pdf.cursor
    col_width = (@pdf.bounds.width - 20) / 2

    @pdf.bounding_box([ 0, y_start ], width: col_width) do
      @pdf.font("NotoSans", size: 8, style: :bold) do
        @pdf.text "TO:", character_spacing: 1
      end
      @pdf.move_down 5
      @pdf.font("NotoSans", style: :bold, size: 10) do
        @pdf.fill_color "000000"
        @pdf.text (@log.client.presence || "CLIENT").upcase, leading: 2
      end
      @pdf.font("NotoSans", size: 8) do
        @pdf.fill_color @mid_gray
        @pdf.text (@log.try(:address).presence || "").to_s
      end
    end

    @pdf.bounding_box([ col_width + 20, y_start ], width: col_width) do
      @pdf.font("NotoSans", size: 8, style: :bold) do
        @pdf.text @profile.business_name, align: :right, leading: 2
      end
      @pdf.font("NotoSans", size: 7) do
        @pdf.fill_color @mid_gray
        @pdf.text "No. #{@invoice_number}", align: :right, leading: 1
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
        @pdf.font("NotoSans", size: 6.5, style: :bold) do
          @pdf.text_box @profile.business_name.upcase,
            at: [ margin, footer_y ], width: 200, align: :left, character_spacing: 0.5
        end

        @pdf.fill_color @dark_charcoal
        @pdf.font("NotoSans", style: :bold, size: 7) do
          page_text = "PAGE #{i + 1} OF #{@pdf.page_count}"
          @pdf.text_box page_text, at: [ page_w - margin - 100, footer_y ], width: 100, align: :right, character_spacing: 1
        end
      end
    end
  end
end
