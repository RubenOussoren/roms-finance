require "test_helper"

class Settings::AiUsagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
  end

  test "show displays usage for admin" do
    with_self_hosting do
      get settings_ai_usage_path
      assert_response :success
    end
  end

  test "non-admin gets redirected" do
    sign_in users(:family_member)

    with_self_hosting do
      get settings_ai_usage_path
      assert_redirected_to settings_hosting_path
    end
  end
end
