require "test_helper"

class AiMemoryTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
  end

  test "valid memory" do
    memory = AiMemory.new(family: @family, category: "preference", content: "Test preference")
    assert memory.valid?
  end

  test "invalid category rejected" do
    memory = AiMemory.new(family: @family, category: "invalid", content: "Test")
    assert_not memory.valid?
    assert_includes memory.errors[:category], "is not included in the list"
  end

  test "content is required" do
    memory = AiMemory.new(family: @family, category: "fact")
    assert_not memory.valid?
    assert_includes memory.errors[:content], "can't be blank"
  end

  test "active scope excludes expired memories" do
    active_memories = @family.ai_memories.active
    assert_not_includes active_memories, ai_memories(:expired_memory)
    assert_includes active_memories, ai_memories(:preference_dark_mode)
  end

  test "enforces 50 memory limit by evicting oldest" do
    # Create enough memories to hit the limit
    (AiMemory::MAX_PER_FAMILY - @family.ai_memories.count).times do |i|
      AiMemory.create!(family: @family, category: "fact", content: "Fact #{i}")
    end

    assert_equal AiMemory::MAX_PER_FAMILY, @family.ai_memories.count

    # Adding one more should evict the oldest
    AiMemory.create!(family: @family, category: "fact", content: "New fact that triggers eviction")
    assert_equal AiMemory::MAX_PER_FAMILY, @family.ai_memories.count
  end
end
