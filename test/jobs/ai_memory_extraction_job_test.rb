require "test_helper"

class AiMemoryExtractionJobTest < ActiveJob::TestCase
  setup do
    @chat = chats(:one)
  end

  test "calls generate_summary and extract!" do
    extractor = mock("extractor")
    extractor.expects(:extract!).once

    Chat.any_instance.expects(:generate_summary).once
    Family::AiProfileExtractor.expects(:new).with(@chat.user.family, @chat).returns(extractor)

    AiMemoryExtractionJob.perform_now(@chat)
  end
end
