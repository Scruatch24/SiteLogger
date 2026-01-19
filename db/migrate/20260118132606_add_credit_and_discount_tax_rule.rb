class AddCreditAndDiscountTaxRule < ActiveRecord::Migration[8.0]
  def change
    # Discount tax rule setting (POST-TAX is default)
    add_column :profiles, :discount_tax_rule, :string, default: "post_tax"

    # Credit fields on logs
    add_column :logs, :credit_flat, :decimal, precision: 10, scale: 2
    add_column :logs, :credit_reason, :string
  end
end
