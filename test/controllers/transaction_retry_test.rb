require "test_helper"

class TransactionRetryTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @account = accounts(:depository)
    @income = categories(:income)
    @income.update!(classification: "income")
    @expense = categories(:food_and_drink)
    @date = Date.current.prev_month
  end

  test "first entry defaults to today and expense with compatible categories" do
    get new_transaction_url
    assert_response :success
    assert_dom "input[name='entry[nature]'][value='outflow']"
    assert_dom "input[name='entry[date]'][value='#{Date.current}']"
    assert_dom "select[name='entry[entryable_attributes][category_id]'] option[value='#{@expense.id}']"
    assert_dom "select[name='entry[entryable_attributes][category_id]'] option[value='#{@income.id}']", count: 0
  end

  %w[inflow outflow].each do |nature|
    test "#{nature} retains intent and valid fields through repeated failures and repair" do
      category = nature == "inflow" ? @income : @expense
      other = nature == "inflow" ? @expense : @income
      attributes = transaction_attributes(nature:, category:)
      2.times do
        assert_no_difference [ "Entry.count", "Transaction.count" ] do
          post transactions_url, params: { entry: attributes }
        end
        assert_response :unprocessable_entity
        assert_dom "[role='alert']", text: "Name can't be blank"
        assert_dom "input[name='entry[nature]'][value='#{nature}']"
        assert_dom "input[name='entry[amount]'][value='125.25']"
        assert_dom "input[name='entry[date]'][value='#{@date}']"
        assert_dom "input[name='entry[account_id]'][value='#{@account.id}']"
        assert_dom "select[name='entry[entryable_attributes][category_id]'] option[value='#{category.id}'][selected]"
        assert_dom "select[name='entry[entryable_attributes][category_id]'] option[value='#{other.id}']", count: 0
        assert_dom "textarea[name='entry[notes]']", text: "Keep this note"
      end

      assert_difference [ "Entry.count", "Transaction.count" ], 1 do
        post transactions_url, params: { entry: attributes.merge(name: "Repaired #{nature}") }
      end
      assert_redirected_to account_url(@account)
      entry = Entry.find_by!(name: "Repaired #{nature}")
      assert_equal(nature == "inflow" ? -125.25.to_d : 125.25.to_d, entry.amount)
      assert_equal @date, entry.date
      assert_equal category, entry.transaction.category
      assert_equal @account, entry.account
      assert_equal "Keep this note", entry.notes
    end
  end

  test "zero income retains explicit nature without changing existing zero convention" do
    attributes = transaction_attributes(amount: "0")
    post transactions_url, params: { entry: attributes }
    assert_response :unprocessable_entity
    assert_dom "input[name='entry[nature]'][value='inflow']"
    assert_dom "input[name='entry[amount]'][value='0']"
    post transactions_url, params: { entry: attributes.merge(name: "Zero income") }
    assert_redirected_to account_url(@account)
    assert_equal 0, Entry.find_by!(name: "Zero income").amount
  end

  test "blank and malformed amounts never become valid zero transactions" do
    [ "", "invalid", "NaN", "Infinity" ].each do |amount|
      assert_no_difference [ "Entry.count", "Transaction.count" ] do
        post transactions_url, params: { entry: transaction_attributes(amount:).merge(name: "Invalid amount") }
      end
      assert_response :unprocessable_entity
      assert_dom "[role='alert']", text: /Amount/
      assert_dom "input[name='entry[nature]'][value='inflow']"
      assert_dom "input[name='entry[date]'][value='#{@date}']"
    end
  end

  test "submitted nature wins over conflicting URL context" do
    post transactions_url(nature: "outflow"), params: { entry: transaction_attributes }
    assert_response :unprocessable_entity
    assert_dom "input[name='entry[nature]'][value='inflow']"
    assert_dom "a.bg-container[href='#{new_transaction_path(nature: "inflow", account_id: @account.id)}']", text: "Income"
  end

  test "signed update without nature is not signed again" do
    entry = entries(:transaction)
    patch transaction_url(entry), params: { entry: { amount: "-125.25" } }
    assert_response :redirect
    assert_equal(-125.25.to_d, entry.reload.amount)
  end

  test "negative submitted amount retains the existing sign convention across retry" do
    attributes = transaction_attributes(amount: "-125.25")
    post transactions_url, params: { entry: attributes }
    assert_response :unprocessable_entity
    assert_dom "input[name='entry[amount]'][value='-125.25']"
    post transactions_url, params: { entry: attributes.merge(name: "Negative input") }
    assert_response :redirect
    assert_equal 125.25.to_d, Entry.find_by!(name: "Negative input").amount
  end

  private
    def transaction_attributes(nature: "inflow", category: @income, amount: "125.25")
      { account_id: @account.id, name: "", date: @date, amount:, currency: "USD",
        nature:, entryable_type: "Transaction", notes: "Keep this note",
        entryable_attributes: { category_id: category.id } }
    end
end
