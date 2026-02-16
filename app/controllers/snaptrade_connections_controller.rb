class SnapTradeConnectionsController < ApplicationController
  before_action :set_snaptrade_connection, only: %i[destroy sync]

  def new
    redirect_uri = callback_snaptrade_connections_url

    begin
      portal_url = Current.family.snaptrade_connection_url(redirect_uri: redirect_uri)
      redirect_to portal_url, allow_other_host: true
    rescue => e
      Rails.logger.error("SnapTrade connection error: #{e.message}")
      redirect_to accounts_path, alert: "Unable to connect brokerage. Please try again."
    end
  end

  def callback
    authorization_id = params[:authorizationId] || params[:authorization_id]

    if authorization_id.blank?
      redirect_to accounts_path, alert: "Brokerage connection was cancelled or failed."
      return
    end

    begin
      Current.family.create_snaptrade_connection!(authorization_id: authorization_id)
      redirect_to accounts_path, notice: "Brokerage connected successfully. Syncing accounts..."
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
      format.html { redirect_back_or_to accounts_path }
      format.json { head :ok }
    end
  end

  private
    def set_snaptrade_connection
      @snaptrade_connection = Current.family.snaptrade_connections.find(params[:id])
    end
end
