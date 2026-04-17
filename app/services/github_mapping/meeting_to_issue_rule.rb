module GithubMapping
  # §32-3: 会議出力 → Issue 自動化ルール。
  # 会議が閉じた時に decisions / hold_items / escalations から自動的に Issue を生成する条件を定義する。
  class MeetingToIssueRule
    ISSUE_TRIGGER_TYPES = %w[hold_item escalation improvement].freeze

    def self.apply(meeting)
      new(meeting).apply
    end

    def initialize(meeting)
      @meeting = meeting
    end

    def apply
      created_issues = []

      created_issues.concat(issues_from_hold_items)
      created_issues.concat(issues_from_escalations)
      created_issues.concat(issues_from_improvements)

      created_issues
    end

    private

    attr_reader :meeting

    # hold_items: KPI 不足で保留された項目を Issue に変換し、次回会議で再議論を促す
    def issues_from_hold_items
      Array(meeting.hold_items).filter_map do |item|
        normalized = item.is_a?(Hash) ? item : {}
        title = normalized["title"] || normalized[:title]
        next if title.blank?

        build_issue_payload(
          title: "[hold] #{title}",
          labels: ["meeting:hold", "meeting:#{meeting.meeting_key}"],
          body: hold_item_body(normalized)
        )
      end
    end

    # escalations: 上位会議にエスカレーションされた項目を Issue 化する
    def issues_from_escalations
      Array(meeting.escalations).filter_map do |esc|
        normalized = esc.is_a?(Hash) ? esc : {}
        ticket_id = normalized["ticket_id"] || normalized[:ticket_id]
        next if ticket_id.blank?

        build_issue_payload(
          title: "[escalation] ticket ##{ticket_id}",
          labels: ["meeting:escalation", "meeting:#{meeting.meeting_key}"],
          body: escalation_body(normalized)
        )
      end
    end

    # improvements: 検出された improvement を Issue 化する
    def issues_from_improvements
      improvement_data = extract_improvements
      return [] if improvement_data.blank?

      Array(improvement_data).filter_map do |detail|
        normalized = detail.is_a?(Hash) ? detail : {}
        title_str = normalized["title"] || normalized[:title]
        next if title_str.blank?

        build_issue_payload(
          title: "[improvement] #{title_str}",
          labels: ["meeting:improvement", "meeting:#{meeting.meeting_key}"],
          body: improvement_body(normalized)
        )
      end
    end

    def extract_improvements
      Array(meeting.directives).flat_map do |directive|
        normalized = directive.is_a?(Hash) ? directive : {}
        improvements = normalized["improvements"] || normalized[:improvements]
        next [] unless improvements.is_a?(Hash)

        Array(improvements["details"] || improvements[:details])
      end
    end

    def build_issue_payload(title:, labels:, body:)
      {
        title: title,
        labels: labels,
        body: body,
        source_meeting_id: meeting.id,
        meeting_key: meeting.meeting_key
      }
    end

    def hold_item_body(item)
      reason = item["reason"] || item[:reason] || "unknown"
      <<~MD
        ## 保留項目
        - **理由**: #{reason}
        - **次回サイクル**: #{item['next_cycle'] || item[:next_cycle] || 'weekly'}
        - **会議**: #{meeting.meeting_key} (#{meeting.held_at&.iso8601})
      MD
    end

    def escalation_body(esc)
      <<~MD
        ## エスカレーション
        - **チケットID**: #{esc['ticket_id'] || esc[:ticket_id]}
        - **エスカレーション先**: #{esc['escalation_to'] || esc[:escalation_to]}
        - **理由**: #{esc['reason'] || esc[:reason]}
        - **会議**: #{meeting.meeting_key} (#{meeting.held_at&.iso8601})
      MD
    end

    def improvement_body(detail)
      <<~MD
        ## Improvement
        - **ルール**: #{detail['rule'] || detail[:rule]}
        - **チケットID**: #{detail['ticket_id'] || detail[:ticket_id]}
        - **会議**: #{meeting.meeting_key} (#{meeting.held_at&.iso8601})
      MD
    end
  end
end
