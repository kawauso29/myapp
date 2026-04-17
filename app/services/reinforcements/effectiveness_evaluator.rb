module Reinforcements
  # Phase 20 / 補強10: improvement 起票の学習ループ。
  # 同一 `improvement_pattern_key` の過去 improvement チケットから effectiveness_score の平均と
  # サンプルサイズを返し、「低効果パターンの強行起票」を検知する。
  class EffectivenessEvaluator
    LOW_EFFECTIVENESS_THRESHOLD = 0.2
    MIN_SAMPLE_SIZE = 3

    Result = Struct.new(:pattern_key, :average_score, :sample_size, :low_effectiveness, :llm_note,
                        keyword_init: true) do
      def recommend_alternative?
        low_effectiveness
      end
    end

    def self.evaluate(pattern_key, threshold: LOW_EFFECTIVENESS_THRESHOLD, min_sample: MIN_SAMPLE_SIZE)
      new(pattern_key:, threshold:, min_sample:).evaluate
    end

    def initialize(pattern_key:, threshold: LOW_EFFECTIVENESS_THRESHOLD, min_sample: MIN_SAMPLE_SIZE)
      @pattern_key = pattern_key
      @threshold = threshold
      @min_sample = min_sample
    end

    def evaluate
      scored = TicketLedger.ticket_type_improvement
                           .where(improvement_pattern_key: pattern_key)
                           .where.not(effectiveness_score: nil)
      sample_size = scored.size
      average = sample_size.positive? ? scored.average(:effectiveness_score)&.to_f : nil
      low = sample_size >= min_sample && average.present? && average < threshold

      Result.new(
        pattern_key: pattern_key,
        average_score: average,
        sample_size: sample_size,
        low_effectiveness: low,
        llm_note: low ? llm_alternative_note(average: average, sample_size: sample_size) : nil
      )
    end

    # 強行起票が必要な場合に `audit_decision.reason_code` へ要求するコード。
    def self.override_reason_code
      "low_effectiveness_override"
    end

    private

    attr_reader :pattern_key, :threshold, :min_sample

    # Phase 40: LLM が有効な場合、低効果パターンに対する代替案のメモを返す。
    # 失敗 / gateway 無効時は nil。
    def llm_alternative_note(average:, sample_size:)
      return nil unless Llm::Gateway.enabled?

      prompt = <<~PROMPT
        改善パターン "#{pattern_key}" は平均 effectiveness=#{average&.round(3)}（n=#{sample_size}）で
        閾値 #{threshold} を下回っています。同一パターンの再試行を避け、別軸の打ち手を
        日本語 1 文（120 文字以内）で提案してください。出力はその 1 文のみ。
      PROMPT

      result = Llm::Gateway.call(purpose: :effectiveness, prompt: prompt, max_tokens: 200)
      return nil unless result.success?

      result.text.to_s.strip.lines.first.to_s.strip[0, 200]
    end
  end
end
