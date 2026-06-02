module Linestamp
  class ComposePackSheetPromptJob < ApplicationJob
    queue_as :linestamp_compose

    def perform(pack_id)
      pack = Linestamp::Pack.find(pack_id)
      return unless pack.planned?
      return if pack.stamps.empty?

      composer = Linestamp::PromptComposer.new
      prompt = composer.compose_pack_sheet_prompt(pack)

      pack.update!(sheet_prompt: prompt)

      # LINE掲載メタ(日本語)と Cowork 用英語プロンプトを未設定時のみ自動生成
      meta = composer.compose_pack_line_meta(pack)
      pack.update_columns(
        line_title_ja: pack.line_title_ja.presence || meta[:title_ja],
        line_desc_ja:  pack.line_desc_ja.presence  || meta[:desc_ja],
        line_meta_prompt: pack.line_meta_prompt.presence || composer.compose_pack_line_meta_prompt(pack)
      )
      pack.mark_prompt_ready! if pack.may_mark_prompt_ready?

      Linestamp::SlackNotifier.notify(
        text: ":memo: Pack sheet prompt composed: #{pack.brand.character_name} / #{pack.series_theme}"
      )
    end
  end
end
