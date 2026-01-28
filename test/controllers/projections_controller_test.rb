require "test_helper"

class ProjectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
  end

  test "should get index" do
    get projections_url
    assert_response :success
  end

  test "should get index with projection years param" do
    get projections_url(projection_years: 20)
    assert_response :success
  end

  test "should get index with tab param" do
    %w[overview investments debts strategies].each do |tab|
      get projections_url(tab: tab)
      assert_response :success
    end
  end

  test "overview tab loads balance sheet and projection data" do
    get projections_url(tab: "overview")
    assert_response :success
  end

  test "investments tab loads investment accounts" do
    get projections_url(tab: "investments")
    assert_response :success
  end

  test "debts tab loads loan accounts" do
    get projections_url(tab: "debts")
    assert_response :success
  end

  test "strategies tab loads debt optimization strategies" do
    get projections_url(tab: "strategies")
    assert_response :success
  end
end
