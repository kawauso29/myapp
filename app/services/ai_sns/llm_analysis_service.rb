module AiSns
  class LlmAnalysisService
    MAX_QUICK_WINS = 3
    MAX_FEATURE_PROPOSALS = 3
    JSON_CODE_BLOCK_PATTERN = /```json\s*(.*?)\s*```/m

    def self.call(observation:)
      new(observation: observation).call
    end

    def initialize(observation:)
      @observation = observation.deep_stringify_keys
    end

    def call
      raw_response = LlmClient.call(prompt, purpose: :post, max_tokens: 1200).to_s
      parsed = parse_json(raw_response)

      normalize_result(parsed, raw_response: raw_response)
    rescue => e
      Rails.logger.warn("[AiSns::LlmAnalysisService] LLM analysis failed: #{e.class} #{e.message}")
      fallback_result("LLM分析に失敗したため、観察データからルールベースで提案を生成")
    end

    private

    def prompt
      <<~PROMPT
        あなたは AI SNS のプロダクト改善アナリストです。
        以下の観察データをもとに、ユーザー体験を改善する提案を作成してください。

        観察データ(JSON):
        #{@observation.to_json}

        出力は必ず JSON のみで返してください。形式:
        {
          "summary": "全体所見",
          "quick_wins": [
            {
              "title": "即時改善タイトル",
              "reason": "理由",
              "action": { "type": "enqueue_job", "job_class": "PostMotivationCalculateJob" }
            }
          ],
          "feature_proposals": [
            {
              "title": "中長期施策タイトル",
              "rationale": "狙い・効果"
            }
          ]
        }

        制約:
        - quick_wins は最大 #{MAX_QUICK_WINS} 件
        - feature_proposals は最大 #{MAX_FEATURE_PROPOSALS} 件
        - action.type は "enqueue_job" または "notify_only"
      PROMPT
    end

    def parse_json(raw_response)
      JSON.parse(raw_response)
    rescue JSON::ParserError
      # LLM が markdown 形式で返した場合に ```json ... ``` から JSON 部分だけ抽出する
      extracted = raw_response[JSON_CODE_BLOCK_PATTERN, 1]
      raise unless extracted

      JSON.parse(extracted)
    end

    def normalize_result(parsed, raw_response:)
      quick_wins = Array(parsed["quick_wins"]).first(MAX_QUICK_WINS).map { |item| normalize_quick_win(item) }
      feature_proposals = Array(parsed["feature_proposals"]).first(MAX_FEATURE_PROPOSALS).map { |item| normalize_feature(item) }

      {
        "summary" => parsed["summary"].presence || fallback_summary,
        "quick_wins" => quick_wins,
        "feature_proposals" => feature_proposals,
        "raw_response" => raw_response
      }
    end

    def normalize_quick_win(item)
      hash = item.is_a?(Hash) ? item.deep_stringify_keys : {}
      title = hash["title"].presence || "運用改善タスク"
      action = hash["action"].is_a?(Hash) ? hash["action"].deep_stringify_keys : default_action_for(title)

      {
        "title" => title,
        "reason" => hash["reason"].presence || "観察データにもとづく改善提案",
        "action" => action
      }
    end

    def normalize_feature(item)
      hash = item.is_a?(Hash) ? item.deep_stringify_keys : {}
      {
        "title" => hash["title"].presence || "UX 改善施策",
        "rationale" => hash["rationale"].presence || "エンゲージメント改善の可能性があるため"
      }
    end

    def default_action_for(title)
      case title
      when /モチベ|投稿/
        { "type" => "enqueue_job", "job_class" => "PostMotivationCalculateJob" }
      when /状態|daily/i
        { "type" => "enqueue_job", "job_class" => "DailyStateGenerateJob" }
      else
        { "type" => "notify_only" }
      end
    end

    def fallback_result(reason)
      posts_24h = @observation.dig("totals", "posts_24h").to_i
      pending_reports = @observation.dig("operations", "pending_reports").to_i
      reply_rate = @observation.dig("engagement", "reply_rate_24h").to_f

      quick_wins = []
      if posts_24h < 30
        quick_wins << {
          "title" => "投稿モチベーション再計算を実行",
          "reason" => "24時間投稿数が少ないため活性化を優先",
          "action" => { "type" => "enqueue_job", "job_class" => "PostMotivationCalculateJob" }
        }
      end
      if pending_reports.positive?
        quick_wins << {
          "title" => "通報キューのレビューを促進",
          "reason" => "未対応通報がUX悪化要因になりやすいため",
          "action" => { "type" => "notify_only" }
        }
      end

      feature_proposals = []
      if reply_rate < 0.4
        feature_proposals << {
          "title" => "会話スレッドの再活性化施策",
          "rationale" => "返信率が低いため、会話導線の改善が必要"
        }
      end
      feature_proposals << {
        "title" => "改善ログを可視化する管理UI",
        "rationale" => "自動改善ループの効果測定を継続できるようにする"
      }

      {
        "summary" => "#{fallback_summary}（#{reason}）",
        "quick_wins" => quick_wins.first(MAX_QUICK_WINS),
        "feature_proposals" => feature_proposals.first(MAX_FEATURE_PROPOSALS),
        "raw_response" => nil
      }
    end

    def fallback_summary
      "AI SNS の観察データから、短期改善と中長期施策を整理しました"
    end
  end
end
