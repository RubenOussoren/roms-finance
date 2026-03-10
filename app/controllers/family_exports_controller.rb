class FamilyExportsController < ApplicationController
  include StreamExtensions

  before_action :require_admin, except: [ :download ]
  before_action :set_export, only: [ :download ]

  def new
    # Modal view for initiating export
  end

  def create
    @export = Current.family.family_exports.create!
    FamilyDataExportJob.perform_later(@export)

    respond_to do |format|
      format.html { redirect_to settings_profile_path, notice: "Export started. You'll be able to download it shortly." }
      format.turbo_stream {
        stream_redirect_to settings_profile_path, notice: "Export started. You'll be able to download it shortly."
      }
    end
  end

  def index
    @exports = Current.family.family_exports.ordered.limit(10)
    render layout: false # For turbo frame
  end

  def download
    if @export.downloadable?
      send_data @export.export_file.download,
                filename: @export.filename,
                type: @export.export_file.content_type,
                disposition: "attachment"
    else
      redirect_to settings_profile_path, alert: "Export not ready for download"
    end
  end

  private

    def set_export
      scope = Current.family.family_exports
      scope = scope.where(requested_by_user_id: Current.user.id) unless Current.user.admin?
      @export = scope.find(params[:id])
    end

    def require_admin
      unless Current.user.admin?
        redirect_to root_path, alert: "Access denied"
      end
    end
end
