module LogsHelper
  def calculate_log_totals(log, profile)
    # Cache based on log and profile updates
    profile_key = profile.persisted? ? "p-#{profile.id}-#{profile.updated_at.to_i}" : "p-guest"
    cache_key = "log_totals/#{log.id}-#{log.updated_at.to_i}/#{profile_key}"

    Rails.cache.fetch(cache_key) do
      categorized_items = {
        labor: [],
        material: [],
        fee: [],
        expense: [],
        other: []
      }

      report_sections = [] # For items with price <= 0

      # Track totals
      item_discount_total = 0.0
      tax_amount = 0.0

      # Parse logging data (Safe check for serialized vs raw string)
      raw_sections = if log.tasks.is_a?(String)
                       JSON.parse(log.tasks || "[]") rescue []
      else
                       log.tasks || []
      end

    # Tax configuration
    tax_scope = log.tax_scope.presence || "all"
    tax_tokens = tax_scope.to_s.split(",").map(&:strip)
    global_tax_rate = profile.try(:tax_rate).to_f
    global_hourly_rate = log.try(:hourly_rate).present? ? log.try(:hourly_rate).to_f : profile.hourly_rate.to_f

    raw_sections.each_with_index do |section, s_idx|
      title = section["title"].to_s.downcase
      report_items = []

      # Determine item type/category based on section title
      category_key = case title
      when /labor|service|სამუშაო|მომსახურება/i then :labor
      when /material|მასალ/i then :material
      when /expense|ხარჯ/i then :expense
      when /fee|მოსაკრებ|საკომისიო|შესაკრებ/i then :fee
      else :other
      end

      if section["items"]
        section["items"].each_with_index do |item, i_idx|
          # Input normalization
          raw_desc = item.is_a?(Hash) ? item["desc"] : item
          desc = sanitize_description(raw_desc)

          # Initialize variables
          qty = 1.0
          price = 0.0
          gross_price = 0.0

          if item.is_a?(Hash)
            # Fetch base values
            raw_qty = item["qty"].to_f
            raw_price = item["price"].to_f

            # MODE DETECTION
            mode = item["mode"].presence || log.billing_mode || "hourly"

            if category_key == :labor
              # LABOR LOGIC
              if mode == "hourly"
                 # In hourly mode, "price" field from JSON actually holds HOURS
                 hours = raw_price > 0 ? raw_price : raw_qty
                 hourly_rate = item["rate"].present? ? item["rate"].to_f : global_hourly_rate

                 qty = hours
                 price = hours * hourly_rate
                 gross_price = price
              else
                 # Fixed mode: "price" is the flat amount
                 qty = 1
                 price = raw_price
                 gross_price = raw_price
              end

              # FALLBACK FOR LABOR NAME
              if desc.blank? || desc == "Work performed"
                desc = I18n.t("professional_services", default: "Professional Services")
              end
            else
              # NON-LABOR LOGIC (Materials, Fees, Expenses)
              qty = raw_qty > 0 ? raw_qty : 1.0

              # SMART QTY EXTRACTION
              if qty == 1.0 && desc.present?
                if match = desc.match(/[\(\s]x?(\d+)[\)]?$/i) || desc.match(/^(\d+)\s*x\s+/i)
                  extracted_q = match[1].to_f
                  qty = extracted_q if extracted_q > 1
                end
              end

              price = raw_price
              gross_price = price * qty

              # FALLBACK FOR NON-LABOR NAME
              if desc.blank? || desc == "Work performed"
                desc = case category_key
                when :material then I18n.t("item_material", default: "Material")
                when :fee      then I18n.t("item_fee", default: "Fee")
                when :expense  then I18n.t("item_expense", default: "Expense")
                else I18n.t("item", default: "Item")
                end
              end
            end

            taxable = item["taxable"] == true
            tax_rate = item["tax_rate"].present? ? item["tax_rate"].to_f : nil
            sub_categories = item["sub_categories"].is_a?(Array) ? item["sub_categories"] : []

            # Item Discounts
            discount_flat = item["discount_flat"].to_f
            discount_percent = item["discount_percent"].to_f
            discount_message = item["discount_message"].to_s
          else
             # String-only item (description only)
             desc = sanitize_description(item)
             sub_categories = []
             taxable = false
             tax_rate = nil
             discount_flat = 0.0
             discount_percent = 0.0
             discount_message = ""
          end

          if gross_price <= 0
            # If it's just a descriptive item with no price, goes to report
            report_items << item
          else
            # Calculate Item Discount
            # Discount is applied to the GROSS PRICE (Total Line Item)
            item_discount_amount = (discount_flat + (gross_price * discount_percent / 100.0)).round(2)
            item_discount_amount = gross_price if item_discount_amount > gross_price # Cap at price
            item_discount_total += item_discount_amount

            # Calculate Tax (Net of item discount)
            computed_tax = 0.0
            if taxable
               effective_rate = tax_rate || global_tax_rate
               taxable_base = [ gross_price - item_discount_amount, 0.0 ].max
                computed_tax = (taxable_base * (effective_rate / 100.0)).round(2)
               tax_amount += computed_tax
            end

            # Construct Item Object
            item_data = {
              desc: desc,
              qty: qty,
              price: gross_price, # TOTAL line price (Qty * Unit Price)
              taxable: taxable,
              tax_rate: (tax_rate || global_tax_rate),
              item_discount_amount: item_discount_amount,
              discount_percent: discount_percent,
              discount_message: discount_message,
              computed_tax_amount: computed_tax,
              sub_categories: sub_categories,
              category: category_key,
              section_index: s_idx,
              item_index: i_idx,
              log_id: log.id
            }

            # Add to Category
            categorized_items[category_key] << item_data
          end
        end
      end
      # Add leftover descriptive items to report sections
      report_sections << { "title" => section["title"], "items" => report_items } if report_items.any?
    end

    # Labor Fallback logic:
    if categorized_items[:labor].empty?
      log_billing_mode = log.billing_mode || "hourly"

      if log_billing_mode == "fixed"
        labor_cost = log.time.to_f
        if labor_cost > 0
          # Check valid fallback
          labor_item = {
            desc: I18n.t("professional_services", default: "Professional Services"),
            qty: 1,
            price: labor_cost,
            taxable: log.try(:labor_taxable),
            tax_rate: global_tax_rate,
            item_discount_amount: 0.0,
            computed_tax_amount: 0.0,
            sub_categories: [],
            category: :labor
          }
           # Recalculate tax for this synthetic item if needed
           if labor_item[:taxable] || tax_tokens.include?("all") || tax_tokens.include?("labor")
             labor_item[:computed_tax_amount] = labor_cost * (global_tax_rate / 100.0)
             tax_amount += labor_item[:computed_tax_amount]
           end

           categorized_items[:labor] << labor_item
        end
      else
        labor_hours = log.time.to_f
        hourly_rate = log.try(:hourly_rate).present? ? log.try(:hourly_rate).to_f : profile.hourly_rate.to_f
        labor_cost = labor_hours * hourly_rate

        if labor_cost > 0
          labor_item = {
            desc: I18n.t("professional_services", default: "Professional Services"),
            qty: labor_hours,
            price: labor_cost,
            taxable: log.try(:labor_taxable),
            tax_rate: global_tax_rate,
            item_discount_amount: 0.0,
            computed_tax_amount: 0.0,
            sub_categories: [],
            category: :labor
          }
           # Recalculate tax for this synthetic item
           if labor_item[:taxable] || tax_tokens.include?("all") || tax_tokens.include?("labor")
             labor_item[:computed_tax_amount] = labor_cost * (global_tax_rate / 100.0)
             tax_amount += labor_item[:computed_tax_amount]
           end
           categorized_items[:labor] << labor_item
        end
      end
    end

    # Calculate Subtotal (Sum of all items in all categories)
    all_items = categorized_items.values.flatten
    subtotal = all_items.sum { |i| i[:price] }

    # Global Discount Calculation
    g_flat = log.try(:global_discount_flat).to_f
    g_percent = log.try(:global_discount_percent).to_f

    # Global discount logic: applied on Net Subtotal (Gross - Item Discounts)
    discountable_base = [ subtotal - item_discount_total, 0 ].max
    raw_global_discount = g_flat + (discountable_base * (g_percent / 100.0))
    global_discount_amount = raw_global_discount

    # Cap global discount
    global_discount_amount = discountable_base if global_discount_amount > discountable_base

    # Credit Handling
    credits = []
    raw_credits = if log.respond_to?(:credits) && log.credits.present?
                    log.credits.is_a?(String) ? (JSON.parse(log.credits) rescue []) : log.credits
    else
                    []
    end

    if raw_credits.is_a?(Array) && raw_credits.present?
      raw_credits.each_with_index do |c, c_idx|
        amount = c["amount"].to_f
        next if amount <= 0
        credits << { reason: c["reason"].presence || I18n.t("courtesy_credit", default: "Courtesy Credit"), amount: amount, credit_index: c_idx, log_id: log.id }
      end
    else
       # Fallback to single fields
       c_amt = log.try(:credit_flat).to_f
       if c_amt > 0
         credits << { reason: log.try(:credit_reason).presence || I18n.t("courtesy_credit", default: "Courtesy Credit"), amount: c_amt }
       end
    end
    total_credits = credits.sum { |c| c[:amount] }

    # Total Calculation
    item_discounts = item_discount_total
    total_discount = item_discount_total + global_discount_amount

    # Calculate Tax adjustment for Global Discount if Pre-Tax
    rule = log.respond_to?(:discount_tax_rule) ? (log.discount_tax_rule.presence || "post_tax") : (profile.try(:discount_tax_rule).presence || "post_tax")
    final_tax = tax_amount
    if rule == "pre_tax"
       taxable_sum = subtotal - item_discounts
       if taxable_sum > 0
          net_subtotal = [ subtotal - total_discount, 0 ].max
          final_tax = (tax_amount * (net_subtotal.to_f / taxable_sum)).round(2)
       end
    end

    # Intermediate total: Subtotal - Discount + Tax
    total_before_credits = [ subtotal - total_discount, 0 ].max + final_tax
    balance_due = total_before_credits - total_credits

    # Results 9-step alignment
    net_items_subtotal = [ subtotal - item_discount_total, 0 ].max
    taxable_total = [ net_items_subtotal - global_discount_amount, 0 ].max
    total_before_credits = taxable_total + final_tax
    balance_due = total_before_credits - total_credits

    {
      categorized_items: categorized_items,
      report_sections: report_sections,
      items_total: subtotal,
      item_discount_total: item_discount_total,
      net_items_subtotal: net_items_subtotal,
      global_discount_amount: global_discount_amount,
      global_discount_percent: g_percent,
      taxable_total: taxable_total,
      tax_amount: final_tax,
      credits: credits,
      total_credits: total_credits,
      total_before_credits: total_before_credits,
      total_due: balance_due,
      currency: log.try(:currency).presence || profile.currency.presence || "USD"
    }
    end
  end

  def sanitize_description(desc)
    d = desc.to_s.strip
    d = d.gsub(/Labor:?/i, "")
         .gsub(/Hourly service:?/i, "")
         .gsub(/^Service\s*-\s*/i, "")
         .gsub(/^Fee:?/i, "")
         .strip

    if d =~ /^I (?:re)?installed/i
      d = d.sub(/^I (?:re)?installed/i, "Installation of")
    elsif d =~ /replaced/i
      d = d.sub(/replaced/i, "Replacement of")
    elsif d =~ /fix(ed|ing)/i
      d = d.sub(/fix(ed|ing)/i, "Repair of")
    end

    if d.blank?
      d = I18n.t("professional_services", default: "Work performed")
    end
    d
  end
end
