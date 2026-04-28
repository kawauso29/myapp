# LedgerV2::OpenTicket — 異常や改善候補から Ticket を作る。
#
# 責務:
# - TicketDeduplicator を呼んで重複を確認する
# - duplicate の場合: Ticket を作らず、duplicate Event を記録して既存 Ticket を返す
# - duplicate でない場合: Ticket を作り、ticket_opened Event を記録する
# - dry_run の場合: DB 書き込みをスキップし、仮結果を返す
#
# 重要ルール:
# - canonical_key なしの自動 Ticket 作成は禁止
# - duplicate 時は Ticket を作らず Event に残す
# - dry_run 時は DB 書き込みを避ける
# 設計の正本: ledger_v2_detailed_design.txt §「LedgerV2::OpenTicket」
module LedgerV2
  module OpenTicket
    # 実行結果の値オブジェクト。
    Result = Struct.new(:ticket, :duplicate_result, :created, keyword_init: true) do
      def created?
        created
      end
    end

    # @param run           [LedgerV2::Run]   この Ticket を開く Run
    # @param canonical_key [String]          重複防止キー（必須）
    # @param title         [String]          Ticket タイトル（必須）
    # @param dry_run       [Boolean]         true なら DB 書き込みをスキップ
    # @param severity      [Symbol, String]  severity（デフォルト :medium）
    # @param description   [String, nil]
    # @param source_type   [String, nil]
    # @param source_id     [String, nil]
    # @param metric_name   [String, nil]
    # @param anomaly_type  [String, nil]
    # @param period_bucket [String, nil]
    # @return [Result]
    def self.call(
      run:,
      canonical_key:,
      title:,
      dry_run: false,
      severity: :medium,
      description: nil,
      source_type: nil,
      source_id: nil,
      metric_name: nil,
      anomaly_type: nil,
      period_bucket: nil
    )
      raise ArgumentError, "canonical_key は必須です" if canonical_key.blank?
      raise ArgumentError, "title は必須です" if title.blank?

      dedup_result = TicketDeduplicator.call(
        canonical_key: canonical_key,
        source_type:   source_type,
        source_id:     source_id,
        metric_name:   metric_name,
        anomaly_type:  anomaly_type
      )

      if dedup_result.duplicate?
        record_duplicate_event(run: run, canonical_key: canonical_key, dedup_result: dedup_result) unless dry_run
        return Result.new(ticket: dedup_result.existing_ticket, duplicate_result: dedup_result, created: false)
      end

      return Result.new(ticket: nil, duplicate_result: dedup_result, created: false) if dry_run

      ticket = Ticket.create!(
        canonical_key: canonical_key,
        title:         title,
        severity:      severity,
        description:   description,
        source_type:   source_type,
        source_id:     source_id,
        metric_name:   metric_name,
        anomaly_type:  anomaly_type,
        period_bucket: period_bucket,
        opened_by_run: run
      )

      Event.create!(
        run:          run,
        event_type:   "ticket_opened",
        severity:     :info,
        occurred_at:  Time.current,
        message:      "Ticket opened: #{title}",
        payload_json: { canonical_key: canonical_key },
        subject_type: "LedgerV2::Ticket",
        subject_id:   ticket.id
      )

      Result.new(ticket: ticket, duplicate_result: dedup_result, created: true)
    end

    # @api private
    def self.record_duplicate_event(run:, canonical_key:, dedup_result:)
      Event.create!(
        run:          run,
        event_type:   "ticket_duplicate_prevented",
        severity:     :info,
        occurred_at:  Time.current,
        message:      "Ticket 重複抑止: #{dedup_result.reason}",
        payload_json: {
          canonical_key:       canonical_key,
          existing_ticket_id:  dedup_result.existing_ticket.id,
          duplicate_level:     dedup_result.duplicate_level,
          reason:              dedup_result.reason
        },
        subject_type: "LedgerV2::Ticket",
        subject_id:   dedup_result.existing_ticket.id
      )
    end
    private_class_method :record_duplicate_event
  end
end
