class AddInvoiceStyleToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :invoice_style, :string
  end
end
