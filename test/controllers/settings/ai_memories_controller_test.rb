require "test_helper"

class Settings::AiMemoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    sign_in @user
    @memory = ai_memories(:preference_dark_mode)
  end

  test "show displays memories for admin" do
    with_self_hosting do
      get settings_ai_memory_path
      assert_response :success
    end
  end

  test "destroy removes a memory" do
    with_self_hosting do
      assert_difference "AiMemory.count", -1 do
        delete settings_destroy_ai_memory_path(@memory)
      end
      assert_redirected_to settings_ai_memory_path
    end
  end

  test "clear removes all memories and profile" do
    @user.family.update!(ai_profile: { "name" => "Test" })

    with_self_hosting do
      assert_difference "AiMemory.count", -@user.family.ai_memories.count do
        delete clear_settings_ai_memory_path
      end

      assert_equal({}, @user.family.reload.ai_profile)
      assert_redirected_to settings_ai_memory_path
    end
  end
end
