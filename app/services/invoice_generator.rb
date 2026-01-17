class InvoiceGenerator
  require "prawn"
  require "prawn/table"

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
    @currency = @symbols[@profile.currency] || @profile.currency || "$"
    @orange_color = "F97316"

    setup_fonts
    prepare_data
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

    add_footer unless style == "bold" # Bold might handle its own footer
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

  def prepare_data
    # Re-use logic for parsing sections, items, taxes
    raw_sections = JSON.parse(@log.tasks || "[]") rescue []
    @billable_items = []
    @report_sections = []

    tax_scope = @log.tax_scope.presence || "all"

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
          taxable = item.is_a?(Hash) && item["taxable"] == true
          tax_rate = (item.is_a?(Hash) && item["tax_rate"].present?) ? item["tax_rate"].to_f : nil

          if price > 0
            @billable_items << { desc: desc, qty: qty, price: price, taxable: taxable, tax_rate: tax_rate, type: item_type }
          else
            report_items << item
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
      @rate_label = "#{@currency}#{'%.2f' % @labor_cost}"
      @table_qty_header = "QTY"
    else
      labor_hours = @log.time.to_f
      hourly_rate = @profile.hourly_rate.to_f
      @labor_cost = labor_hours * hourly_rate
      @labor_label = "Professional Services / Labor"
      @qty_label = ("%g" % labor_hours)
      @rate_label = "#{@currency}#{'%.2f' % hourly_rate}"
      @table_qty_header = "HRS"
    end

    materials_cost = @billable_items.sum { |i| i[:price] }
    @subtotal = @labor_cost + materials_cost

    # Tax Calc
    tax_tokens = tax_scope.to_s.split(",").map(&:strip)
    global_tax_rate = @profile.try(:tax_rate).to_f
    @tax_amount = 0.0

    is_labor_taxed = @log.labor_taxable
    if @log.labor_taxable.nil?
      is_labor_taxed = tax_tokens.include?("labor") || tax_tokens.include?("all") || tax_tokens.include?("total")
    end
    @tax_amount += @labor_cost * (global_tax_rate / 100.0) if is_labor_taxed

    @billable_items.each do |item|
      if item[:taxable]
        in_scope = tax_tokens.include?("all") || tax_tokens.include?("total") ||
                   (tax_tokens.include?("tasks_only") && item[:type] == :task) ||
                   (tax_tokens.include?("materials_only") && item[:type] == :material)
        if in_scope
          rate = item[:tax_rate] || global_tax_rate
          @tax_amount += item[:price] * (rate / 100.0)
        end
      end
    end

    @total_due = @subtotal + @tax_amount
    @invoice_date = @log.date.presence || Date.today.strftime("%b %d, %Y")
    @due_date = @log.due_date.presence || (Date.parse(@invoice_date) + 14.days rescue Date.today + 14).strftime("%b %d, %Y")
    @invoice_number = "INV-#{1000 + @log.id}"
  end

  def render_professional
    # Implementation of Style 1 (The current Premium Recraft)
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
    render_table(header_bg: "F9F9F9", header_text: "333333", border: true)
    render_totals(highlight: true)
    render_payment_instructions
    render_field_report
  end

  def render_modern
    # Style 2: Modern (Sidebar)
    # Background Sidebar
    @pdf.canvas do
      @pdf.fill_color "F8F9FA"
      @pdf.fill_rectangle [ 0, @pdf.bounds.top ], 200, @pdf.bounds.height
    end

    @pdf.fill_color "000000"
    @pdf.font("NotoSans", style: :bold) do
      @pdf.text_box "INVOICE", at: [ 40, @pdf.bounds.top - 50 ], size: 24, character_spacing: 2
    end

    @pdf.bounding_box([ 0, @pdf.bounds.top - 100 ], width: 160) do
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

    @pdf.bounding_box([ 220, @pdf.bounds.top ], width: 300) do
      @pdf.move_down 50
      render_table(simple: true)
      @pdf.move_down 20
      render_totals(simple: true)
      render_payment_instructions
      render_field_report(simple: true)
    end
  end

  def render_classic
    # Style 3: Classic (Serif, Centered)
    # Use Helvetica as fallback for classic feel if Times not available, but NotoSans is fine.

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
    render_table(grid: true)
    render_totals(line_item: true)
    render_payment_instructions
    render_field_report(grid: true)
  end

  def render_bold
    # Style 4: Bold (High Contrast Header)
    @pdf.canvas do
      @pdf.fill_color "111827" # Dark blue/black
      @pdf.fill_rectangle [ 0, @pdf.bounds.top ], @pdf.bounds.width, 200
    end

    @pdf.fill_color "FFFFFF"
    @pdf.move_down 20
    @pdf.text "INVOICE", align: :right, size: 40, style: :bold, character_spacing: 2

    @pdf.move_down 20
    @pdf.text @profile.business_name, size: 20, style: :bold
    @pdf.text @profile.address, size: 10

    @pdf.move_down 60 # Exit the dark zone visually
    @pdf.fill_color "000000"

    y_pos = @pdf.cursor
    @pdf.text_box "BILL TO", at: [ 0, y_pos ], size: 8, style: :bold, color: "9CA3AF"
    @pdf.text_box @log.client, at: [ 0, y_pos - 15 ], size: 14, style: :bold

    @pdf.text_box "DETAILS", at: [ 300, y_pos ], size: 8, style: :bold, color: "9CA3AF"
    @pdf.text_box "##{@invoice_number} | #{@invoice_date}", at: [ 300, y_pos - 15 ], size: 10

    @pdf.move_down 50
    render_table(header_bg: "111827", header_text: "FFFFFF")
    render_totals
    render_payment_instructions
    render_field_report

    # Custom bold footer
    @pdf.page_count.times do |i|
      @pdf.go_to_page(i + 1)
      @pdf.canvas do
        @pdf.fill_color "111827"
        @pdf.fill_rectangle [ 0, 50 ], @pdf.bounds.width, 50
        @pdf.fill_color "FFFFFF"
        @pdf.text_box "Generated by TALKINVOICE", at: [ 0, 30 ], width: @pdf.bounds.width, align: :center, size: 8
      end
    end
  end

  def render_minimal
    # Style 5: Minimal (Whitespace, Typography)
    @pdf.font_size 10

    @pdf.text @profile.business_name.upcase, style: :bold, size: 12
    @pdf.text "INVOICE #{@invoice_number}", align: :right, style: :bold, size: 12

    @pdf.move_down 40

    @pdf.text @log.client, size: 18, style: :bold
    @pdf.text "Due: #{@due_date}", size: 10, color: "666666"

    @pdf.move_down 40
    render_table(minimal: true)
    render_totals(minimal: true)
    render_payment_instructions
    render_field_report(minimal: true)
  end

  # --- Shared Components ---

  def render_table(options = {})
    table_data = [ [ "DESCRIPTION", @table_qty_header, "RATE", "AMOUNT" ] ]
    table_data << [ @labor_label, @qty_label, @rate_label, "#{@currency}#{'%.2f' % @labor_cost}" ]
    @billable_items.each do |item|
      m_qty = item[:qty].to_f
      m_qty_label = (m_qty > 0) ? ("%g" % m_qty) : "1"
      table_data << [ item[:desc], m_qty_label, "-", "#{@currency}#{'%.2f' % item[:price]}" ]
    end

    @pdf.table(table_data, width: options[:simple] ? 300 : @pdf.bounds.width) do
      # Defaults
      cells.borders = opt_borders = options[:grid] ? [ :top, :bottom, :left, :right ] : [ :bottom ]
      cells.border_width = 0.5
      cells.border_color = "EEEEEE"
      cells.padding = [ 10, 10 ]

      # Header
      row(0).font_style = :bold
      if options[:header_bg]
        row(0).background_color = options[:header_bg]
        row(0).text_color = options[:header_text] || "FFFFFF"
        row(0).borders = []
      elsif options[:minimal]
        row(0).borders = [ :bottom ]
        row(0).border_width = 2
        row(0).border_color = "000000"
        row(0).text_color = "000000"
      else
        row(0).text_color = "333333"
      end

      columns(1..3).align = :right
    end
  end

  def render_totals(options = {})
    @pdf.move_down 20
    width = options[:simple] ? 300 : 250
    x_pos = options[:simple] ? 0 : @pdf.bounds.width - width

    @pdf.bounding_box([ x_pos, @pdf.cursor ], width: width) do
      totals = [
        [ "SUBTOTAL", "#{@currency}#{'%.2f' % @subtotal}" ],
        [ "TAX", "#{@currency}#{'%.2f' % @tax_amount}" ],
        [ "TOTAL", "#{@currency}#{'%.2f' % @total_due}" ]
      ]

      @pdf.table(totals, width: width) do
        cells.borders = []
        cells.align = :right
        cells.padding = [ 5, 10 ]

        column(0).font_style = :bold
        row(2).size = 14

        if options[:highlight]
          row(2).background_color = @orange_color
          row(2).text_color = "FFFFFF"
        elsif options[:line_item]
          row(2).borders = [ :top ]
          row(2).border_color = "000000"
        end
      end
    end
  end

  def render_payment_instructions
    if @profile.payment_instructions.present?
      @pdf.move_down 40
      @pdf.text "PAYMENT INSTRUCTIONS", size: 9, style: :bold
      @pdf.fill_color "444444"
      @pdf.text @profile.payment_instructions, size: 9, leading: 4
      @pdf.fill_color "000000"
    end
  end

  def render_field_report(options = {})
    return unless @report_sections.any?

    if @pdf.cursor < 150
      @pdf.start_new_page
    else
      @pdf.move_down 30
    end

    # Header
    if options[:minimal]
      @pdf.text "FIELD REPORT", style: :bold, size: 12
      @pdf.stroke_horizontal_rule
      @pdf.move_down 20
    elsif options[:grid]
      @pdf.text "FIELD REPORT", align: :center, style: :bold
      @pdf.move_down 10
    else
      @pdf.fill_color "F3F4F6"
      @pdf.fill_rectangle [ 0, @pdf.cursor ], @pdf.bounds.width, 30
      @pdf.fill_color @orange_color
      @pdf.text_box "FIELD INTELLIGENCE REPORT", at: [ 10, @pdf.cursor - 8 ], size: 11, style: :bold
      @pdf.move_down 45
    end

    # Items
    @report_sections.each do |section|
      @pdf.fill_color "000000"
      @pdf.text section["title"].upcase, size: 9, style: :bold
      @pdf.stroke_color @orange_color
      @pdf.stroke_horizontal_line 0, 40 unless options[:minimal] || options[:grid]
      @pdf.move_down 5

      section["items"].each do |item|
        desc = item.is_a?(Hash) ? item["desc"] : item
        qty  = item.is_a?(Hash) ? item["qty"].to_f : 0
        text = qty > 0 && qty != 1 ? "#{desc} (x#{'%g' % qty})" : desc
        @pdf.fill_color "444444"
        @pdf.indent(5) { @pdf.text "• #{text}", size: 9 }
      end
      @pdf.move_down 15
    end
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
