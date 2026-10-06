require "application_system_test_case"

class ChatResponseRecoveryTest < ApplicationSystemTestCase
  # Synthetic provider only: exercise the real Assistant/Responder streamer,
  # reservation, execution claim, persistence and context construction.
  class SyntheticProvider
    attr_accessor :plan
    attr_reader :requests, :checkpoints

    def initialize
      @requests = []
      @checkpoints = []
    end

    def chat_response(prompt, model:, instructions:, function_instances:, messages:, streamer:)
      attempt, chunks, timeout = plan
      @requests << { prompt: prompt, model: model, messages: messages.deep_dup, attempt_id: attempt.id }
      chunks.each do |text|
        streamer.call(Provider::LlmConcept::ChatStreamChunk.new(type: "output_text", data: text))
        persisted = AssistantMessage.find(attempt.id)
        @checkpoints << { id: persisted.id, content: persisted.content, status: persisted.status,
                          claimed: persisted.execution_claimed_at.present? }
      end
      raise Faraday::TimeoutError, "Synthetic timeout" if timeout

      response = Provider::LlmConcept::ChatResponse.new(
        id: "synthetic-#{attempt.id}", model: model, messages: [], function_requests: [],
        input_tokens: 11, output_tokens: 7
      )
      streamer.call(Provider::LlmConcept::ChatStreamChunk.new(type: "response", data: response))
      Provider::Response.new(success?: true, data: response, error: nil)
    end
  end

  setup do
    impersonation_sessions(:in_progress).complete!
    @viewer = users(:family_member)
    @viewer.update!(ai_enabled: true, show_ai_sidebar: true, last_viewed_chat: nil)
    User.any_instance.stubs(:ai_available?).returns(true)
    @provider = SyntheticProvider.new
    Assistant.any_instance.stubs(:get_model_provider).returns(@provider)
    # Flush inside the real streamer so each chunk is independently durable.
    AssistantMessage.any_instance.stubs(:should_flush?).returns(true)
    @queued_attempt_ids = []
    assert_empty response_jobs
    sign_in @viewer
  end

  teardown do
    # Retain queued evidence throughout the scenario; only remove response jobs
    # after verifying every serialized attempt was actually claimed and settled.
    assert_queue_unchanged
    response_jobs.each do |job|
      attempt = ActiveJob::Arguments.deserialize(job.fetch(:args)).sole
      assert_not_nil attempt.execution_claimed_at
      assert_includes [ "complete", "failed" ], attempt.status
    end
    ActiveJob::Base.queue_adapter.enqueued_jobs.delete_if { |job| job[:job] == AssistantResponseJob }
  end

  test "desktop timeout preserves streamed text and duplicate browser retry recovers the same prompt" do
    prompt, original = start_conversation("Synthetic recovery: explain my savings plan.")
    # Unlinked pre-rollout content stays visible but must never enter requests.
    legacy = AssistantMessage.create!(chat: @chat, ai_model: prompt.ai_model,
      status: :complete, content: "Synthetic legacy answer excluded from context.")

    execute_attempt(original, chunks: [ "Synthetic partial first. ", "Synthetic partial second." ], timeout: true)
    assert_equal [
      { id: original.id, content: "Synthetic partial first. ", status: "pending", claimed: true },
      { id: original.id, content: "Synthetic partial first. Synthetic partial second.", status: "pending", claimed: true }
    ], @provider.checkpoints
    assert_request(0, prompt, [])
    assert original.reload.failed?
    assert_equal "Synthetic partial first. Synthetic partial second.", original.content

    reload_conversation
    within article(original) do
      assert_text "FAILED"
      assert_text original.content
      assert_button "Retry"
    end
    assert_text "Older unlinked messages remain visible but are excluded from AI context"
    evidence_screenshot("issue-145-timeout-desktop")

    # Capture the originating form before navigation, then POST it again from
    # the browser with its original message_id and CSRF fields after clicking.
    stale_form = page.evaluate_script(<<~JS)
      (() => {
        const form = document.querySelector("#{article(original)} form");
        return { url: form.action, body: new URLSearchParams(new FormData(form)).toString() };
      })()
    JS
    replacement = click_recovery(original, "Retry")
    page.execute_script(<<~JS)
      fetch(#{stale_form.fetch("url").to_json}, {
        method: "POST", credentials: "same-origin",
        headers: { "Content-Type": "application/x-www-form-urlencoded",
                   "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" },
        body: #{stale_form.fetch("body").to_json}
      }).then(response => {
        document.documentElement.dataset.duplicateRetry = String(response.status);
      }).catch(() => { document.documentElement.dataset.duplicateRetry = "error"; });
    JS
    assert_selector "html[data-duplicate-retry='200']", visible: :all
    assert_equal replacement.id, original.reload.replacement.id
    assert_equal [ original.id, replacement.id ], attempts_for(prompt).pluck(:id)
    assert_queue_unchanged
    assert_equal 1, response_jobs.count { |job| serialized_attempt_id(job) == replacement.id }

    execute_attempt(replacement, chunks: [ "Synthetic recovered answer." ])
    assert_request(1, prompt, [])
    assert_equal "Synthetic recovered answer.", replacement.reload.content
    assert replacement.complete?
    assert_equal original.id, replacement.replaces_message_id
    assert_equal prompt.id, replacement.origin_user_message_id
    assert_equal 2, replacement.attempt_number
    assert_equal original.content, original.reload.content
    assert original.failed?
    assert_equal replacement.id, @chat.authoritative_response_for(prompt).id
    reload_conversation
    within article(original) do
      assert_text "FAILED"
      assert_text "Synthetic partial first. Synthetic partial second."
      assert_no_button "Retry"
    end
    within article(replacement) do
      assert_text "Synthetic recovered answer."
      assert_selector "button[aria-label='Regenerate response']", visible: :all
    end
    evidence_screenshot("issue-145-recovered-desktop")

    later, later_attempt = submit_later_prompt("Synthetic follow-up after recovery.")
    execute_attempt(later_attempt, chunks: [ "Synthetic follow-up answer." ])
    assert_request(2, later, context(prompt, replacement))
    assert_equal legacy.content, legacy.reload.content
    assert_equal 3, @provider.requests.length
    assert_queue_unchanged
  end

  test "mobile regenerates an earlier completed turn and failed regeneration retains newest successful context" do
    page.current_window.resize_to(390, 844)
    prompt, first = start_conversation("Synthetic original prompt for regeneration.")
    execute_attempt(first, chunks: [ "Synthetic first completed version." ])
    assert_request(0, prompt, [])
    later, later_attempt = submit_later_prompt("Synthetic later turn before regeneration.")
    execute_attempt(later_attempt, chunks: [ "Synthetic later completed answer." ])
    assert_request(1, later, context(prompt, first))

    reload_conversation
    regenerated = click_recovery(first, "Regenerate response")
    assert_equal prompt.id, regenerated.origin_user_message_id
    assert_equal first.id, regenerated.replaces_message_id
    assert_equal 2, regenerated.attempt_number
    execute_attempt(regenerated, chunks: [ "Synthetic newest successful version." ])
    # Regeneration uses the original prompt, not the latest browser turn, and
    # cannot consume its own previous answer or turns after its origin.
    assert_request(2, prompt, [])
    assert_equal "Synthetic first completed version.", first.reload.content
    assert first.complete?
    assert regenerated.reload.complete?
    assert_equal regenerated.id, @chat.authoritative_response_for(prompt).id
    reload_conversation
    within article(first) do
      assert_text "Previous version"
      assert_text first.content
      assert_no_selector "button[aria-label='Regenerate response']", visible: :all
    end
    within article(regenerated) do
      assert_text regenerated.content
      assert_selector "button[aria-label='Regenerate response']", visible: :all
    end
    evidence_screenshot("issue-145-regenerated-mobile")

    failed = click_recovery(regenerated, "Regenerate response")
    execute_attempt(failed, chunks: [ "Synthetic failed regeneration partial." ], timeout: true)
    assert_request(3, prompt, [])
    assert failed.reload.failed?
    assert_equal regenerated.id, failed.replaces_message_id
    assert_equal 3, failed.attempt_number
    assert_equal prompt.id, failed.origin_user_message_id
    assert_equal "Synthetic failed regeneration partial.", failed.content
    assert_equal regenerated.id, @chat.authoritative_response_for(prompt).id
    assert_equal "Synthetic newest successful version.", regenerated.reload.content
    assert regenerated.complete?
    reload_conversation
    within article(failed) do
      assert_text "FAILED"
      assert_text failed.content
      assert_button "Retry"
    end
    within article(regenerated) do
      assert_text regenerated.content
      assert_no_text "Previous version"
    end
    evidence_screenshot("issue-145-failed-regeneration-mobile")

    final_prompt, final_attempt = submit_later_prompt("Synthetic final prompt after failed regeneration.")
    execute_attempt(final_attempt, chunks: [ "Synthetic final completed answer." ])
    assert_request(4, final_prompt, context(prompt, regenerated) + context(later, later_attempt))
    assert final_attempt.reload.complete?
    assert_equal "Synthetic final completed answer.", final_attempt.content
    assert_equal [ first.id, regenerated.id, failed.id ], attempts_for(prompt).pluck(:id)
    assert_equal 5, @provider.requests.length
    assert_queue_unchanged
    reload_conversation
    within article(final_attempt) { assert_text final_attempt.content }
    evidence_screenshot("issue-145-authoritative-context-mobile")
  end

  test "reload exposes explicit interrupted recovery and fences the old queued job" do
    prompt, abandoned = start_conversation("Synthetic interrupted prompt.")
    assert abandoned.claim_execution!
    claim = abandoned.execution_claimed_at
    abandoned.update_columns(updated_at: 6.minutes.ago)
    reload_conversation
    within article(abandoned) do
      assert_text "No response update for five minutes"
      assert_text "Any late output from it will be ignored"
      assert_button "Stop and retry"
    end
    replacement = click_recovery(abandoned, "Stop and retry")
    assert abandoned.reload.failed?
    assert_equal claim, abandoned.execution_claimed_at
    assert_equal prompt.id, replacement.origin_user_message_id
    AssistantResponseJob.perform_now(abandoned)
    assert_empty @provider.requests
    execute_attempt(replacement, chunks: [ "Synthetic interrupted recovery answer." ])
    assert_request(0, prompt, [])
    reload_conversation
    within article(abandoned) { assert_text "FAILED" }
    within article(replacement) { assert_text "Synthetic interrupted recovery answer." }
    evidence_screenshot("issue-145-interrupted-recovery-desktop")
  end

  private
    def response_jobs
      ActiveJob::Base.queue_adapter.enqueued_jobs.select { |job| job[:job] == AssistantResponseJob }
    end

    def serialized_attempt_id(job)
      job.fetch(:args).sole.fetch("_aj_globalid").split("/").last
    end

    def assert_queue_unchanged
      assert_equal @queued_attempt_ids, response_jobs.map { |job| serialized_attempt_id(job) }
    end

    def assert_new_attempt(attempt)
      @queued_attempt_ids << attempt.id
      assert_queue_unchanged
      assert attempt.persisted?
      assert attempt.reload.pending?
      assert_nil attempt.execution_claimed_at
      assert_equal "", attempt.content
      assert_equal "high_priority", response_jobs.last.fetch(:queue)
    end

    def start_conversation(text)
      visit new_chat_path
      within "main #chat-form" do
        fill_in "chat[content]", with: text
        find("button[type='submit']").click
      end
      assert_selector "main [aria-label='Your message']", text: text
      @chat = @viewer.chats.find_by!(title: Chat.generate_title(text))
      prompt = @chat.messages.where(type: "UserMessage").sole
      assert_equal text, prompt.content
      assert_equal 1, prompt.conversation_turn
      attempt = attempts_for(prompt).sole
      assert_equal 1, attempt.attempt_number
      assert_nil attempt.replaces_message_id
      assert_new_attempt(attempt)
      [ prompt, attempt ]
    end

    def submit_later_prompt(text)
      reload_conversation
      within "main #chat-form" do
        fill_in "message[content]", with: text
        find("button[type='submit']").click
      end
      assert_selector "main [aria-label='Your message']", text: text
      prompt = @chat.messages.where(type: "UserMessage", content: text).sole
      attempt = attempts_for(prompt).sole
      assert_equal @chat.id, prompt.chat_id
      assert_equal prompt.id, attempt.origin_user_message_id
      assert_equal 1, attempt.attempt_number
      assert_new_attempt(attempt)
      [ prompt, attempt ]
    end

    def attempts_for(prompt)
      @chat.messages.where(type: "AssistantMessage", origin_user_message_id: prompt.id).order(:attempt_number)
    end

    def click_recovery(source, label)
      within article(source) do
        if label == "Regenerate response"
          find(".group").hover
          find("button[aria-label='Regenerate response']").click
        else
          click_button label
        end
      end
      # Wait for the POST redirect, not ActionCable, before inspecting its row.
      selector = label == "Regenerate response" ? "button[aria-label='Regenerate response']" : "button[type='submit']"
      assert_no_selector "#{article(source)} #{selector}"
      replacement = source.reload.replacement
      assert_not_nil replacement
      assert_equal source.origin_user_message_id, replacement.origin_user_message_id
      assert_new_attempt(replacement)
      replacement
    end

    def execute_attempt(attempt, chunks:, timeout: false)
      job = response_jobs.find { |entry| serialized_attempt_id(entry) == attempt.id }
      assert_not_nil job
      argument = ActiveJob::Arguments.deserialize(job.fetch(:args)).sole
      assert_instance_of AssistantMessage, argument
      assert_equal attempt.id, argument.id
      @provider.plan = [ attempt, chunks, timeout ]
      count = @provider.requests.length
      # Explicit synchronous delivery of only the exact verified queued argument.
      # The test adapter queue is retained so duplicate enqueueing cannot be hidden.
      AssistantResponseJob.perform_now(argument)
      assert_equal count + 1, @provider.requests.length
      assert_equal attempt.id, @provider.requests.last.fetch(:attempt_id)
      assert_not_nil attempt.reload.execution_claimed_at
      assert_equal chunks.join, attempt.content
      assert_equal timeout ? "failed" : "complete", attempt.status
      # Duplicate delivery must fail its real execution claim, without provider IO.
      AssistantResponseJob.perform_now(argument.reload)
      assert_equal count + 1, @provider.requests.length
    end

    def assert_request(index, prompt, messages)
      request = @provider.requests.fetch(index)
      assert_equal prompt.content, request.fetch(:prompt)
      assert_equal prompt.ai_model, request.fetch(:model)
      assert_equal messages, request.fetch(:messages)
    end

    def context(prompt, response)
      [ { role: "user", content: prompt.content }, { role: "assistant", content: response.content } ]
    end

    def article(message)
      "main #assistant_message_#{message.id}"
    end

    def reload_conversation
      visit chat_path(@chat)
      assert_selector "main [aria-label='Your message']"
    end

    def evidence_screenshot(name)
      return unless ENV["AUTONOMY_BROWSER_EVIDENCE"] == "true"

      path = Rails.root.join("tmp", "screenshots", "#{name}.png")
      FileUtils.mkdir_p(path.dirname)
      page.save_screenshot(path)
    end
end
