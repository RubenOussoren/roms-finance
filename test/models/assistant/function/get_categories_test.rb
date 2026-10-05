require "test_helper"

class Assistant::Function::GetCategoriesTest < ActiveSupport::TestCase
  setup do
    @viewer = users(:family_member)
    @function = Assistant::Function::GetCategories.new(@viewer)
    @parent = category("Synthetic parent")
    @child = category("Synthetic child", parent: @parent)
    @zero = category("Synthetic zero")
  end

  test "retains positive parent and child totals without parsing formatted currency" do
    expense(@parent, "1000.00")
    expense(@parent, "234.56")
    expense(@child, "20.25")
    expense(@child, "4.75")

    result = @function.call
    parent = result[:categories].find { |c| c[:name] == @parent.name }
    assert parent
    assert_equal "$1,234.56", parent[:spending]
    assert_equal [ { name: @child.name, classification: "expense", spending: "$25.00" } ], parent[:subcategories]
    assert_equal "USD", result[:currency]
    assert_equal "this_month", result[:period]
    # Independent arithmetic: 1000 + 234.56 and 20.25 + 4.75; no display parsing.
    assert_equal 1234.56.to_d, spending(@parent).amount
    assert_equal 25.to_d, spending(@child).amount
  end

  test "retains a zero-spending parent only when it has a positive child" do
    expense(@child, "1234.56")
    parent = @function.call[:categories].find { |c| c[:name] == @parent.name }
    assert parent
    assert_equal "$0.00", parent[:spending]
    assert_equal "$1,234.56", parent[:subcategories].sole[:spending]
    assert_equal 0.to_d, spending(@parent).amount
  end

  test "omits known zero categories and children while retaining positive subcent totals" do
    expense(@parent, "0.004")
    expense(@zero, "0")
    expense(@child, "-15")
    parent = @function.call[:categories].find { |c| c[:name] == @parent.name }
    assert parent, "positive numeric spending remains positive even when its display rounds to zero"
    assert_equal "$0.00", parent[:spending]
    assert_empty parent[:subcategories]
    refute_includes @function.call[:categories].map { |c| c[:name] }, @zero.name
    assert_equal 0.to_d, spending(@zero).amount
    assert_equal 0.to_d, spending(@child).amount
  end

  test "retains a zero parent whose positive child rounds to zero for display" do
    expense(@child, "0.004")
    parent = @function.call[:categories].find { |c| c[:name] == @parent.name }
    assert parent
    assert_equal "$0.00", parent[:spending]
    assert_equal "$0.00", parent[:subcategories].sole[:spending]
    assert_equal 0.004.to_d, spending(@child).amount
  end

  test "formatting is presentation only" do
    expense(@child, "1234.56")
    Money.any_instance.stubs(:format).returns("USD 1,234.56")
    parent = @function.call[:categories].find { |c| c[:name] == @parent.name }
    assert parent
    assert_equal "USD 1,234.56", parent[:subcategories].sole[:spending]
    assert_equal 1234.56.to_d, spending(@child).amount
  end

  test "excludes restricted foreign-family and out-of-period expenses" do
    expense(@parent, "12.34")
    [ [ accounts(:credit_card), "balance_only" ], [ accounts(:loan), "hidden" ] ].each do |account, visibility|
      account.account_permissions.create!(user: @viewer, visibility: visibility)
      expense(@parent, "9000", account: account)
    end
    foreign = families(:empty).accounts.create!(name: "Synthetic foreign", accountable: Depository.new, currency: "USD", balance: 0, created_by_user: users(:empty))
    expense(@parent, "8000", account: foreign)
    expense(@parent, "7000", date: 2.months.ago.to_date)
    foreign_category = families(:empty).categories.create!(name: "Foreign category", color: "#4da568", lucide_icon: "shopping-cart", classification: "expense")
    expense(foreign_category, "6000", account: foreign)

    result = @function.call
    parent = result[:categories].find { |c| c[:name] == @parent.name }
    assert_equal "$12.34", parent[:spending]
    assert_equal 12.34.to_d, spending(@parent).amount
    refute_includes result[:categories].map { |c| c[:name] }, foreign_category.name
    expense(@parent, "5000", account: accounts(:credit_card))
    expense(@parent, "4000", account: accounts(:loan))
    assert_equal result, @function.call
  end

  private
    def category(name, parent: nil)
      @viewer.family.categories.create!(name: name, parent: parent, classification: "expense", color: "#4da568", lucide_icon: "shopping-cart")
    end

    def expense(category, amount, account: accounts(:depository), date: Date.current)
      account.entries.create!(name: "Synthetic spending", date: date, amount: amount, currency: "USD", entryable: Transaction.new(category: category))
    end

    def spending(category)
      @function.send(:category_spending, category, [ accounts(:depository).id ], Date.current.beginning_of_month..Date.current)
    end
end
