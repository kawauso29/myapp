module Linestamp
  class ComposePackSheetPromptJob < ApplicationJob
    queue_as :linestamp_compose

    def perform(pack_id)
      pack = Linestamp::Pack.find(pack_id)
      return unless pack.planned?

      composer = Linestamp::PromptComposer.new
      prompt = composer.compose_pack_sheet_prompt(pack)

      pack.update!(sheet_prompt: prompt)
      pack.mark_prompt_ready! if pack.may_mark_prompt_ready?

      Linestamp::SlackNotifier.notify(
        text: ":memo: Pack sheet prompt composed: #{pack.brand.character_name} / #{pack.series_theme}"
      )
    end
  end
end
