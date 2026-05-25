module Linestamp
  class ComposeStampPromptsJob < ApplicationJob
    queue_as :linestamp_compose

    def perform(stamp_id)
      stamp = Linestamp::Stamp.find(stamp_id)
      return unless stamp.planned?

      composer = Linestamp::PromptComposer.new
      prompt = composer.compose_stamp_prompt(stamp)

      stamp.update!(prompt: prompt)
      stamp.mark_prompt_ready! if stamp.may_mark_prompt_ready?
    end
  end
end
