module Reinforcements
  # Phase 21 / 補強11: cost_ledger への記録 API。
  # ジョブ完了・会議終了・成果物出力・サービス単位の集計を統一的に扱う。
  class CostRecorder
    def self.record_job(subject_id:, amount_jpy:, source: :llm_api, scope_level: :service,
                        service_id: nil, business_unit_id: nil, source_detail: nil,
                        incurred_at: Time.current, source_ticket: nil)
      CostLedger.create!(
        subject_type: :job,
        subject_id: subject_id.to_s,
        scope_level: scope_level,
        service_id: service_id,
        business_unit_id: business_unit_id,
        amount_jpy: amount_jpy,
        source: source,
        source_detail: source_detail,
        incurred_at: incurred_at,
        source_ticket: source_ticket
      )
    end

    def self.record_meeting(meeting:, amount_jpy:, source: :human_hours, source_detail: nil,
                            incurred_at: Time.current)
      CostLedger.create!(
        subject_type: :meeting,
        subject_id: meeting.id.to_s,
        scope_level: meeting.scope_level,
        service_id: meeting.service_id,
        amount_jpy: amount_jpy,
        source: source,
        source_detail: source_detail,
        incurred_at: incurred_at,
        source_meeting: meeting
      )
    end

    def self.record_artifact(artifact_id:, amount_jpy:, source: :llm_api, scope_level: :service,
                             service_id: nil, source_detail: nil, incurred_at: Time.current)
      CostLedger.create!(
        subject_type: :artifact,
        subject_id: artifact_id.to_s,
        scope_level: scope_level,
        service_id: service_id,
        amount_jpy: amount_jpy,
        source: source,
        source_detail: source_detail,
        incurred_at: incurred_at,
        source_artifact_id: artifact_id.to_s
      )
    end

    # 指定サービスの当月合計コスト（JPY）。Phase 24 以降で roi 計算に利用する。
    def self.monthly_total(service_id:, month: Date.current)
      from = month.beginning_of_month.beginning_of_day
      to   = month.end_of_month.end_of_day
      CostLedger.where(service_id: service_id)
                .in_period(from, to)
                .sum(:amount_jpy)
    end

    def self.total_for(subject_type:, subject_id:)
      CostLedger.for_subject(subject_type, subject_id.to_s).sum(:amount_jpy)
    end
  end
end
