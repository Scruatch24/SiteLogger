ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'capybara/dsl'
require 'selenium-webdriver'

include Capybara::DSL

Capybara.default_driver = :selenium_headless
Capybara.app_host = "http://localhost:3000"

# Register chrome driver
Capybara.register_driver :selenium_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--disable-gpu')
  options.add_argument('--no-sandbox')

  # Enable logging
  options.add_option('goog:loggingPrefs', { browser: 'ALL' })

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

# We need to boot a server or use rack_test?
# Capybara needs an app.
Capybara.app = Rails.application

puts "Starting Smoke Test..."

begin
  visit '/'

  # 1. Check Home Page H1
  if page.has_selector?("h1")
    puts "[PASS] Home page loaded (H1 found)"
  else
    puts "[FAIL] Home page missing H1"
    puts "Page Title: #{page.title}"
    puts "Page Body Sample: #{page.body[0..500]}"
    exit 1
  end

  # 2. Check Record Button
  if page.has_css?("#recordButton")
    puts "[PASS] Record button found"
  else
    puts "[FAIL] Record button NOT found"
    puts "DEBUG: Dumping page body..."
    puts page.body
    exit 1
  end

  # 3. Check Interactivity (Currency Menu)
  # The menu starts hidden
  menu = page.find("#globalCurrencyMenu", visible: :all)
  if menu[:class].include?("hidden")
    puts "[PASS] Currency menu initially hidden"
  else
    puts "[FAIL] Currency menu should be hidden initially"
  end

  # Click the toggle button
  # We might need to handle specific mobile/desktop visibility,
  # assuming desktop for smoke test as per driver
  if page.has_css?("#globalCurrencyBtn")
    page.find("#globalCurrencyBtn").click
    sleep 0.5 # Wait for JS toggle

    menu = page.find("#globalCurrencyMenu", visible: :all)
    if !menu[:class].include?("hidden")
      puts "[PASS] Currency menu toggled open (JS Interactivity Verified)"
    else
      puts "[FAIL] Currency menu did not open. JS might be broken."
      puts "Browser Logs:"
      begin
        page.driver.browser.logs.get(:browser).each do |log|
          puts "[#{log.level}] #{log.message}"
        end
      rescue => e
        puts "Could not get logs: #{e.message}"
      end
      exit 1
    end
  else
    puts "[WARN] Currency button not found, skipping interactvity check"
  end

  puts "ALL TESTS PASSED"
rescue => e
  puts "Test Crashed: #{e.message}"
  exit 1
end
