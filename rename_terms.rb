require 'fileutils'

directories = [ "app/controllers", "app/views", "app/assets/javascripts", "app/helpers", "app/javascript", "db/migrate", "db" ]
extensions = [ ".rb", ".js", ".erb", ".html" ]

files = []
directories.each do |dir|
  extensions.each do |ext|
    files += Dir.glob("#{dir}/**/*#{ext}")
  end
end

replacements_made = 0

files.each do |f|
  next unless File.file?(f)
  text = File.read(f, encoding: 'UTF-8')
  next unless text.match?(/material|expense/i)

  new_text = text.gsub(/materials/i) do |m|
    if m == 'materials' then 'products'
    elsif m == 'Materials' then 'Products'
    else 'PRODUCTS'
    end
  end
  .gsub(/material/i) do |m|
    if m == 'material' then 'product'
    elsif m == 'Material' then 'Product'
    else 'PRODUCT'
    end
  end
  .gsub(/expenses/i) do |m|
    if m == 'expenses' then 'reimbursements'
    elsif m == 'Expenses' then 'Reimbursements'
    else 'REIMBURSEMENTS'
    end
  end
  .gsub(/expense/i) do |m|
    if m == 'expense' then 'reimbursement'
    elsif m == 'Expense' then 'Reimbursement'
    else 'REIMBURSEMENT'
    end
  end

  if text != new_text
    File.write(f, new_text)
    replacements_made += 1
    puts "Updated: #{f}"
  end
end

puts "Total files updated: #{replacements_made}"
