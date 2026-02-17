class PlaidItemsController < ApplicationController
  before_action :set_plaid_item, only: %i[show edit destroy sync import_accounts]

  def new
    region = params[:region] == "eu" ? :eu : :us
    webhooks_url = region == :eu ? plaid_eu_webhooks_url : plaid_us_webhooks_url

    @link_token = Current.family.get_link_token(
      webhooks_url: webhooks_url,
      accountable_type: params[:accountable_type] || "Depository",
      region: region
    )
  end

  def show
    @plaid_accounts = @plaid_item.plaid_accounts.order(:created_at)
  end

  def edit
    webhooks_url = @plaid_item.plaid_region == "eu" ? plaid_eu_webhooks_url : plaid_us_webhooks_url

    @link_token = @plaid_item.get_update_link_token(
      webhooks_url: webhooks_url
    )
  end

  def create
    plaid_item = Current.family.create_plaid_item!(
      public_token: plaid_item_params[:public_token],
      item_name: item_name,
      region: plaid_item_params[:region]
    )

    redirect_to plaid_item_path(plaid_item), notice: t(".success")
  end

  def destroy
    @plaid_item.destroy_later
    redirect_to accounts_path, notice: t(".success")
  end

  def sync
    unless @plaid_item.syncing?
      @plaid_item.sync_later
    end

    respond_to do |format|
      format.html { redirect_back_or_to accounts_path }
      format.json { head :ok }
    end
  end

  def import_accounts
    raw = params[:plaid_accounts]
    entries = case raw
    when ActionController::Parameters
      raw.values.map { |v| v.permit(:id, :selected, :custom_name) }
    when Array
      params.permit(plaid_accounts: [ :id, :selected, :custom_name ])[:plaid_accounts] || []
    else
      []
    end

    PlaidAccount.transaction do
      entries.each do |acct|
        plaid_account = @plaid_item.plaid_accounts.find(acct[:id])
        plaid_account.update!(
          selected_for_import: acct[:selected] == "1",
          custom_name: acct[:custom_name].presence
        )
      end
    end

    if @plaid_item.plaid_accounts.selected.any?
      @plaid_item.sync_later unless @plaid_item.syncing?
      redirect_to accounts_path, notice: "Importing selected accounts..."
    else
      redirect_to plaid_item_path(@plaid_item), alert: "No accounts selected for import."
    end
  end

  private
    def set_plaid_item
      @plaid_item = Current.family.plaid_items.find(params[:id])
    end

    def plaid_item_params
      params.require(:plaid_item).permit(:public_token, :region, metadata: {})
    end

    def item_name
      plaid_item_params.dig(:metadata, :institution, :name)
    end

    def plaid_us_webhooks_url
      return webhooks_plaid_url if Rails.env.production?

      ENV.fetch("DEV_WEBHOOKS_URL", root_url.chomp("/")) + "/webhooks/plaid"
    end

    def plaid_eu_webhooks_url
      return webhooks_plaid_eu_url if Rails.env.production?

      ENV.fetch("DEV_WEBHOOKS_URL", root_url.chomp("/")) + "/webhooks/plaid_eu"
    end
end
