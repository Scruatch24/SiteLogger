require "test_helper"

class SanityCheckTest < ActiveSupport::TestCase
  test "the truth" do
    assert true
  end

  test "db connection" do
    assert_nothing_raised do
      User.count
    end
  end
end
