module AiSns
  class ImprovementExecutor
    RUNNABLE_JOB_CLASSES = {
      "DailyStateGenerateJob" => DailyStateGenerateJob,
      "WeatherFetchJob" => WeatherFetchJob,
      "PostMotivationCalculateJob" => PostMotivationCalculateJob,
      "AiActionCheckJob" => AiActionCheckJob,
      "DailyScheduleGenerateJob" => DailyScheduleGenerateJob,
      "HourlyStateUpdateJob" => HourlyStateUpdateJob
    }.freeze

    # 1日あたりの Feature Proposal PR 作成上限
    DAILY_PR_LIMIT = 2

    def self.call(analysis_result:)
      new(analysis_result: analysis_result).call
    end

    def initialize(analysis_result:)
      @analysis_result = analysis_result.deep_stringify_keys
    end

    def call
      quick_win_results = execute_quick_wins
      notify_feature_proposals(quick_win_results)
      created_prs = create_feature_proposal_prs

      {
        "applied_quick_wins" => quick_win_results.count { |item| item["status"] == "applied" },
        "quick_win_results" => quick_win_results,
        "feature_proposals_count" => feature_proposals.size,
        "created_pr_numbers" => created_prs.map { |pr| pr["number"] }
      }
    end

    private

    def execute_quick_wins
      quick_wins.map do |quick_win|
        action = quick_win["action"] || {}
        case action["type"]
        when "enqueue_job"
          execute_enqueue_job(quick_win, action)
        when "adjust_post_motivation"
          execute_adjust_post_motivation(quick_win, action)
        else
          quick_win_result(quick_win, status: "skipped", reason: "notify_only")
        end
      rescue => e
        quick_win_result(quick_win, status: "failed", reason: "#{e.class}: #{e.message}")
      end
    end

    def execute_enqueue_job(quick_win, action)
      job_class = RUNNABLE_JOB_CLASSES[action["job_class"]]
      unless job_class
        return quick_win_result(quick_win, status: "skipped", reason: "unsupported_job_class")
      end

      job_class.perform_later
      quick_win_result(quick_win, status: "applied", reason: "job_enqueued")
    end

    # 全アクティブ AI の post_motivation を一時的に底上げする
    def execute_adjust_post_motivation(quick_win, action)
      boost = [ action["boost"].to_i, 5 ].max
      updated = AiDailyState.where(date: Date.current)
                             .joins(ai_user: {})
                             .merge(AiUser.active)
                             .update_all([ "post_motivation = LEAST(post_motivation + ?, 100)", boost ])
      quick_win_result(quick_win, status: "applied", reason: "post_motivation_boosted_by_#{boost} (#{updated} AIs)")
    end

    def notify_feature_proposals(quick_win_results)
      return if feature_proposals.empty? && quick_win_results.none? { |result| result["status"] == "applied" }

      fields = [
        { title: "Summary", value: @analysis_result["summary"].presence || "-" },
        { title: "Quick Win Applied", value: quick_win_results.count { |result| result["status"] == "applied" }.to_s },
        { title: "Feature Proposals", value: feature_proposals.count.to_s }
      ]

      feature_proposals.each_with_index do |proposal, index|
        feature_number = index + 1
        fields << {
          title: "Feature #{feature_number}",
          value: "#{proposal['title']} - #{proposal['rationale']}",
          short: false
        }
      end

      SlackNotifierService.notify(
        text: ":bulb: AI SNS 自動改善ループの提案を作成しました",
        color: :info,
        fields: fields,
        channel: :jobs
      )
    end

    def create_feature_proposal_prs
      # 日次 PR 作成上限チェック
      today_pr_count = ImprovementLog.where(created_at: Date.current.all_day)
                                     .pluck(:created_pr_numbers)
                                     .flatten
                                     .compact
                                     .size
      remaining_quota = [ DAILY_PR_LIMIT - today_pr_count, 0 ].max
      return [] if remaining_quota.zero?

      # 直近の提案済みタイトルで重複排除
      recent_titles = ImprovementLog.recent_feature_titles(limit: 10)
      # plan_status.yml の既存タイトルでも重複排除
      plan_titles = Admin::AiSnsPlanService.items.values.map { |v| v["title"] }.compact.to_set

      deduped = feature_proposals.reject do |proposal|
        title = proposal["title"].to_s
        recent_titles.any? { |t| t.to_s == title } || plan_titles.any? { |t| t.to_s == title }
      end

      deduped.first(remaining_quota).filter_map do |proposal|
        title = proposal["title"]
        rationale = proposal["rationale"]

        body = <<~BODY
          ## AI SNS 自動提案 Feature Proposal

          **タイトル**: #{title}

          ### 狙い・効果
          #{rationale}

          ---

          @github-copilot `docs/ai_sns_improvement_plan.md` の計画書を参照し、既存コードとの整合性を保ちながら **#{title}** を実装してください。

          <!-- copilot:model claude-opus-4.6 -->
        BODY

        pr = GithubPrService.create_pr(
          title: "[AI SNS自動提案] #{title}",
          body: body
        )
        Rails.logger.info("[ImprovementExecutor] Feature proposal PR created: ##{pr['number']}") if pr
        pr
      end
    end

    def quick_win_result(quick_win, status:, reason:)
      {
        "title" => quick_win["title"],
        "status" => status,
        "reason" => reason
      }
    end

    def quick_wins
      Array(@analysis_result["quick_wins"])
    end

    def feature_proposals
      Array(@analysis_result["feature_proposals"])
    end
  end
end
