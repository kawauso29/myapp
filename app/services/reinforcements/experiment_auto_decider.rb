module Reinforcements
  # §33.4 R4: 実験台帳の自動判定サービス。
  # deadline を過ぎた active 実験に対して KPI 達成状況を照合し、
  # continued（継続）または withdrawn（撤退）を自動決定する。
  class ExperimentAutoDecider
    def self.call
      new.call
    end

    def call
      results = []
      ExperimentLedger.expired_candidates.find_each do |experiment|
        decision = evaluate(experiment)
        experiment.decide!(decision[:status], reason: decision[:reason])
        results << { experiment_id: experiment.id, decision: decision }
      end
      { decided: results.size, details: results }
    end

    private

    def evaluate(experiment)
      targets = Array(experiment.kpi_targets)
      return { status: :withdrawn, reason: "no_kpi_targets" } if targets.blank?

      hit_count = targets.count { |target| kpi_met?(target, experiment.service_id) }
      hit_rate = hit_count.to_f / targets.size

      if hit_rate >= 0.5
        { status: :continued, reason: "kpi_hit_rate=#{(hit_rate * 100).round(1)}%" }
      else
        { status: :withdrawn, reason: "kpi_hit_rate=#{(hit_rate * 100).round(1)}%" }
      end
    end

    def kpi_met?(target, service_id)
      normalized = target.is_a?(Hash) ? target : {}
      kpi_key = normalized["kpi_key"] || normalized[:kpi_key]
      threshold = normalized["threshold"] || normalized[:threshold]
      return false if kpi_key.blank? || threshold.blank?

      kpi = KpiLedger.find_by(kpi_key: kpi_key, service_id: service_id)
      return false unless kpi

      current = kpi.current_value
      # current_value は JSON — 数値キー "value" or 直接値
      actual = current.is_a?(Hash) ? (current["value"] || current[:value]) : current
      return false if actual.nil?

      actual.to_f >= threshold.to_f
    end
  end
end
