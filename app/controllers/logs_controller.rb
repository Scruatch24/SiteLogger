class LogsController < ApplicationController
    require 'prawn'
    require 'prawn/table'
  
    def create
      @log = Log.new(log_params)
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
      
      # 1. PARSE DATA
      # We now expect items to potentially have 'price'
      raw_sections = JSON.parse(log.tasks || '[]') rescue []
      
      billable_items = []
      report_sections = []
  
      # 2. SEPARATE BILLABLE vs. REPORT ITEMS
      raw_sections.each do |section|
        report_items = []
        
        if section["items"]
          section["items"].each do |item|
            # Normalize item structure
            desc = item.is_a?(Hash) ? item["desc"] : item
            qty = item.is_a?(Hash) ? item["qty"] : nil
            price = item.is_a?(Hash) ? item["price"].to_f : 0.0
  
            if price > 0
              # Moves to Invoice
              billable_items << { desc: desc, qty: qty, price: price }
            else
              # Stays in Field Report
              report_items << item
            end
          end
        end
        
        # Only add section to report if it still has items left
        if report_items.any?
          report_sections << { "title" => section["title"], "items" => report_items }
        end
      end
  
      # 3. CALCULATE TOTALS
      labor_hours = log.time.to_f
      hourly_rate = profile.hourly_rate.to_f
      labor_cost = labor_hours * hourly_rate
      
      materials_cost = billable_items.sum { |i| i[:price] }
      subtotal = labor_cost + materials_cost
      
      tax_rate = profile.try(:tax_rate).to_f 
      tax_amount = subtotal * (tax_rate / 100.0)
      total_due = subtotal + tax_amount
  
      # Date Logic
      invoice_date = log.date.presence || Date.today.strftime("%B %d, %Y")
      invoice_number = "INV-#{1000 + log.id}"
  
      pdf = Prawn::Document.new
      
      # --- SECTION A: THE INVOICE ---
      
      # Header
      pdf.font "Helvetica"
      pdf.fill_color "111827"
      pdf.text profile.business_name.upcase, size: 18, style: :bold
      pdf.fill_color "6B7280"
      pdf.text "#{profile.phone} | #{profile.email}", size: 10
      pdf.text profile.address, size: 10
      
      pdf.move_down 20
      pdf.stroke_horizontal_rule
      pdf.move_down 20
  
      # Invoice Meta Data
      pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width) do
        pdf.float do
          pdf.fill_color "111827"
          pdf.text "BILLED TO:", size: 8, style: :bold, color: "6B7280"
          pdf.text log.client.presence || "Valued Client", size: 12, style: :bold
        end
        
        pdf.bounding_box([350, pdf.cursor], width: 200) do
          pdf.text "INVOICE", align: :right, size: 24, style: :bold, color: "E5E7EB"
          pdf.move_down 5
          pdf.text "Invoice #: #{invoice_number}", align: :right, size: 10
          pdf.text "Date: #{invoice_date}", align: :right, size: 10
        end
      end
  
      pdf.move_down 30
  
      # FINANCIAL TABLE
      table_data = [["DESCRIPTION", "QTY/HRS", "RATE", "AMOUNT"]]
      
      # Row 1: Labor
      table_data << ["Service / Labor", labor_hours, "$#{hourly_rate}", "$#{'%.2f' % labor_cost}"]
      
      # Rows 2+: Billable Materials
      billable_items.each do |item|
        qty_display = (item[:qty].present? && item[:qty] != '1') ? item[:qty] : "1"
        table_data << [item[:desc], qty_display, "-", "$#{'%.2f' % item[:price]}"]
      end
      
      # Empty padding row
      table_data << ["", "", "", ""]
      
      pdf.table(table_data, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        row(0).background_color = "F3F4F6"
        row(0).text_color = "111827"
        row(0).borders = [:bottom]
        row(0).border_width = 2
        row(0).border_color = "E5E7EB"
        columns(1..3).align = :right
        self.cell_style = { borders: [], padding: [8, 8] }
      end
  
      pdf.move_down 10
  
      # TOTALS BLOCK
      pdf.bounding_box([300, pdf.cursor], width: 240) do
        pdf.table([
          ["Subtotal:", "$#{'%.2f' % subtotal}"],
          ["Tax (#{tax_rate}%):", "$#{'%.2f' % tax_amount}"],
          [{content: "AMOUNT DUE", font_style: :bold, size: 14}, {content: "$#{'%.2f' % total_due}", font_style: :bold, size: 14, text_color: "F59E0B"}]
        ], width: 240) do
          self.cell_style = { borders: [], align: :right, padding: [4, 8] }
          row(-1).borders = [:top]
          row(-1).border_width = 1
          row(-1).border_color = "E5E7EB"
        end
      end
  
      # Payment Instructions
      if profile.payment_instructions.present?
        pdf.move_down 30
        pdf.text "PAYMENT INSTRUCTIONS", size: 8, style: :bold, color: "6B7280"
        pdf.text profile.payment_instructions, size: 10, color: "111827", leading: 4
      end
  
      # --- SECTION B: THE FIELD REPORT ---
      
      if report_sections.any?
        pdf.move_down 50
        pdf.stroke do
          pdf.stroke_color "E5E7EB"
          pdf.dash(5)
          pdf.horizontal_rule
        end
        pdf.undash
        pdf.move_down 20
  
        pdf.text "ATTACHED: FIELD INTELLIGENCE REPORT", size: 10, style: :bold, color: "6B7280"
        pdf.move_down 10
        
        report_sections.each do |section|
          pdf.fill_color "F59E0B"
          pdf.circle [5, pdf.cursor - 8], 3
          pdf.fill
          
          pdf.indent(15) do
            pdf.fill_color "111827"
            pdf.text section["title"].upcase, style: :bold, size: 10
          end
          pdf.move_down 5
          
          section["items"].each do |item|
            desc = item.is_a?(Hash) ? item["desc"] : item
            qty = item.is_a?(Hash) ? item["qty"] : nil
            
            text_string = desc
            text_string += " (Qty: #{qty})" if qty.present? && qty != "1" && qty != "N/A"
  
            pdf.indent(20) do
              pdf.fill_color "4B5563"
              pdf.text "• #{text_string}", size: 10, leading: 2
            end
          end
          pdf.move_down 15
        end
      end
  
      # Footer
      pdf.number_pages "Page <page> of <total>", at: [pdf.bounds.right - 150, 0], width: 150, align: :right, size: 8, color: "9CA3AF"
  
      send_data pdf.render, filename: "#{invoice_number}_#{log.client}.pdf", type: "application/pdf", disposition: "inline"
    end
  
    private
  
    def log_params
      params.require(:log).permit(:client, :time, :date, :tasks, :materials)
    end
  end