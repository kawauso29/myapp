module Ledgers
  # Phase 30 補強: seeds.rb が投入する必須 MeetingDefinition / ServiceLedger / KpiLedger が
  # DB に存在するかを検証する。
  #
  # Runner 群は `MeetingDefinition.find_by!` で定義を取得するため、seed 未投入のまま
  # 起動すると `ActiveRecord::RecordNotFound` でランナーが落ちる。
  # 本サービスをデプロイ後ヘルスチェックや CI で呼ぶことで、seed 漏れを事前に検知できる。
  #
  # 使い方:
  #   result = Ledgers::SeedValidator.call
  #   result.ok?         # => true / false
  #   result.missing     # => { meeting_definitions: ["weekly_dept"], ... }
  #   result.errors_text # => 人間可読なエラーメッセージ
  class SeedValidator
    REQUIRED_MEETING_KEYS = %w[
      weekly_dept
      monthly_ops
      quarterly_review
      annual_plan
    ].freeze

    REQUIRED_SERVICE_IDS = %w[ai_sns].freeze

    REQUIRED_KPI_KEYS = %w[
      kpi:service_health
      kpi:ai_sns_wau
      kpi:ai_sns_retention_7d
      kpi:ai_sns_paid_conversion
      kpi:company_revenue_growth
    ].freeze

    Result = Struct.new(:missing, keyword_init: true) do
      def ok?
        missing.values.all?(&:empty?)
      end

      def errors_text
        parts = missing.filter_map do |category, keys|
          next if keys.empty?

          "[#{category}] missing: #{keys.join(', ')}"
        end
        parts.join("\n")
      end
    end

    def self.call
      new.call
    end

    def call
      missing_meetings = REQUIRED_MEETING_KEYS - existing_meeting_keys
      missing_services = REQUIRED_SERVICE_IDS - existing_service_ids
      missing_kpis = REQUIRED_KPI_KEYS - existing_kpi_keys

      Result.new(
        missing: {
          meeting_definitions: missing_meetings,
          service_ledgers: missing_services,
          kpi_ledgers: missing_kpis
        }
      )
    end

    private

    def existing_meeting_keys
      MeetingDefinition.pluck(:meeting_key)
    end

    def existing_service_ids
      ServiceLedger.pluck(:service_id)
    end

    def existing_kpi_keys
      KpiLedger.pluck(:kpi_key)
    end
  end
end
