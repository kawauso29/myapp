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
        if action["type"] != "enqueue_job"
          next quick_win_result(quick_win, status: "skipped", reason: "notify_only")
        end

        job_class = RUNNABLE_JOB_CLASSES[action["job_class"]]
        unless job_class
          next quick_win_result(quick_win, status: "skipped", reason: "unsupported_job_class")
        end

        job_class.perform_later
        quick_win_result(quick_win, status: "applied", reason: "job_enqueued")
      rescue => e
        quick_win_result(quick_win, status: "failed", reason: "#{e.class}: #{e.message}")
      end
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
      feature_proposals.filter_map do |proposal|
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
