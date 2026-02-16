require "test_helper"

class SnapTradeConnectionTest < ActiveSupport::TestCase
  include SyncableInterfaceTest

  setup do
    @snaptrade_connection = @syncable = snaptrade_connections(:one)
    @snaptrade_provider = mock
    Provider::Registry.stubs(:snaptrade_provider).returns(@snaptrade_provider)
  end

  test "has many snaptrade accounts" do
    assert_respond_to @snaptrade_connection, :snaptrade_accounts
  end

  test "belongs to family" do
    assert_equal families(:dylan_family), @snaptrade_connection.family
  end

  test "validates authorization_id presence" do
    connection = SnapTradeConnection.new(family: families(:dylan_family))
    assert_not connection.valid?
    assert_includes connection.errors[:authorization_id], "can't be blank"
  end

  test "validates authorization_id uniqueness" do
    duplicate = SnapTradeConnection.new(
      family: families(:dylan_family),
      authorization_id: @snaptrade_connection.authorization_id
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:authorization_id], "has already been taken"
  end

  test "destroy_later schedules deletion" do
    assert_enqueued_with(job: DestroyJob) do
      @snaptrade_connection.destroy_later
    end

    assert @snaptrade_connection.reload.scheduled_for_deletion?
  end

  test "active scope excludes items scheduled for deletion" do
    @snaptrade_connection.update!(scheduled_for_deletion: true)
    assert_not_includes SnapTradeConnection.active, @snaptrade_connection
  end

  test "status enum" do
    assert @snaptrade_connection.good?

    @snaptrade_connection.update!(status: :requires_update)
    assert @snaptrade_connection.requires_update?

    @snaptrade_connection.update!(status: :disabled)
    assert @snaptrade_connection.disabled?
  end
end
