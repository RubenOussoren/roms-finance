require "test_helper"

class Family::AiProfileExtractorTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @chat = chats(:one)
  end

  test "skips extraction if fewer than 4 messages" do
    @chat.conversation_messages.where.not(id: @chat.conversation_messages.ordered.limit(3).pluck(:id)).destroy_all
    extractor = Family::AiProfileExtractor.new(@family, @chat)
    extractor.extract!
    assert_equal({}, @family.reload.ai_profile)
  end

  test "deep_merge combines hashes correctly" do
    extractor = Family::AiProfileExtractor.new(@family, @chat)
    base = { "name" => "Alice", "preferences" => { "theme" => "dark" } }
    overlay = { "occupation" => "Engineer", "preferences" => { "currency" => "CAD" } }
    result = extractor.send(:deep_merge, base, overlay)

    assert_equal "Alice", result["name"]
    assert_equal "Engineer", result["occupation"]
    assert_equal "dark", result["preferences"]["theme"]
    assert_equal "CAD", result["preferences"]["currency"]
  end

  test "deep_merge combines arrays with dedup" do
    extractor = Family::AiProfileExtractor.new(@family, @chat)
    base = { "goals" => [ "retire early" ] }
    overlay = { "goals" => [ "retire early", "buy house" ] }
    result = extractor.send(:deep_merge, base, overlay)

    assert_equal [ "retire early", "buy house" ], result["goals"]
  end
end
