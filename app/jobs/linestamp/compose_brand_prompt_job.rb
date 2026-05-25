module Linestamp
  class ComposeBrandPromptJob < ApplicationJob
    queue_as :linestamp_compose

    def perform(brand_id)
      brand = Linestamp::Brand.find(brand_id)
      return unless brand.planned?

      composer = Linestamp::PromptComposer.new
      prompt = composer.compose_brand_prompt(brand)

      brand.update!(brand_prompt: prompt)
      brand.mark_prompt_ready! if brand.may_mark_prompt_ready?

      Linestamp::SlackNotifier.notify(
        text: ":pencil: Brand prompt composed: #{brand.character_name}"
      )
    end
  end
end
