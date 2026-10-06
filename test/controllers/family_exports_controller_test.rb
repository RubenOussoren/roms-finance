require "test_helper"

class FamilyExportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:family_admin)
    @non_admin = users(:family_member)
    @family = @admin.family

    sign_in @admin
  end

  test "non-admin cannot access exports" do
    sign_in @non_admin

    get new_family_export_path
    assert_redirected_to root_path

    post family_exports_path
    assert_redirected_to root_path

    get family_exports_path
    assert_redirected_to root_path
  end

  test "admin can view export modal" do
    get new_family_export_path
    assert_response :success
    assert_select "h2", text: "Export your data"
  end

  test "admin can create export" do
    assert_enqueued_with(job: FamilyDataExportJob) do
      post family_exports_path
    end

    assert_redirected_to settings_profile_path
    assert_equal "Export started. You'll be able to download it shortly.", flash[:notice]

    export = @family.family_exports.last
    assert_equal "pending", export.status
  end

  test "admin can view export list" do
    export1 = @family.family_exports.create!(status: "completed")
    export2 = @family.family_exports.create!(status: "processing")

    get family_exports_path
    assert_response :success

    assert_match export1.filename, response.body
    assert_match "Exporting...", response.body
  end

  test "admin can download completed export" do
    export = @family.family_exports.create!(status: "completed")
    export.export_file.attach(
      io: StringIO.new("test zip content"),
      filename: "test.zip",
      content_type: "application/zip"
    )

    get download_family_export_path(export)
    assert_response :success
    assert_equal "test zip content", response.body
    assert_equal "application/zip", response.content_type
    assert_match "attachment", response.headers["Content-Disposition"]
  end

  test "member downloads candidate tax evidence from actual tool result without deductible claims" do
    account = @family.accounts.create!(name: "Synthetic personal HELOC", accountable: Loan.new, subtype: "heloc", currency: "USD", balance: 0, created_by_user: @admin)
    entry = account.entries.create!(name: "=HYPERLINK(\"https://example.invalid\",\"interest personal use\")", date: Date.new(2026, 1, 15), amount: "-42", currency: "USD", entryable: Transaction.new)
    sign_in @non_admin
    function = Assistant::Function::GenerateTaxReport.new(@non_admin)
    tool = Provider::RubyLlm::FunctionToolAdapter.new([ function ]).tool_classes.sole.new
    result = tool.call(start_date: "2026-01-01", end_date: "2026-01-31")
    export = FamilyExport.find(result[:download_path].split("/")[-2])
    assert export.reload.downloadable?
    assert_equal @non_admin.id, export.requested_by_user_id
    get result[:download_path]
    assert_response :success
    assert_match "attachment", response.headers["Content-Disposition"]
    assert_equal export.export_file.download, response.body
    assert_includes CSV.parse(response.body), [ entry.id, "2026-01-15", account.name, "'#{entry.name}", "-42.0", "USD", "Requires review; eligibility not established" ]
    assert_match(/jurisdictional eligibility/, response.body)
    assert_match(/Candidate HELOC Interest Entries/, response.body)
    assert_match(/eligibility not established/, response.body)
    refute_match(/Deductible Interest/, response.body)
  end

  test "cannot download incomplete export" do
    export = @family.family_exports.create!(status: "processing")

    get download_family_export_path(export)
    assert_redirected_to settings_profile_path
    assert_equal "Export not ready for download", flash[:alert]
  end

  test "handles missing file gracefully on download" do
    export = @family.family_exports.create!(status: "completed")
    export.export_file.attach(
      io: StringIO.new("test zip content"),
      filename: "test.zip",
      content_type: "application/zip"
    )

    # Delete the blob from storage to simulate a missing file
    export.export_file.blob.service.delete(export.export_file.blob.key)

    get download_family_export_path(export)
    assert_redirected_to settings_profile_path
    assert_equal "This export file is no longer available. Please generate a new report.", flash[:alert]
  end

  [ :family_admin, :family_member ].each do |viewer|
    test "#{viewer} cannot download foreign family export" do
      requester = users(:empty)
      export = requester.family.family_exports.create!(status: "completed", requested_by_user: requester)
      export.export_file.attach(io: StringIO.new("private foreign export"), filename: "private.zip", content_type: "application/zip")
      original_export = export.reload.attributes
      sign_in users(viewer)

      assert_no_difference [ "FamilyExport.count", "ActiveStorage::Attachment.count" ] do
        get download_family_export_path(export)
      end

      assert_response :not_found
      assert_no_match "private foreign export", response.body
      assert_nil response.headers["Content-Disposition"]
      assert_equal original_export, export.reload.attributes
      assert export.export_file.attached?
    end
  end

  test "member can download own export but not another requester's export" do
    export = @family.family_exports.create!(status: "completed", requested_by_user: @non_admin)
    export.export_file.attach(io: StringIO.new("private requester export"), filename: "private.zip", content_type: "application/zip")
    sign_in @non_admin

    get download_family_export_path(export)
    assert_response :success
    assert_equal "private requester export", response.body
    assert_equal "application/zip", response.content_type
    assert_match "attachment", response.headers["Content-Disposition"]

    export.update!(requested_by_user: @admin)
    original_export = export.attributes
    assert_no_difference [ "FamilyExport.count", "ActiveStorage::Attachment.count" ] do
      get download_family_export_path(export)
    end

    assert_response :not_found
    assert_no_match "private requester export", response.body
    assert_nil response.headers["Content-Disposition"]
    assert_equal original_export, export.reload.attributes
    assert export.export_file.attached?
  end
end
