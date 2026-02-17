class SnapTradeConnection < ApplicationRecord
  include Syncable

  enum :status, { good: "good", requires_update: "requires_update", disabled: "disabled" }, default: :good

  validates :authorization_id, presence: true, uniqueness: true

  before_destroy :remove_snaptrade_connection
  after_destroy :deregister_snaptrade_user_if_last

  belongs_to :family
  has_many :snaptrade_accounts, dependent: :destroy
  has_many :accounts, through: :snaptrade_accounts

  scope :active, -> { where(scheduled_for_deletion: false) }
  scope :ordered, -> { order(created_at: :desc) }
  scope :needs_update, -> { where(status: :requires_update) }

  def destroy_later
    update!(scheduled_for_deletion: true)
    DestroyJob.perform_later(self)
  end

  def import_latest_snaptrade_data
    SnapTradeConnection::Importer.new(self, snaptrade_provider: snaptrade_provider).import
  end

  def process_accounts
    snaptrade_accounts.selected.each do |snaptrade_account|
      SnapTradeAccount::Processor.new(snaptrade_account).process
    end
  end

  def refresh_brokerage_name!
    return if brokerage_name.present? && !brokerage_name.match?(/\AConnection/i)

    payload = raw_payload
    return unless payload.is_a?(Hash)

    name = payload.dig("brokerage", "name") || payload.dig(:brokerage, :name)
    update!(brokerage_name: name) if name.present?
  end

  def schedule_account_syncs(parent_sync: nil, window_start_date: nil, window_end_date: nil)
    accounts.each do |account|
      account.sync_later(
        parent_sync: parent_sync,
        window_start_date: window_start_date,
        window_end_date: window_end_date
      )
    end
  end

  private
    def snaptrade_provider
      @snaptrade_provider ||= Provider::Registry.snaptrade_provider
    end

    def remove_snaptrade_connection
      return unless snaptrade_provider
      return unless family.snaptrade_user_id.present? && family.snaptrade_user_secret.present?

      response = snaptrade_provider.remove_connection(
        authorization_id: authorization_id,
        user_id: family.snaptrade_user_id,
        user_secret: family.snaptrade_user_secret
      )

      Rails.logger.warn("SnapTrade remove_connection failed for #{authorization_id}: #{response.error&.message}") unless response.success?
    rescue => e
      Rails.logger.warn("SnapTrade remove_connection error for #{authorization_id}: #{e.message}")
    end

    def deregister_snaptrade_user_if_last
      family.deregister_snaptrade_user_if_no_connections!
    rescue => e
      Rails.logger.warn("SnapTrade deregister_user error: #{e.message}")
    end
end
