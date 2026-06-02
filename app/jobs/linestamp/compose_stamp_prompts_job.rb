module Linestamp
  class ComposeStampPromptsJob < ApplicationJob
    queue_as :linestamp_compose

    def perform(stamp_id)
      stamp = Linestamp::Stamp.find(stamp_id)
      return unless stamp.planned?

      composer = Linestamp::PromptComposer.new
      prompt = composer.compose_stamp_prompt(stamp)

      stamp.update!(prompt: prompt)

      # 検索タグ未設定なら候補を自動投入(ラベル/主テーマ/属性から最大9個)
      if stamp.search_keywords.blank?
        seeds = []
        seeds << stamp.display_label if stamp.label.present?
        seeds << stamp.primary_communication_theme&.name
        seeds.concat(stamp.communication_themes.pluck(:name))
        seeds.concat(stamp.attribute_values.pluck(:name))
        seeds = seeds.compact.map { |x| x.to_s.strip }.reject(&:blank?).uniq.first(9)
        stamp.update_column(:search_keywords, seeds) if seeds.any?
      end
      stamp.mark_prompt_ready! if stamp.may_mark_prompt_ready?
    end
  end
end
