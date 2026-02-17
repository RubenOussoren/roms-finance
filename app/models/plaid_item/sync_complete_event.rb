class PlaidItem::SyncCompleteEvent
  attr_reader :plaid_item

  def initialize(plaid_item)
    @plaid_item = plaid_item
  end

  def broadcast
    plaid_item.accounts.each do |account|
      account.broadcast_sync_complete
    end

    plaid_item.broadcast_replace_to(
      plaid_item.family,
      target: "plaid_item_#{plaid_item.id}",
      partial: "plaid_items/plaid_item",
      locals: { plaid_item: plaid_item }
    )

    # Update the review page frame when discovery sync completes
    plaid_item.broadcast_replace_to(
      plaid_item,
      target: "#{ActionView::RecordIdentifier.dom_id(plaid_item, :accounts)}",
      partial: "plaid_items/accounts_review",
      locals: { plaid_item: plaid_item, plaid_accounts: plaid_item.plaid_accounts.order(:created_at) }
    )

    plaid_item.family.broadcast_sync_complete
  end
end
