require "application_system_test_case"

class SmokeTest < ApplicationSystemTestCase
  test "visiting the index" do
    visit root_url

    # 1. basic page load assertions
    assert_selector "h1", text: "TalkInvoice" # Adjust if title is different logic, but usually header matches app name
    assert_selector "#recordButton", wait: 5

    # 2. Assert key UI elements for invoice generation are present
    assert_selector "textarea#mainTranscript"
    assert_selector "#invoicePreview.hidden", visible: false # Should be hidden initially

    # 3. Assert currency selector works (basic interactability check)
    assert_selector "select#currencySelector"

    # 4. Assert recording button state
    assert_no_selector "#recordButton.recording" # Should not be recording initially
  end
end
