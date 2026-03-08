require "application_system_test_case"

class SmokeTest < ApplicationSystemTestCase
  test "visiting the index" do
    visit root_url

    if page.has_css?("#onboardingOverlay", visible: true, wait: 2)
      find(".onb-skip", wait: 5).click
      assert_no_selector "#onboardingOverlay", visible: true, wait: 5
    end

    assert_selector "#recordButton", wait: 5
    assert_selector "textarea#mainTranscript"
    assert_selector "#invoicePreview"
    assert_selector "#globalCurrencyBtn"

    assert_no_selector "#recordButton.recording" # Should not be recording initially
  end
end
