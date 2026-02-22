require "test_helper"

class PlaidAccount::TypeMappableTest < ActiveSupport::TestCase
  setup do
    class MockProcessor
      include PlaidAccount::TypeMappable
    end

    @mock_processor = MockProcessor.new
  end

  test "maps types to accountables" do
    assert_instance_of Depository, @mock_processor.map_accountable("depository")
    assert_instance_of Investment, @mock_processor.map_accountable("investment")
    assert_instance_of CreditCard, @mock_processor.map_accountable("credit")
    assert_instance_of Loan, @mock_processor.map_accountable("loan")
    assert_instance_of OtherAsset, @mock_processor.map_accountable("other")
  end

  test "maps subtypes" do
    assert_equal "checking", @mock_processor.map_subtype("depository", "checking")
    assert_equal "roth_ira", @mock_processor.map_subtype("investment", "roth")
  end

  test "raises on invalid types" do
    assert_raises PlaidAccount::TypeMappable::UnknownAccountTypeError do
      @mock_processor.map_accountable("unknown")
    end
  end

  test "handles nil subtypes" do
    assert_equal "other", @mock_processor.map_subtype("depository", nil)
    assert_equal "other", @mock_processor.map_subtype("depository", "unknown")
  end

  test "line of credit overrides loan to CreditCard" do
    accountable = @mock_processor.map_accountable("loan", "line of credit")
    assert_instance_of CreditCard, accountable
  end

  test "line of credit maps to line_of_credit subtype" do
    assert_equal "line_of_credit", @mock_processor.map_subtype("loan", "line of credit")
  end

  test "map_accountable_class returns class without instantiation" do
    assert_equal Depository, @mock_processor.map_accountable_class("depository")
    assert_equal Loan, @mock_processor.map_accountable_class("loan")
    assert_equal CreditCard, @mock_processor.map_accountable_class("loan", "line of credit")
  end

  test "loan without subtype override maps to Loan" do
    assert_instance_of Loan, @mock_processor.map_accountable("loan")
    assert_instance_of Loan, @mock_processor.map_accountable("loan", "mortgage")
    assert_instance_of Loan, @mock_processor.map_accountable("loan", "student")
  end
end
