require "test_helper"

class ValuationsControllerTest < ActionDispatch::IntegrationTest
  include EntryableResourceInterfaceTest

  setup do
    sign_in @user = users(:family_admin)
    @entry = entries(:valuation)
  end

  test "can create reconciliation" do
    account = accounts(:investment)

    assert_difference [ "Entry.count", "Valuation.count" ], 1 do
      post valuations_url, params: {
        entry: {
          amount: account.balance + 100,
          date: Date.current.to_s,
          account_id: account.id
        }
      }
    end

    created_entry = Entry.order(created_at: :desc).first
    assert_equal "Manual value update", created_entry.name
    assert_equal Date.current, created_entry.date
    assert_equal account.balance + 100, created_entry.amount_money.to_f

    assert_enqueued_with job: SyncJob

    assert_redirected_to account_url(created_entry.account)
  end

  test "updates entry with basic attributes" do
    assert_no_difference [ "Entry.count", "Valuation.count" ] do
      patch valuation_url(@entry), params: {
        entry: {
          amount: 22000,
          date: Date.current,
          notes: "Test notes"
        }
      }
    end

    assert_enqueued_with job: SyncJob

    assert_redirected_to account_url(@entry.account)

    @entry.reload
    assert_equal 22000, @entry.amount
    assert_equal "Test notes", @entry.notes
  end

  %w[hidden balance_only].each do |visibility|
    test "#{visibility} member cannot preview valuation update" do
      account = @entry.account
      account.account_permissions.create!(user: users(:family_member), visibility: visibility)
      sign_in users(:family_member)
      original_entry = @entry.attributes
      original_account = account.reload.attributes

      assert_no_difference [ "Entry.count", "Valuation.count" ] do
        assert_no_enqueued_jobs do
          post confirm_update_valuation_url(@entry), params: {
            entry: { date: Date.current.to_s, amount: 22000 }
          }
        end
      end

      assert_response :not_found
      assert_no_match account.name, response.body
      assert_select "form[action=?]", valuation_path(@entry), count: 0
      assert_equal original_entry, @entry.reload.attributes
      assert_equal original_account, account.reload.attributes
    end
  end

  [ :family_admin, :family_member ].each do |viewer|
    test "#{viewer} can preview valuation update with full access without persisting" do
      sign_in users(viewer)
      original_entry = @entry.attributes
      original_account = @entry.account.attributes

      assert_no_enqueued_jobs do
        post confirm_update_valuation_url(@entry), params: {
          entry: { date: Date.current.to_s, amount: 22000 }
        }
      end

      assert_response :success
      assert_select "form[action=?]", valuation_path(@entry)
      assert_select "input[name='entry[amount]']" do |inputs|
        assert_equal 22000.to_d, inputs.first["value"].to_d
      end
      assert_equal original_entry, @entry.reload.attributes
      assert_equal original_account, @entry.account.reload.attributes
    end
  end

  test "foreign family cannot preview valuation update" do
    sign_in users(:empty)
    original_entry = @entry.attributes

    assert_no_enqueued_jobs do
      post confirm_update_valuation_url(@entry), params: {
        entry: { date: Date.current.to_s, amount: 22000 }
      }
    end

    assert_response :not_found
    assert_no_match @entry.account.name, response.body
    assert_select "form[action=?]", valuation_path(@entry), count: 0
    assert_equal original_entry, @entry.reload.attributes
  end
end
