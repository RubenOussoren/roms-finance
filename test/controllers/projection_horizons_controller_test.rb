require "test_helper"

class ProjectionHorizonsControllerTest < ActionDispatch::IntegrationTest
  INVALID_YEARS = [ "", "0", "-1", "nonsense", "15", "40", "20junk", "2.5", "1000000000", "9" * 1000 ].freeze

  setup do
    @user = users(:family_admin)
    @account = accounts(:investment)
    sign_in @user
  end

  [ false, true ].each do |turbo_frame|
    ([ nil ] + %w[5 10 20 30] + INVALID_YEARS).each do |input|
      test "#{turbo_frame ? 'Turbo frame' : 'HTML'} forecast bounds horizon #{input.inspect.truncate(30)} before calculation" do
        expected = %w[5 10 20 30].include?(input) ? input.to_i : 10
        calculator = FamilyProjectionCalculator.new(@user.family, viewer: @user, scope: :personal)
        projection = calculator.project(years: expected)
        calculator.expects(:project).with(years: expected).returns(projection)
        FamilyProjectionCalculator.expects(:new).returns(calculator)
        original_cache = Rails.cache
        Rails.cache = ActiveSupport::Cache::NullStore.new

        get projections_path, params: { tab: "overview", scope: "personal", projection_years: input }.compact,
          headers: turbo_frame ? { "Turbo-Frame" => "projections-content" } : {}

        assert_response :success
        assert_select "turbo-frame#projections-content" do
          assert_select "input[name='tab'][value='overview']"
          assert_select "input[name='scope'][value='personal']"
          assert_select "select[name='projection_years'] option[selected][value='#{expected}']"
          assert_select "p[role='status']", count: INVALID_YEARS.include?(input) ? 1 : 0
        end
      ensure
        Rails.cache = original_cache
      end
    end
  end

  [ :html, :turbo_stream ].each do |format|
    (%w[5 10 20 30] + INVALID_YEARS).each do |input|
      test "#{format} settings update and reset normalize #{input.inspect.truncate(30)} and retain valid state" do
        expected = %w[5 10 20 30].include?(input) ? input.to_i : 10
        context = { tab: "investments", scope: "personal", projection_years: expected }
        params = context.merge(projection_years: input)

        patch account_projection_settings_path(@account), params: params.merge(
          expected_return: "8", volatility: "20", monthly_contribution: "123", use_pag_defaults: "0"
        ), as: format
        assert_response :see_other
        assert_redirected_to projections_path(context)
        assumption = @account.reload.projection_assumption
        assert_equal 123, assumption.monthly_contribution
        assert_equal 0.08, assumption.expected_return
        assert_equal 0.20, assumption.volatility
        follow_redirect!
        assert_response :success
        assert_select "p[role='status']", count: INVALID_YEARS.include?(input) ? 1 : 0
        assert_select "select[name='projection_years'] option[selected][value='#{expected}']"

        delete reset_account_projection_settings_path(@account), params: params, as: format
        assert_response :see_other
        assert_redirected_to projections_path(context)
        assert_nil @account.reload.projection_assumption
        follow_redirect!
        assert_response :success
        assert_select "p[role='status']", count: INVALID_YEARS.include?(input) ? 1 : 0
      end
    end
  end
end
