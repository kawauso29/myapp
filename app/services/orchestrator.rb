# Layer 2: オーケストレーター
#
# 各エージェントの判断を集約し、最終的な売買判断を下す。
#
# スコアリング方式:
#   - 各エージェントの判断を方向・確信度で数値化（0〜100点）
#   - 拒否権方式: 1つでもveto=trueなら即時skip
#   - 閾値（EXECUTE_THRESHOLD点以上）でのみ執行
#
# 出力: TradeDecision（execute/skip + direction + score）

class Orchestrator
  EXECUTE_THRESHOLD = 75.0

  AGENT_WEIGHTS = {
    "macro"       => 0.20,
    "technical"   => 0.30,
    "momentum"    => 0.20,
    "event_risk"  => 0.15,
    "sentiment"   => 0.15
  }.freeze

  def initialize
    @agents = {
      "macro"      => Agents::MacroAgent.new,
      "technical"  => Agents::TechnicalAgent.new,
      "momentum"   => Agents::MomentumAgent.new,
      "event_risk" => Agents::EventRiskAgent.new,
      "sentiment"  => Agents::SentimentAgent.new
    }
  end

  # @param snapshot [MarketSnapshot]
  # @return [TradeDecision]
  def evaluate(snapshot)
    # dangerous 状態は即時skip（エージェントを呼び出さない）
    if snapshot.dangerous? || !snapshot.confident?
      return record_decision(snapshot, score: 0.0, decision: "skip",
                              direction: nil,
                              skip_reason: "市場状態が危険または分類確信度不足 (state=#{snapshot.state}, confidence=#{snapshot.state_confidence})")
    end

    results = run_agents(snapshot)

    # 拒否権チェック: 1つでも veto があれば skip
    veto_result = results.find { |_, r| r.veto }
    if veto_result
      agent_name, result = veto_result
      return record_decision(snapshot, score: 0.0, decision: "skip",
                              direction: nil,
                              skip_reason: "拒否権発動 [#{agent_name}]: #{result.veto_reason}")
    end

    score, direction = calculate_score(results)

    if score >= EXECUTE_THRESHOLD
      record_decision(snapshot, score: score, decision: "execute",
                      direction: direction, skip_reason: nil)
    else
      record_decision(snapshot, score: score, decision: "skip",
                      direction: nil,
                      skip_reason: "スコア不足 (#{score.round(1)}点 < #{EXECUTE_THRESHOLD}点)")
    end
  end

  private

  def run_agents(snapshot)
    results = {}
    @agents.each do |name, agent|
      results[name] = agent.call(snapshot)
    rescue => e
      Rails.logger.error "[Orchestrator] #{name} agent error: #{e.message}"
      results[name] = Agents::BaseAgent::AgentResult.new(
        judgment:    "skip",
        confidence:  0.0,
        reasoning:   "エラー: #{e.message}",
        veto:        false,
        veto_reason: nil
      )
    end
    results
  end

  # 各エージェントの判断を重み付きスコアに変換
  # buy方向で+100点、sell方向で+0点（buy/sellどちらかを選択）
  # 最多方向を採用し、その方向への加重平均確信度をスコアとする
  def calculate_score(results)
    buy_score  = 0.0
    sell_score = 0.0

    results.each do |agent_name, result|
      weight     = AGENT_WEIGHTS[agent_name] || 0.0
      confidence = result.confidence.to_f

      case result.judgment
      when "buy"
        buy_score  += confidence * weight * 100
      when "sell"
        sell_score += confidence * weight * 100
      end
      # "skip" は0点加算
    end

    if buy_score >= sell_score
      [ buy_score, "buy" ]
    else
      [ sell_score, "sell" ]
    end
  end

  def record_decision(snapshot, score:, decision:, direction:, skip_reason:)
    TradeDecision.create!(
      market_snapshot: snapshot,
      final_score:     score,
      decision:        decision,
      direction:       direction,
      skip_reason:     skip_reason
    )
  end
end
