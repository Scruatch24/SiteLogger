path = 'app/views/home/index.html.erb'
content = File.read(path)

# Regex to find the first style block which corresponds to the massive inline CSS
# We look for <style> at start of file and matching </style>
# Using specific markers from the file content we viewed to be safe
start_marker = "<style>"
end_marker = "</style>"

start_index = content.index(start_marker)
end_index = content.index(end_marker)

if start_index && end_index && start_index < end_index
  # Remove the block including markers
  # Check if it looks right (starts near 0)
  if start_index < 100
    puts "Found style block at #{start_index} ending at #{end_index}. Removing..."
    new_content = content[0...start_index] + content[(end_index + end_marker.length)..-1]

    # Strip leading newlines that might be left
    new_content = new_content.sub(/\A\s+/, "")

    File.write(path, new_content)
    puts "Successfully removed inline CSS block."
  else
    puts "Style block not at start of file as expected. Aborting for safety."
    exit 1
  end
else
  puts "Could not find style block markers. Aborting."
  exit 1
end
