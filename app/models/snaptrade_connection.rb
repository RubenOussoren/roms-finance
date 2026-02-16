class SnapTradeConnection < ApplicationRecord
  include Syncable

  enum :status, { good: "good", requires_update: "requires_update", disabled: "disabled" }, default: :good

  validates :authorization_id, presence: true, uniqueness: true

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
    snaptrade_accounts.each do |snaptrade_account|
      SnapTradeAccount::Processor.new(snaptrade_account).process
    end
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
end
