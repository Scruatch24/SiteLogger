class AddDiscountTaxRuleToLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :logs, :discount_tax_rule, :string
  end
end
