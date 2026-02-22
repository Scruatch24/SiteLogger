require "prawn"
require "prawn/table"

class AnalyticsPdfGenerator
  DARK_BG       = "1a1a2e"
  CARD_BG       = "242442"
  HEADER_BG     = "2a2a4a"
  TEXT_WHITE     = "FFFFFF"
  TEXT_MUTED     = "9ca3af"
  ACCENT_ORANGE  = "f97316"
  COLOR_GREEN    = "4ade80"
  COLOR_YELLOW   = "fbbf24"
  COLOR_RED      = "f87171"
  COLOR_BLUE     = "60a5fa"
  TABLE_BORDER   = "3a3a5c"

  def initialize(data:, alerts:, invoice_rows:, client_insights:, currency_sym:, currency_code:, today:, profile:, locale:)
    @data = data
    @alerts = alerts
    @invoice_rows = invoice_rows
    @client_insights = client_insights
    @cs = currency_sym
    @currency_code = currency_code
    @today = today
    @profile = profile
    @locale = locale
  end

  def render
    I18n.with_locale(@locale) do
      pdf = Prawn::Document.new(
        page_size: "A4",
        page_layout: :landscape,
        margin: [30, 36, 40, 36],
        info: {
          Title: t("analytics_export.pdf_title"),
          Author: "TalkInvoice",
          Creator: "TalkInvoice Analytics",
          CreationDate: Time.current
        }
      )

      setup_fonts(pdf)

      # Background on every page (including auto-created by tables)
      pdf.on_page_create { draw_page_background(pdf) }
      draw_page_background(pdf)

      # Header
      draw_header(pdf)

      # Health Score Banner
      draw_health_banner(pdf)

      # Overview Cards
      draw_overview_cards(pdf)

      # Alerts
      draw_alerts(pdf) if @alerts.any?

      # Invoice Table
      draw_invoice_table(pdf)

      # Client Insights Table
      draw_client_table(pdf)

      # Footer on every page
      draw_footer(pdf)

      pdf.render
    end
  end

  private

  def t(key, **opts)
    I18n.t(key, **opts)
  end

  def fmt(val)
    "#{@cs}#{number_with_delimiter(val.to_f.round(2))}"
  end

  def number_with_delimiter(number)
    parts = number.to_s.split(".")
    parts[0] = parts[0].reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    parts.join(".")
  end

  def setup_fonts(pdf)
    noto_regular = Rails.root.join("app", "assets", "fonts", "NotoSans-Regular.ttf")
    noto_bold = Rails.root.join("app", "assets", "fonts", "NotoSans-Bold.ttf")
    geo_regular = Rails.root.join("app", "assets", "fonts", "NotoSansGeorgian-Regular.ttf")
    geo_bold = Rails.root.join("app", "assets", "fonts", "NotoSansGeorgian-Bold.ttf")

    if @locale.to_s.start_with?("ka") && File.exist?(geo_regular)
      pdf.font_families.update(
        "NotoSans" => {
          normal: geo_regular.to_s,
          bold: File.exist?(geo_bold) ? geo_bold.to_s : geo_regular.to_s
        }
      )
      pdf.font "NotoSans"
    elsif File.exist?(noto_regular)
      pdf.font_families.update(
        "NotoSans" => {
          normal: noto_regular.to_s,
          bold: File.exist?(noto_bold) ? noto_bold.to_s : noto_regular.to_s
        }
      )
      pdf.font "NotoSans"
    else
      pdf.font "Helvetica"
    end
  end

  def draw_page_background(pdf)
    pdf.canvas do
      pdf.fill_color DARK_BG
      pdf.fill_rectangle [0, pdf.bounds.absolute_top], pdf.bounds.absolute_right, pdf.bounds.absolute_top
    end
    pdf.fill_color TEXT_WHITE
  end

  def draw_header(pdf)
    earliest = @data[:cached_at] ? @today.strftime("%Y-%m-%d") : "—"
    title = t("analytics_export.pdf_title")
    subtitle = "#{t('analytics_export.pdf_report_date')}: #{@today.strftime('%Y-%m-%d')} | #{t('analytics_export.col_currency')}: #{@currency_code}"

    pdf.fill_color ACCENT_ORANGE
    pdf.text title, size: 20, style: :bold, align: :center
    pdf.move_down 4
    pdf.fill_color TEXT_MUTED
    pdf.text subtitle, size: 9, align: :center
    pdf.move_down 16
    pdf.fill_color TEXT_WHITE
  end

  def draw_health_banner(pdf)
    score = @data[:health_score]
    level = @data[:health_level]
    color = case level
            when "healthy" then COLOR_GREEN
            when "risk" then COLOR_YELLOW
            else COLOR_RED
            end

    banner_h = 50
    pdf.fill_color CARD_BG
    pdf.fill_rounded_rectangle [0, pdf.cursor], pdf.bounds.width, banner_h, 6
    pdf.fill_color TEXT_WHITE

    y = pdf.cursor
    # Score circle area
    pdf.bounding_box([16, y - 6], width: 60, height: 38) do
      pdf.fill_color color
      pdf.text "#{score}%", size: 18, style: :bold, valign: :center, align: :center
      pdf.fill_color TEXT_WHITE
    end

    # Health label
    pdf.bounding_box([86, y - 8], width: 250, height: 36) do
      pdf.fill_color color
      pdf.text t("analytics_page.health_#{level}"), size: 11, style: :bold
      pdf.fill_color TEXT_MUTED
      pdf.text t("analytics_page.health_#{level}_desc"), size: 7
      pdf.fill_color TEXT_WHITE
    end

    # Metrics on right
    col_rate = @data[:collection_rate]
    out_ratio = @data[:outstanding_ratio]
    pdf.bounding_box([pdf.bounds.width - 260, y - 8], width: 120, height: 36) do
      cr_color = col_rate >= 80 ? COLOR_GREEN : (col_rate >= 50 ? COLOR_YELLOW : COLOR_RED)
      pdf.fill_color cr_color
      pdf.text "#{col_rate}%", size: 14, style: :bold, align: :center
      pdf.fill_color TEXT_MUTED
      pdf.text t("analytics_page.collection_rate"), size: 7, align: :center
      pdf.fill_color TEXT_WHITE
    end

    pdf.bounding_box([pdf.bounds.width - 120, y - 8], width: 120, height: 36) do
      or_color = out_ratio <= 20 ? COLOR_GREEN : (out_ratio <= 50 ? COLOR_YELLOW : COLOR_RED)
      pdf.fill_color or_color
      pdf.text "#{out_ratio}%", size: 14, style: :bold, align: :center
      pdf.fill_color TEXT_MUTED
      pdf.text t("analytics_page.outstanding_ratio"), size: 7, align: :center
      pdf.fill_color TEXT_WHITE
    end

    pdf.move_down banner_h + 10
  end

  def draw_overview_cards(pdf)
    pdf.fill_color ACCENT_ORANGE
    pdf.text t("analytics_page.overview"), size: 12, style: :bold
    pdf.move_down 6
    pdf.fill_color TEXT_WHITE

    cards = [
      { label: t("analytics_page.total_invoiced"),       value: fmt(@data[:total_invoiced]),       color: TEXT_WHITE },
      { label: t("analytics_page.outstanding"),          value: fmt(@data[:total_outstanding]),    color: COLOR_YELLOW },
      { label: t("analytics_page.overdue_amount"),       value: fmt(@data[:total_overdue_amount]), color: COLOR_RED },
      { label: t("analytics_page.collected_this_month"), value: fmt(@data[:collected_this_month]), color: COLOR_GREEN },
      { label: t("analytics_page.projected_revenue"),    value: fmt(@data[:projected_revenue]),    color: ACCENT_ORANGE },
      { label: t("analytics_page.avg_invoice"),          value: fmt(@data[:avg_invoice]),          color: TEXT_WHITE }
    ]

    card_w = (pdf.bounds.width - 30) / 3.0
    card_h = 40
    cards.each_slice(3).with_index do |row, row_idx|
      row.each_with_index do |card, col_idx|
        x = col_idx * (card_w + 10)
        y = pdf.cursor
        pdf.fill_color CARD_BG
        pdf.fill_rounded_rectangle [x, y], card_w, card_h, 4
        pdf.bounding_box([x + 8, y - 6], width: card_w - 16, height: card_h - 12) do
          pdf.fill_color TEXT_MUTED
          pdf.text card[:label], size: 7
          pdf.fill_color card[:color]
          pdf.text card[:value], size: 13, style: :bold
        end
      end
      pdf.move_down card_h + 6
    end
    pdf.fill_color TEXT_WHITE
    pdf.move_down 4
  end

  def draw_alerts(pdf)
    pdf.fill_color ACCENT_ORANGE
    pdf.text t("analytics_page.action_required"), size: 12, style: :bold
    pdf.move_down 6
    pdf.fill_color TEXT_WHITE

    @alerts.first(4).each do |alert|
      bg = case alert[:type]
           when "danger" then "3b1a1a"
           when "warning" then "3b2f1a"
           when "info" then "1a2a3b"
           else CARD_BG
           end
      border_color = case alert[:type]
                     when "danger" then COLOR_RED
                     when "warning" then COLOR_YELLOW
                     when "info" then COLOR_BLUE
                     else TABLE_BORDER
                     end

      alert_h = 30
      pdf.fill_color bg
      pdf.fill_rounded_rectangle [0, pdf.cursor], pdf.bounds.width, alert_h, 4

      # Left accent bar
      pdf.fill_color border_color
      pdf.fill_rounded_rectangle [0, pdf.cursor], 3, alert_h, 2

      y = pdf.cursor
      pdf.bounding_box([12, y - 5], width: pdf.bounds.width - 24, height: alert_h - 10) do
        pdf.fill_color border_color
        pdf.text alert[:title], size: 9, style: :bold, inline_format: true
        pdf.fill_color TEXT_MUTED
        pdf.text alert[:desc], size: 7, inline_format: true
      end
      pdf.move_down alert_h + 4
    end
    pdf.fill_color TEXT_WHITE
    pdf.move_down 6
  end

  def draw_invoice_table(pdf)
    check_page_space(pdf, 80)

    pdf.fill_color ACCENT_ORANGE
    pdf.text t("analytics_export.section_invoices"), size: 12, style: :bold
    pdf.move_down 6
    pdf.fill_color TEXT_WHITE

    headers = [
      t("analytics_export.col_invoice_id"),
      t("analytics_export.col_client"),
      t("analytics_export.col_status"),
      t("analytics_export.col_amount"),
      t("analytics_export.col_due_date"),
      t("analytics_export.col_paid_date"),
      t("analytics_export.col_days_to_pay"),
      t("analytics_export.col_aging")
    ]

    rows = @invoice_rows.first(500).map do |inv|
      [
        inv[:id],
        inv[:client].to_s.truncate(24),
        inv[:status_label] || inv[:status],
        fmt(inv[:amount]),
        inv[:due_date],
        inv[:paid_date],
        inv[:days_to_pay].to_s,
        inv[:aging]
      ]
    end

    if rows.empty?
      pdf.fill_color TEXT_MUTED
      pdf.text t("analytics_page.no_invoices_yet"), size: 9
      pdf.fill_color TEXT_WHITE
      pdf.move_down 10
      return
    end

    table_data = [headers] + rows
    col_widths = compute_col_widths(pdf, 8)

    pdf.table(table_data, width: pdf.bounds.width, column_widths: col_widths, cell_style: {
      size: 7,
      padding: [4, 5, 4, 5],
      border_width: 0.5,
      border_color: TABLE_BORDER,
      text_color: TEXT_WHITE,
      background_color: DARK_BG
    }) do |tbl|
      tbl.row(0).font_style = :bold
      tbl.row(0).background_color = HEADER_BG
      tbl.row(0).text_color = ACCENT_ORANGE

      # Color-code status column (index 2) and aging column (index 7)
      rows.each_with_index do |row_data, idx|
        data_row = idx + 1
        status_raw = @invoice_rows[idx][:status].to_s.downcase rescue ""
        case status_raw
        when "overdue"
          tbl.row(data_row).column(2).text_color = COLOR_RED
          tbl.row(data_row).column(7).text_color = COLOR_RED
        when "paid"
          tbl.row(data_row).column(2).text_color = COLOR_GREEN
        when "sent"
          tbl.row(data_row).column(2).text_color = COLOR_BLUE
        when "draft"
          tbl.row(data_row).column(2).text_color = TEXT_MUTED
        end
      end

      # Alternate row backgrounds
      tbl.rows(1..-1).each_with_index do |row, i|
        row.background_color = i.even? ? DARK_BG : CARD_BG
      end
    end

    pdf.move_down 14
  end

  def draw_client_table(pdf)
    check_page_space(pdf, 60)

    pdf.fill_color ACCENT_ORANGE
    pdf.text t("analytics_export.section_clients"), size: 12, style: :bold
    pdf.move_down 6
    pdf.fill_color TEXT_WHITE

    if @client_insights.blank?
      pdf.fill_color TEXT_MUTED
      pdf.text t("analytics_page.no_clients_yet"), size: 9
      pdf.fill_color TEXT_WHITE
      pdf.move_down 10
      return
    end

    headers = [
      t("analytics_export.col_client"),
      t("analytics_export.col_total_invoiced"),
      t("analytics_export.col_outstanding"),
      t("analytics_export.col_repeat_client"),
      t("analytics_export.col_last_invoice_date"),
      t("analytics_export.col_top_client")
    ]

    rows = @client_insights.map do |c|
      repeat = c[:count] > 1 ? t("analytics_export.yes") : t("analytics_export.no")
      top = c[:badges].include?("top_client") ? t("analytics_export.yes") : t("analytics_export.no")
      [
        c[:name].to_s.truncate(28),
        fmt(c[:total]),
        fmt(c[:outstanding]),
        repeat,
        c[:last_at]&.strftime("%Y-%m-%d") || "—",
        top
      ]
    end

    table_data = [headers] + rows
    col_widths_6 = compute_col_widths(pdf, 6)

    pdf.table(table_data, width: pdf.bounds.width, column_widths: col_widths_6, cell_style: {
      size: 7,
      padding: [4, 5, 4, 5],
      border_width: 0.5,
      border_color: TABLE_BORDER,
      text_color: TEXT_WHITE,
      background_color: DARK_BG
    }) do |tbl|
      tbl.row(0).font_style = :bold
      tbl.row(0).background_color = HEADER_BG
      tbl.row(0).text_color = ACCENT_ORANGE

      # Highlight high outstanding
      rows.each_with_index do |row_data, idx|
        data_row = idx + 1
        outstanding_val = @client_insights[idx][:outstanding].to_f
        total_val = @client_insights[idx][:total].to_f
        if outstanding_val > 0 && total_val > 0 && (outstanding_val / total_val) > 0.5
          tbl.row(data_row).column(2).text_color = COLOR_YELLOW
        end
      end

      tbl.rows(1..-1).each_with_index do |row, i|
        row.background_color = i.even? ? DARK_BG : CARD_BG
      end
    end

    pdf.move_down 14
  end

  def draw_footer(pdf)
    pdf.repeat(:all) do
      pdf.canvas do
        pdf.fill_color TEXT_MUTED
        pdf.draw_text "TalkInvoice Analytics Report — #{t('analytics_export.pdf_exported')}: #{@today.strftime('%Y-%m-%d')}",
                      at: [36, 18], size: 7
        pdf.draw_text "talkinvoice.online",
                      at: [pdf.bounds.absolute_right - 130, 18], size: 7
        pdf.fill_color TEXT_WHITE
      end
    end
  end

  def check_page_space(pdf, needed)
    if pdf.cursor < needed
      pdf.start_new_page
      draw_page_background(pdf)
    end
  end

  def compute_col_widths(pdf, count)
    w = pdf.bounds.width
    case count
    when 8
      # Invoice table: ID, Client, Status, Amount, Due, Paid, Days, Aging
      [w * 0.09, w * 0.19, w * 0.09, w * 0.12, w * 0.12, w * 0.12, w * 0.10, w * 0.17]
    when 6
      # Client table: Name, Total, Outstanding, Repeat, Last, Top
      [w * 0.22, w * 0.18, w * 0.18, w * 0.14, w * 0.16, w * 0.12]
    else
      Array.new(count, w / count.to_f)
    end
  end
end
