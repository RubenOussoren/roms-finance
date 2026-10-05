require "application_system_test_case"

class CategorySpendingChatTest < ApplicationSystemTestCase
  setup do
    impersonation_sessions(:in_progress).complete!
    @viewer = users(:family_member)
    @viewer.update!(ai_enabled: true, show_ai_sidebar: true, last_viewed_chat: nil)

    # Enable the local UI without requiring any provider credentials. The response
    # job is stubbed below, so no provider/model invocation is part of this journey.
    User.any_instance.stubs(:ai_available?).returns(true)

    @parent = create_category("Synthetic household spending")
    @subcategory = create_category("Synthetic grocery spending", parent: @parent)
    @zero = create_category("Synthetic unused spending")
    [ @parent, @subcategory ].each do |category|
      accounts(:depository).entries.create!(
        name: "Synthetic expense for #{category.name}",
        date: Date.current,
        amount: "1234.56",
        currency: "USD",
        entryable: Transaction.new(category: category)
      )
    end

    @prompt = "Show my spending categories and subcategories for this month."
    sign_in @viewer
  end

  test "desktop chat displays grounded parent and subcategory spending" do
    visit root_url(chat_view: "new")
    submit_category_prompt("#chat-container")
    chat = synthesize_grounded_response

    # Reload the existing conversation rather than depending on ActionCable delivery.
    visit root_url
    assert_grounded_conversation("#chat-container")
    assert_equal chat.id, @viewer.reload.last_viewed_chat_id
    evidence_screenshot("issue-141-category-spending-desktop")
  end

  test "mobile chat displays the same grounded category result" do
    page.current_window.resize_to(390, 844)
    visit new_chat_path
    submit_category_prompt("main")
    chat = synthesize_grounded_response

    visit chat_path(chat)
    assert_grounded_conversation("main")
    evidence_screenshot("issue-141-category-spending-mobile")
  end

  private
    def create_category(name, parent: nil)
      @viewer.family.categories.create!(
        name: name,
        parent: parent,
        classification: "expense",
        color: "#4da568",
        lucide_icon: "shopping-cart"
      )
    end

    def submit_category_prompt(container)
      # Match the existing ChatsTest boundary: persist the user's real browser
      # submission, but do not enqueue or execute an LLM response job.
      Chat.any_instance.expects(:ask_assistant_later).once

      within container do
        within "#chat-form" do
          fill_in "chat[content]", with: @prompt
          find("button[type='submit']").click
        end
        assert_selector "[aria-label='Your message']", text: @prompt
      end
    end

    def synthesize_grounded_response
      chat = @viewer.chats.find_by!(title: Chat.generate_title(@prompt))
      message = chat.messages.where(type: "UserMessage").sole
      assert_equal @prompt, message.content

      # This is a synthetic provider/chat boundary, not an end-to-end LLM test:
      # execute the actual tool for this viewer and render its returned values
      # verbatim in an AssistantMessage using the application's existing flow.
      result = Assistant::Function::GetCategories.new(@viewer).call("period" => "this_month")
      assert_equal "USD", result.fetch(:currency)
      assert_equal "this_month", result.fetch(:period)
      parent = result.fetch(:categories).find { |category| category.fetch(:name) == @parent.name }
      assert parent, "get_categories must retain a parent with positive USD spending"
      assert_equal "$1,234.56", parent.fetch(:spending)
      subcategory = parent.fetch(:subcategories).find { |category| category.fetch(:name) == @subcategory.name }
      assert subcategory, "get_categories must retain a subcategory with positive USD spending"
      assert_equal "$1,234.56", subcategory.fetch(:spending)
      assert_empty @zero.transactions
      refute_includes result.fetch(:categories).map { |category| category.fetch(:name) }, @zero.name

      lines = [ "Category spending for #{result.fetch(:period)} (#{result.fetch(:currency)}):" ]
      result.fetch(:categories).each do |category|
        lines << "- #{category.fetch(:name)}: #{category.fetch(:spending)}"
        category.fetch(:subcategories).each do |subcategory|
          lines << "  - #{subcategory.fetch(:name)}: #{subcategory.fetch(:spending)}"
        end
      end
      AssistantMessage.create!(
        chat: chat,
        ai_model: message.ai_model,
        status: :complete,
        content: lines.join("\n")
      )
      chat
    end

    def assert_grounded_conversation(container)
      within container do
        assert_selector "[aria-label='Your message']", text: @prompt
        within "[aria-label='Assistant message'] .prose" do
          assert_text "Category spending for this_month (USD)"
          assert_text "#{@parent.name}: $1,234.56"
          assert_text "#{@subcategory.name}: $1,234.56"
          assert_no_text @zero.name
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
