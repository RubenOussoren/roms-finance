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

  test "snapshot names group with base model without changing stored history" do
    names = [ "gpt-5-mini", "gpt-5-mini-2025-08-07", "gpt-5-mini-20250807" ]
    replies = names.map do |name|
      chats(:one).messages.create!(type: "AssistantMessage", ai_model: name,
        content: "Recorded reply", status: :complete, input_tokens: 100, output_tokens: 50, cost_cents: 25)
    end
    chats(:one).messages.create!(type: "AssistantMessage", ai_model: "other-model",
      content: "Other reply", status: :complete, input_tokens: 10, output_tokens: 5, cost_cents: 10)

    with_self_hosting do
      get settings_ai_usage_path
      assert_response :success
      assert_select "tbody tr", count: 3 # two models and one day
      assert_select "tbody tr", text: /gpt-5-mini/ do
        assert_select "td", text: "gpt-5-mini", count: 1
        assert_select "td", text: "3", count: 1
        assert_select "td", text: "300", count: 1
        assert_select "td", text: "150", count: 1
        assert_select "td", text: "$0.75", count: 1
      end
    end
    assert_equal names, replies.map { |reply| reply.reload.ai_model }
  end

  test "unpriced replies show unknown rather than a zero cost" do
    reply = chats(:one).messages.create!(type: "AssistantMessage", ai_model: "unpriced-model",
      content: "Unpriced reply", status: :complete, input_tokens: 100, output_tokens: 50, cost_cents: nil)

    with_self_hosting do
      get settings_ai_usage_path
      assert_response :success
      assert_select "p", text: "Unknown", count: 1
      assert_select "td", text: "Unknown", count: 2
      assert_select "td", text: "$0.00", count: 0

      reply.update!(cost_cents: 25)
      chats(:one).messages.create!(type: "AssistantMessage", ai_model: reply.ai_model,
        content: "Another unpriced reply", status: :complete, input_tokens: 10, output_tokens: 5)
      get settings_ai_usage_path
      assert_select "p", text: "$0.25 + unknown", count: 1
      assert_select "td", text: "$0.25 + unknown", count: 2
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
