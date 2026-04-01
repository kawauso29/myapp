# ジョブ用 LLM 呼び出しモジュール（LlmClient のラッパー）
module LlmCaller
  extend ActiveSupport::Concern

  # @param prompt [String]
  # @param purpose [Symbol] :post（nano）or :creation（mini）
  # @param max_tokens [Integer]
  def call_llm(prompt, purpose: :post, max_tokens: 1000)
    LlmClient.call(prompt, purpose: purpose, max_tokens: max_tokens)
  end
end
