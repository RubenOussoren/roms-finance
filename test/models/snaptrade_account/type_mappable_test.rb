require "test_helper"

class SnapTradeAccount::TypeMappableTest < ActiveSupport::TestCase
  setup do
    @processor = SnapTradeAccount::Processor.new(snaptrade_accounts(:one))
  end

  # Canadian registered types
  test "maps TFSA to Investment with tfsa subtype" do
    assert_instance_of Investment, @processor.send(:map_accountable, "TFSA")
    assert_equal "tfsa", @processor.send(:map_subtype, "TFSA")
  end

  test "maps RRSP to Investment with rrsp subtype" do
    assert_instance_of Investment, @processor.send(:map_accountable, "RRSP")
    assert_equal "rrsp", @processor.send(:map_subtype, "RRSP")
  end

  test "maps FHSA to Investment with fhsa subtype" do
    assert_instance_of Investment, @processor.send(:map_accountable, "FHSA")
    assert_equal "fhsa", @processor.send(:map_subtype, "FHSA")
  end

  test "maps RESP to Investment with resp subtype" do
    assert_instance_of Investment, @processor.send(:map_accountable, "RESP")
    assert_equal "resp", @processor.send(:map_subtype, "RESP")
  end

  test "maps LIRA to Investment with lira subtype" do
    assert_instance_of Investment, @processor.send(:map_accountable, "LIRA")
    assert_equal "lira", @processor.send(:map_subtype, "LIRA")
  end

  test "maps RDSP to Investment with rdsp subtype" do
    assert_instance_of Investment, @processor.send(:map_accountable, "RDSP")
    assert_equal "rdsp", @processor.send(:map_subtype, "RDSP")
  end

  # Canadian non-registered
  test "maps INDIVIDUAL to Investment with non_registered subtype" do
    assert_instance_of Investment, @processor.send(:map_accountable, "INDIVIDUAL")
    assert_equal "non_registered", @processor.send(:map_subtype, "INDIVIDUAL")
  end

  # US types
  test "maps 401K to Investment with 401k subtype" do
    assert_instance_of Investment, @processor.send(:map_accountable, "401K")
    assert_equal "401k", @processor.send(:map_subtype, "401K")
  end

  test "maps IRA to Investment with ira subtype" do
    assert_instance_of Investment, @processor.send(:map_accountable, "IRA")
    assert_equal "ira", @processor.send(:map_subtype, "IRA")
  end

  # Generic types
  test "maps CASH to Depository" do
    assert_instance_of Depository, @processor.send(:map_accountable, "CASH")
    assert_equal "savings", @processor.send(:map_subtype, "CASH")
  end

  test "maps CRYPTO to Crypto" do
    assert_instance_of Crypto, @processor.send(:map_accountable, "CRYPTO")
  end

  # Unknown types default to Investment
  test "maps unknown type to Investment with brokerage subtype" do
    assert_instance_of Investment, @processor.send(:map_accountable, "UNKNOWN_TYPE")
    assert_equal "brokerage", @processor.send(:map_subtype, "UNKNOWN_TYPE")
  end

  # Case insensitivity
  test "handles lowercase type strings" do
    assert_instance_of Investment, @processor.send(:map_accountable, "tfsa")
    assert_equal "tfsa", @processor.send(:map_subtype, "tfsa")
  end
end
