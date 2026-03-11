require 'fileutils'

# Precision-targeted directories for remaining terminology updates
directories = [
  "config/locales",
  "app/models",
  "app/services",
  "app/helpers",
  "test",
  "app/javascript"
]

extensions = [ ".rb", ".js", ".erb", ".html", ".yml" ]

files = []
directories.each do |dir|
  extensions.each do |ext|
    files += Dir.glob("#{dir}/**/*#{ext}")
  end
end

replacements_made = 0

files.each do |f|
  next unless File.file?(f)
  begin
    text = File.read(f, encoding: 'UTF-8')
  rescue => e
    puts "Skipping #{f} due to encoding error: #{e.message}"
    next
  end

  next unless text.match?(/material|expense/i)

  new_text = text.gsub(/materials/i) do |m|
    case m
    when 'materials' then 'products'
    when 'Materials' then 'Products'
    else 'PRODUCTS'
    end
  end
  .gsub(/material/i) do |m|
    case m
    when 'material' then 'product'
    when 'Material' then 'Product'
    else 'PRODUCT'
    end
  end
  .gsub(/expenses/i) do |m|
    case m
    when 'expenses' then 'reimbursements'
    when 'Expenses' then 'Reimbursements'
    else 'REIMBURSEMENTS'
    end
  end
  .gsub(/expense/i) do |m|
    case m
    when 'expense' then 'reimbursement'
    when 'Expense' then 'Reimbursement'
    else 'REIMBURSEMENT'
    end
  end

  if text != new_text
    File.write(f, new_text)
    replacements_made += 1
    puts "Precision Updated: #{f}"
  end
end

puts "Total precision updates made across #{replacements_made} files."
