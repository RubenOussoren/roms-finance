require "application_system_test_case"

class TypedToolChatTest < ApplicationSystemTestCase
  setup do
    impersonation_sessions(:in_progress).complete!
    @viewer = users(:family_member)
    @viewer.update!(ai_enabled: true, show_ai_sidebar: true, last_viewed_chat: nil)

    # Enable only the UI; no credentials, provider calls, or response jobs are used.
    User.any_instance.stubs(:ai_available?).returns(true)

    @account = accounts(:loan)
    @account.update!(name: "Synthetic zero-interest loan", balance: 1200, currency: "USD")
    @account.accountable.update!(interest_rate: 0)
    Loan.any_instance.stubs(:monthly_payment).returns(Money.new(100, "USD"))

    @prompt = "When will my #{@account.name} be paid off if I pay an extra $200 per month?"
    sign_in @viewer
  end

  test "desktop chat renders a synthetic typed loan payoff result" do
    visit root_url(chat_view: "new")
    submit_payoff_prompt("#chat-container")
    chat = synthesize_typed_response

    # Reload rather than requiring ActionCable delivery of the synthetic response.
    visit root_url
    assert_payoff_conversation("#chat-container")
    assert_equal chat.id, @viewer.reload.last_viewed_chat_id
    evidence_screenshot("issue-144-typed-tool-chat-desktop")
  end

  test "mobile chat renders the same synthetic typed loan payoff result" do
    page.current_window.resize_to(390, 844)
    visit new_chat_path
    submit_payoff_prompt("main")
    chat = synthesize_typed_response

    visit chat_path(chat)
    assert_payoff_conversation("main")
    evidence_screenshot("issue-144-typed-tool-chat-mobile")
  end

  private
    def submit_payoff_prompt(container)
      # Persist the real browser submission without enqueueing an assistant job.
      Chat.any_instance.expects(:ask_assistant_later).once

      within container do
        within "#chat-form" do
          fill_in "chat[content]", with: @prompt
          find("button[type='submit']").click
        end
        assert_selector "[aria-label='Your message']", text: @prompt
      end
    end

    def synthesize_typed_response
      chat = @viewer.chats.find_by!(title: Chat.generate_title(@prompt))
      message = chat.messages.where(type: "UserMessage").sole
      assert_equal @prompt, message.content

      # Synthetic provider/chat boundary, NOT LLM-generated: use the actual
      # RubyLLM tool adapter and loan function, then render their returned values.
      function = Assistant::Function::GetLoanPayoff.new(@viewer)
      adapter = Provider::RubyLlm::FunctionToolAdapter.new([ function ])
      tool = adapter.tool_classes.sole.new

      rejected = tool.call(account_name: @account.name, extra_payment: "200")
      assert_equal "invalid_arguments", rejected.dig(:error, :type)
      assert_includes rejected.dig(:error, :details), { path: "$.extra_payment", message: "must be number" }
      refute rejected.key?(:extra_payment_scenario)
      assert_equal rejected, adapter.tool_calls_log.last.fetch(:result)

      baseline = tool.call(account_name: @account.name)
      result = tool.call(account_name: @account.name, extra_payment: 200)
      scenario = result.fetch(:extra_payment_scenario)

      # Independently derived: $1,200 / $100 = 12 months; adding $200 gives
      # $1,200 / $300 = 4 months, saving 8 months and $0 at zero interest.
      assert_equal 12, baseline.fetch(:months_to_payoff)
      assert_equal 4, result.fetch(:months_to_payoff)
      assert_equal @account.name, result.fetch(:account)
      assert_equal "USD", result.fetch(:currency)
      assert_equal "$1,200.00", result.fetch(:current_balance)
      assert_equal "$100.00", result.fetch(:monthly_payment)
      assert_equal 0, result.fetch(:interest_rate)
      assert_equal "$0.00", result.fetch(:total_interest_remaining)
      assert_equal "$200.00", scenario.fetch(:extra_monthly_payment)
      assert_equal "$300.00", scenario.fetch(:total_monthly_payment)
      assert_equal 8, scenario.fetch(:months_saved)
      assert_equal "$0.00", scenario.fetch(:interest_saved)
      assert_equal 3, adapter.tool_calls_log.length
      call = adapter.tool_calls_log.last
      assert_equal "get_loan_payoff", call.fetch(:function_name)
      assert_equal({ "account_name" => @account.name, "extra_payment" => 200 }, call.fetch(:arguments))
      assert_equal result, call.fetch(:result)

      lines = [
        "Synthetic typed-tool payoff analysis (not LLM-generated):",
        "Loan: #{result.fetch(:account)} (#{result.fetch(:currency)})",
        "Current balance: #{result.fetch(:current_balance)}",
        "Baseline monthly payment: #{result.fetch(:monthly_payment)}",
        "Interest rate: #{result.fetch(:interest_rate)}%",
        "Baseline payoff: #{baseline.fetch(:months_to_payoff)} months",
        "Extra monthly payment: #{scenario.fetch(:extra_monthly_payment)}",
        "Total monthly payment: #{scenario.fetch(:total_monthly_payment)}",
        "Accelerated payoff: #{result.fetch(:months_to_payoff)} months",
        "Months saved: #{scenario.fetch(:months_saved)}",
        "Total interest remaining: #{result.fetch(:total_interest_remaining)}",
        "Interest saved: #{scenario.fetch(:interest_saved)}"
      ]
      AssistantMessage.create!(
        chat: chat,
        ai_model: message.ai_model,
        status: :complete,
        content: lines.join("\n")
      )
      chat
    end

    def assert_payoff_conversation(container)
      within container do
        assert_selector "[aria-label='Your message']", text: @prompt
        within "[aria-label='Assistant message'] .prose" do
          assert_text "Synthetic typed-tool payoff analysis (not LLM-generated)"
          assert_text "Loan: Synthetic zero-interest loan (USD)"
          assert_text "Current balance: $1,200.00"
          assert_text "Baseline monthly payment: $100.00"
          # The model stores the rate as a decimal; tolerate its display scale.
          assert_text(/Interest rate: 0(?:\.0+)?%/)
          assert_text "Baseline payoff: 12 months"
          assert_text "Extra monthly payment: $200.00"
          assert_text "Total monthly payment: $300.00"
          assert_text "Accelerated payoff: 4 months"
          assert_text "Months saved: 8"
          assert_text "Total interest remaining: $0.00"
          assert_text "Interest saved: $0.00"
          assert_no_text "invalid_arguments"
        end
      end
    end

    def evidence_screenshot(name)
      return unless ENV["AUTONOMY_BROWSER_EVIDENCE"] == "true"

      path = Rails.root.join("tmp", "screenshots", "#{name}.png")
      FileUtils.mkdir_p(path.dirname)
      page.save_screenshot(path)
    end
end
