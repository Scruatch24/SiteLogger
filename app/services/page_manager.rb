# PageManager - Deterministic pagination for Prawn PDF documents
# Tracks vertical space and handles page breaks with running subtotals
class PageManager
  # Layout Constants (in points)
  HEADER_HEIGHT = 140           # Orange header bar height
  FOOTER_HEIGHT = 50            # Space reserved for footer
  PAGE_MARGIN = 40              # Document margins
  SINGLE_LINE_ROW_HEIGHT = 28   # Single-line item row
  DOUBLE_LINE_ROW_HEIGHT = 40   # Double-line item row (wrapped text)
  SECTION_HEADER_HEIGHT = 24    # Section header (FEES, EXPENSES, etc.)
  TABLE_HEADER_HEIGHT = 36      # Table column headers row
  TOTALS_BASE_HEIGHT = 120      # Base height for totals block
  TOTALS_LINE_HEIGHT = 30       # Each line in totals (SUBTOTAL, TAX, etc.)
  PAYMENT_INSTRUCTIONS_HEIGHT = 80
  FIELD_REPORT_HEADER_HEIGHT = 35
  FIELD_REPORT_SECTION_HEIGHT = 30
  FIELD_REPORT_ITEM_HEIGHT = 18

  # Column widths for item table (A4 page width - margins = ~515pt)
  COLUMN_WIDTHS = {
    description: 300,
    qty: 60,
    rate: 75,
    amount: 80
  }.freeze

  attr_reader :is_multi_page, :running_subtotal, :pdf

  def initialize(pdf, options = {})
    @pdf = pdf
    @header_renderer = options[:header_renderer]     # Proc to re-render page header
    @subtotal_renderer = options[:subtotal_renderer] # Proc to render subtotal carry-forward
    @currency_formatter = options[:currency_formatter] # Proc to format currency
    @running_subtotal = 0.0
    @is_multi_page = false
    @orange_color = options[:orange_color] || "F97316"
  end

  # Returns available vertical space before hitting footer area
  def remaining_height
    @pdf.cursor - FOOTER_HEIGHT
  end

  # Check if there's enough space, start new page if not
  # Returns true if a new page was started
  def ensure_space(required_height)
    if remaining_height < required_height
      start_new_page_with_subtotal
      true
    else
      false
    end
  end

  # Check if section header + first item can fit together
  def ensure_section_fits(header_height, first_item_height)
    ensure_space(header_height + first_item_height)
  end

  # Add amount to running subtotal (for carry-forward)
  def add_to_subtotal(amount)
    @running_subtotal += amount.to_f
  end

  # Reset subtotal (e.g., after rendering totals block)
  def reset_subtotal
    @running_subtotal = 0.0
  end

  # Calculate row height based on description length
  def compute_row_height(description, chars_per_line: 50)
    return SINGLE_LINE_ROW_HEIGHT if description.to_s.empty?

    lines = (description.to_s.length / chars_per_line.to_f).ceil
    lines = [ lines, 1 ].max
    lines > 1 ? DOUBLE_LINE_ROW_HEIGHT : SINGLE_LINE_ROW_HEIGHT
  end

  # Calculate totals block height dynamically
  def calculate_totals_height(has_discount: false, has_credit: false)
    lines = 3  # SUBTOTAL, TAX, TOTAL
    lines += 1 if has_discount
    lines += 1 if has_credit
    TOTALS_BASE_HEIGHT + (lines - 3) * TOTALS_LINE_HEIGHT
  end

  private

  def start_new_page_with_subtotal
    # Render "Subtotal carried forward" footer before page break
    if @is_multi_page || @running_subtotal > 0
      render_carry_forward_footer
    end

    @pdf.start_new_page
    @is_multi_page = true

    # Render header on new page
    @header_renderer&.call

    # Render "Subtotal brought forward" on new page
    if @running_subtotal > 0
      render_brought_forward_header
    end
  end

  def render_carry_forward_footer
    return unless @running_subtotal > 0

    @pdf.move_down 10
    @pdf.fill_color "666666"
    formatted_amount = @currency_formatter ? @currency_formatter.call(@running_subtotal) : "$#{'%.2f' % @running_subtotal}"
    @pdf.text "Subtotal carried forward → #{formatted_amount}",
              size: 9,
              align: :right
    @pdf.fill_color "000000"
  end

  def render_brought_forward_header
    return unless @running_subtotal > 0

    @pdf.fill_color "666666"
    formatted_amount = @currency_formatter ? @currency_formatter.call(@running_subtotal) : "$#{'%.2f' % @running_subtotal}"
    @pdf.text "Subtotal brought forward → #{formatted_amount}",
              size: 9,
              align: :right
    @pdf.move_down 15
    @pdf.fill_color "000000"
  end
end
