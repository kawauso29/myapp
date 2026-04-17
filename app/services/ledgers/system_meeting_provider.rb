module Ledgers
  # Phase 30c / 補強3: `source_meeting_id` を NOT NULL にするにあたり、
  # 会議ではなく自動ジョブから発生する improvement ticket（Planner / ImprovementDetector 起票）
  # 用に「月次まとめのシステム自動化会議」を 1 件用意する。
  #
  # 月が変わると新しいシステム会議が発行され、month 内の自動起票はすべて同じ会議に
  # ぶら下がる（監査可能性を維持しつつ履歴を爆発させない）。
  class SystemMeetingProvider
    DEFAULT_KIND = "auto_improvement".freeze
    MEETING_DEFINITION_KEY = "system_auto_improvement".freeze

    # @param kind [String] 月次会議の種類ラベル（ログ用）
    # @param on [Date] 対象月の判定基準日
    def self.for(kind: DEFAULT_KIND, on: Date.current)
      new(kind: kind, on: on).find_or_create!
    end

    def initialize(kind:, on:)
      @kind = kind
      @on = on
    end

    def find_or_create!
      MeetingLedger.find_or_create_by!(idempotency_key: idempotency_key) do |meeting|
        definition = system_meeting_definition!
        meeting.meeting_definition = definition
        meeting.meeting_key = definition.meeting_key
        meeting.meeting_type = definition.meeting_type
        meeting.scope_level = definition.scope_level
        meeting.chair = definition.chair_role
        meeting.participants = definition.participant_roles
        meeting.role_fill_rate = 1.0
        meeting.held_at = @on.beginning_of_month
        meeting.status = :open
      end
    end

    private

    def idempotency_key
      "system:#{@kind}:#{@on.strftime('%Y-%m')}"
    end

    # 自動化ジョブ用の MeetingDefinition を遅延作成する。seeds.rb を汚さないため
    # 最初に参照された時点で 1 回だけ作る。
    def system_meeting_definition!
      MeetingDefinition.find_or_create_by!(meeting_key: MEETING_DEFINITION_KEY) do |definition|
        definition.meeting_type = :monthly
        definition.scope_level = :company
        definition.service_id = nil
        definition.chair_role = "system"
        definition.participant_roles = %w[system]
        definition.active = true
        definition.writes_ledgers = %w[meeting_ledger ticket_ledger]
        definition.allowed_cycles = []
      end
    end
  end
end
