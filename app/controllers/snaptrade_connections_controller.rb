class SnapTradeConnectionsController < ApplicationController
  before_action :set_snaptrade_connection, only: %i[show destroy sync import_accounts]

  def new
    begin
      @portal_url = Current.family.snaptrade_connection_url
    rescue => e
      Rails.logger.error("SnapTrade connection error: #{e.message}")
      redirect_to accounts_path, alert: "Unable to connect brokerage. Please try again."
    end
  end

  def show
    @snaptrade_connection.refresh_brokerage_name!
    @snaptrade_accounts = @snaptrade_connection.snaptrade_accounts.order(:created_at)
  end

  def callback
    authorization_id = params[:authorizationId] || params[:authorization_id]

    if authorization_id.blank?
      redirect_to accounts_path, alert: "Brokerage connection was cancelled or failed."
      return
    end

    begin
      connection = Current.family.create_snaptrade_connection!(authorization_id: authorization_id)
      redirect_to snaptrade_connection_path(connection), notice: "Brokerage connected successfully. Discovering accounts..."
    rescue => e
      Rails.logger.error("SnapTrade callback error: #{e.message}")
      redirect_to accounts_path, alert: "Failed to complete brokerage connection."
    end
  end

  def destroy
    @snaptrade_connection.destroy_later
    redirect_to accounts_path, notice: "Brokerage connection scheduled for removal."
  end

  def sync
    unless @snaptrade_connection.syncing?
      @snaptrade_connection.sync_later
    end

    respond_to do |format|
      format.html { redirect_back_or_to snaptrade_connection_path(@snaptrade_connection) }
      format.json { head :ok }
    end
  end

  def import_accounts
    raw = params[:snaptrade_accounts]
    entries = case raw
    when ActionController::Parameters
              raw.values.map { |v| v.permit(:id, :selected, :custom_name) }
    when Array
              params.permit(snaptrade_accounts: [ :id, :selected, :custom_name ])[:snaptrade_accounts] || []
    else
              []
    end

    SnapTradeAccount.transaction do
      entries.each do |acct|
        snaptrade_account = @snaptrade_connection.snaptrade_accounts.find(acct[:id])
        snaptrade_account.update!(
          selected_for_import: acct[:selected] == "1",
          custom_name: acct[:custom_name].presence
        )
      end
    end

    if @snaptrade_connection.snaptrade_accounts.selected.any?
      @snaptrade_connection.sync_later unless @snaptrade_connection.syncing?
      redirect_to accounts_path, notice: "Importing selected accounts..."
    else
      redirect_to snaptrade_connection_path(@snaptrade_connection), alert: "No accounts selected for import."
    end
  end

  private
    def set_snaptrade_connection
      @snaptrade_connection = Current.family.snaptrade_connections.find(params[:id])
    end
end
