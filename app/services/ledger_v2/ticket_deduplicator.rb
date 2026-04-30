# LedgerV2::TicketDeduplicator — 意味的に同じ Ticket の重複を防ぐ。
#
# 判定順:
#   Level 1: canonical_key 完全一致 + active 状態確認
#   Level 2: source_type + source_id + metric_name + anomaly_type 一致 + active 状態確認
#   Level 3: metric_name + anomaly_type 一致 + active 状態確認
#            （source_type/source_id が nil の場合でも跨日重複を抑止するため）
#
# 重要ルール:
# - Level 1 完全一致は必ず止める
# - Level 2 類似一致は警告 Event に留めてもよいが、初期は duplicate 扱いにする
# - Level 3 は source なしの全体指標（error_count 等）向け。open チケットが存在する間は
#   日付が変わっても同じ異常を新規起票しない。
# - resolved / rejected 後の再起票は canonical_key を再利用してよい（active でないため通過）
# 設計の正本: ledger_v2_detailed_design.txt §「LedgerV2::TicketDeduplicator」
module LedgerV2
  module TicketDeduplicator
    # 重複判定結果の値オブジェクト。
    DeduplicationResult = Struct.new(
      :duplicate,
      :existing_ticket,
      :reason,
      :duplicate_level,
      keyword_init: true
    ) do
      def duplicate?
        duplicate
      end
    end

    # @param canonical_key [String]
    # @param source_type   [String, nil]
    # @param source_id     [String, nil]
    # @param metric_name   [String, nil]
    # @param anomaly_type  [String, nil]
    # @return [DeduplicationResult]
    def self.call(canonical_key:, source_type: nil, source_id: nil, metric_name: nil, anomaly_type: nil)
      # Level 1: canonical_key 完全一致
      existing = Ticket.active.find_by(canonical_key: canonical_key)
      if existing
        return DeduplicationResult.new(
          duplicate:       true,
          existing_ticket: existing,
          reason:          "canonical_key の完全一致",
          duplicate_level: 1
        )
      end

      # Level 2: source_type + source_id + metric_name + anomaly_type 一致
      if source_type.present? && source_id.present? && metric_name.present? && anomaly_type.present?
        similar = Ticket.active
                        .where(source_type: source_type, source_id: source_id,
                               metric_name: metric_name, anomaly_type: anomaly_type)
                        .limit(1).first
        if similar
          return DeduplicationResult.new(
            duplicate:       true,
            existing_ticket: similar,
            reason:          "source_type/source_id/metric_name/anomaly_type の一致",
            duplicate_level: 2
          )
        end
      end

      # Level 3: metric_name + anomaly_type 一致（source なしの全体指標向け跨日重複抑止）
      if metric_name.present? && anomaly_type.present?
        similar = Ticket.active
                        .where(metric_name: metric_name, anomaly_type: anomaly_type)
                        .limit(1).first
        if similar
          return DeduplicationResult.new(
            duplicate:       true,
            existing_ticket: similar,
            reason:          "metric_name/anomaly_type の一致（跨日重複抑止）",
            duplicate_level: 3
          )
        end
      end

      DeduplicationResult.new(duplicate: false, existing_ticket: nil, reason: nil, duplicate_level: nil)
    end
  end
end
