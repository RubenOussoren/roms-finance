class FamilyExport < ApplicationRecord
  belongs_to :family
  belongs_to :requested_by_user, class_name: "User", optional: true

  has_one_attached :export_file

  REPORT_TYPES = %w[
    full_data
    net_worth_report
    spending_report
    investment_report
    tax_report
  ].freeze

  enum :status, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }, default: :pending, validate: true

  validates :export_type, inclusion: { in: REPORT_TYPES }

  scope :ordered, -> { order(created_at: :desc) }

  def filename
    if export_type == "full_data"
      "roms_export_#{created_at.strftime('%Y%m%d_%H%M%S')}.zip"
    else
      "roms_#{export_type}_#{created_at.strftime('%Y%m%d_%H%M%S')}.csv"
    end
  end

  def downloadable?
    completed? && export_file.attached?
  end
end
