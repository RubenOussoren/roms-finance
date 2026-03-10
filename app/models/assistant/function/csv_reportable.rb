require "csv"

module Assistant::Function::CsvReportable
  extend ActiveSupport::Concern

  private
    def generate_csv_report(export_type:, start_date:, end_date:)
      export = family.family_exports.create!(
        export_type: export_type,
        status: :processing,
        requested_by_user: user
      )

      csv_data = CSV.generate { |csv| yield csv }

      export.export_file.attach(
        io: StringIO.new(csv_data),
        filename: export.filename,
        content_type: "text/csv"
      )

      export.update!(status: :completed)
      export
    rescue => e
      export&.update(status: :failed)
      raise e
    end

    def report_result(export:, summary:)
      path = "/family_exports/#{export.id}/download"
      {
        download_path: path,
        download_link: "[Download Report](#{path})",
        filename: export.filename,
        summary: summary
      }
    end

    def parse_date_range(params)
      [
        Date.parse(params["start_date"]),
        Date.parse(params["end_date"])
      ]
    end

    def date_range_properties
      {
        start_date: {
          type: "string",
          description: "Start date in YYYY-MM-DD format"
        },
        end_date: {
          type: "string",
          description: "End date in YYYY-MM-DD format"
        }
      }
    end
end
