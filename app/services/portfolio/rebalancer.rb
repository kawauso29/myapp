module Portfolio
  # Phase 41b / §4.2: ポートフォリオ再編ロジック。
  #
  # 複数サービスの KPI を横断的に見て、「健全サービス」に投資を寄せ
  # 「critical が続くサービス」を絞る / exit 候補化する再編提案を
  # PortfolioStrategyLedger に `strategy_type: :rebalance` で記録する。
  #
  # 現時点ではシンプルなルール:
  #   - 対象 service_id は KpiLedger で active な service-level KPI を持つもの
  #   - grade: healthy=1.0 / warning=0.5 / critical=0.0 / nil=0.5 でスコア化
  #   - サービスごとの平均 grade_score を算出
  #   - 平均 < 0.3 → exit 候補 / 0.3〜0.7 → rebalance 候補 / 0.7〜 → 投資寄せ候補
  class Rebalancer
    Result = Struct.new(:strategy, :service_scores, :summary, keyword_init: true)

    GRADE_SCORE = {
      "healthy" => 1.0,
      "warning" => 0.5,
      "critical" => 0.0
    }.freeze

    DEFAULT_PERIOD_DAYS = 90

    def self.call(**args)
      new(**args).call
    end

    def initialize(strategy_key: nil, period_start: nil, period_end: nil,
                   source_meeting: nil, idempotency_key: nil,
                   member_service_ids: nil)
      @strategy_key = strategy_key || default_strategy_key
      @period_start = period_start || (Date.current - DEFAULT_PERIOD_DAYS)
      @period_end = period_end || Date.current
      @source_meeting = source_meeting
      @idempotency_key = idempotency_key || "portfolio_rebalance:#{@period_start}:#{@period_end}"
      @member_service_ids = member_service_ids
    end

    def call
      service_scores = compute_service_scores
      summary = build_summary(service_scores)

      strategy = PortfolioStrategyLedger.find_or_initialize_by(strategy_key: @strategy_key)
      strategy.assign_attributes(
        title: "Portfolio rebalance #{@period_start}..#{@period_end}",
        member_service_ids: service_scores.keys,
        strategy_type: :rebalance,
        status: :active,
        targets: summary,
        linked_kpis: linked_kpi_keys,
        period_start: @period_start,
        period_end: @period_end,
        source_meeting: @source_meeting,
        idempotency_key: @idempotency_key
      )
      strategy.save!

      Result.new(strategy: strategy, service_scores: service_scores, summary: summary)
    end

    private

    def default_strategy_key
      "portfolio:rebalance:#{Date.current.strftime('%Y-%m-%d')}"
    end

    def kpi_scope
      scope = KpiLedger.status_active.where(scope_level: KpiLedger.scope_levels["service"])
      scope = scope.where(service_id: @member_service_ids) if @member_service_ids.present?
      scope.where.not(service_id: nil)
    end

    def compute_service_scores
      kpis = kpi_scope.to_a
      return {} if kpis.empty?

      grouped = kpis.group_by(&:service_id)
      grouped.transform_values do |service_kpis|
        grades = service_kpis.map { |k| GRADE_SCORE.fetch(k.grade.to_s, 0.5) }
        avg = grades.sum / grades.size.to_f
        { avg_grade_score: avg.round(4), kpi_count: service_kpis.size }
      end
    end

    def build_summary(service_scores)
      classified = service_scores.each_with_object({ invest: [], rebalance: [], exit: [] }) do |(sid, metrics), acc|
        bucket = classify(metrics[:avg_grade_score])
        acc[bucket] << { service_id: sid, **metrics }
      end
      {
        services: service_scores.transform_values { |v| v.transform_keys(&:to_s) },
        invest_candidates: classified[:invest],
        rebalance_candidates: classified[:rebalance],
        exit_candidates: classified[:exit],
        computed_at: Time.current.iso8601
      }
    end

    def classify(score)
      return :exit if score < 0.3
      return :invest if score >= 0.7
      :rebalance
    end

    def linked_kpi_keys
      kpi_scope.pluck(:kpi_key).sort.uniq
    end
  end
end
