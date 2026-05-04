# LedgerV2::BuildCiFixArtifact — CI 失敗を分類してドラフト修正案 Artifact を生成する。
#
# 責務:
# - auto_pr FeatureFlag が有効な場合のみ動作する（デフォルト無効）
# - metric_name: "ci_success_rate" の open Ticket を探す
# - SolidQueue::FailedExecution からエラー種別を分類する（lint / test / schema / unknown）
# - 各 Ticket に対して draft の ci_fix_suggestion Artifact を 1 件作成する（冪等）
# - dry_run 対応（DB 書き込みなし）
#
# やらないこと:
# - 自動マージしない
# - 実際の GitHub PR を作らない
# - Ticket を自動クローズしない
# - FeatureFlag を変更しない
#
# 設計の正本: docs/projects/ledger-v2-migration.md §「Ticket 29」
module LedgerV2
  class BuildCiFixArtifact
    # SolidQueue のエラーメッセージから種別を判定する正規表現マップ
    FAILURE_CATEGORIES = {
      lint:   /rubocop|lint|style|offense|cop/i,
      test:   /rspec|test|failure|example|expect|\.rb:\d+/i,
      schema: /migration|schema|database|db:|PG::|ActiveRecord::/i
    }.freeze

    # @param run     [LedgerV2::Run]  RunExecutor が生成した Run
    # @param dry_run [Boolean]        true なら DB 書き込みをスキップ
    # @return [Integer] 作成した Artifact の件数
    def self.call(run:, dry_run: false)
      new(run: run, dry_run: dry_run).call
    end

    def initialize(run:, dry_run:)
      @run     = run
      @dry_run = dry_run
    end

    def call
      return 0 unless Flags.enabled?(:auto_pr)
      return 0 unless Flags.enabled?(:artifact_generation)

      ci_failure_tickets = find_ci_failure_tickets
      return 0 if ci_failure_tickets.empty?

      failures = classify_failures
      created  = 0

      ci_failure_tickets.each do |ticket|
        next if artifact_exists_for?(ticket)

        unless @dry_run
          create_artifact(ticket, failures)
        end
        created += 1
      end

      created
    end

    private

    def find_ci_failure_tickets
      Ticket.active.where(metric_name: "ci_success_rate")
    rescue => e
      Rails.logger.warn("[LedgerV2::BuildCiFixArtifact] find_ci_failure_tickets: #{e.message}")
      []
    end

    def artifact_exists_for?(ticket)
      Artifact.where(artifact_type: "ci_fix_suggestion", related_ticket: ticket).exists?
    rescue => e
      Rails.logger.warn("[LedgerV2::BuildCiFixArtifact] artifact_exists_for?: #{e.message}")
      false
    end

    # SolidQueue の直近失敗を読んでカテゴリ別件数を返す。
    # @return [Hash<Symbol, Integer>]  例: { lint: 2, test: 5, unknown: 1 }
    def classify_failures
      categories = Hash.new(0)
      SolidQueue::FailedExecution.limit(20).each do |fe|
        category = detect_category(fe.error.to_s)
        categories[category] += 1
      end
      categories
    rescue => e
      Rails.logger.warn("[LedgerV2::BuildCiFixArtifact] classify_failures: #{e.message}")
      {}
    end

    def detect_category(error_message)
      FAILURE_CATEGORIES.each do |category, pattern|
        return category if error_message.match?(pattern)
      end
      :unknown
    end

    def create_artifact(ticket, failures)
      artifact = Artifact.create!(
        artifact_type:  "ci_fix_suggestion",
        title:          "CI 修正案 #{Time.current.strftime('%Y-%m-%d')}",
        body:           build_body(ticket, failures),
        format:         "markdown",
        review_status:  :draft,
        run:            @run,
        related_ticket: ticket
      )

      Event.create!(
        run:          @run,
        event_type:   "artifact_created",
        severity:     :info,
        occurred_at:  Time.current,
        message:      "CI 修正案 Artifact ##{artifact.id} を作成しました（Ticket ##{ticket.id}）",
        payload_json: { "ticket_id" => ticket.id, "artifact_type" => "ci_fix_suggestion" }
      )
    end

    def build_body(ticket, failures)
      lines = []
      lines << "# CI 修正案（draft）"
      lines << ""
      lines << "- 生成日時: #{Time.current.strftime('%Y-%m-%d %H:%M')}"
      lines << "- 関連 Ticket: ##{ticket.id} #{ticket.title}"
      lines << "- Run ID: #{@run.id}"
      lines << ""
      lines << "## 障害分類"
      lines << ""
      if failures.empty?
        lines << "（直近の SolidQueue 失敗なし）"
      else
        failures.each do |category, count|
          lines << "- #{category}: #{count} 件"
        end
      end
      lines << ""
      lines << "## 修正案"
      lines << ""
      primary = failures.max_by { |_, v| v }&.first || :unknown
      lines += suggested_fixes(primary)
      lines << ""
      lines << "---"
      lines << ""
      lines << "このドキュメントは LedgerV2::BuildCiFixArtifact が自動生成しました。"
      lines << "内容の確定・PR 作成・デプロイは人間が承認してから行ってください。"
      lines.join("\n")
    end

    def suggested_fixes(primary_category)
      case primary_category
      when :lint
        [
          "1. `bin/rubocop --autocorrect` を実行して自動修正可能な違反を修正する",
          "2. 修正後 `bin/rubocop` でエラーがゼロになることを確認する",
          "3. PR を作成して CI を再実行する"
        ]
      when :test
        [
          "1. `bundle exec rspec --format documentation` でテストを実行して失敗箇所を確認する",
          "2. 失敗しているテストを修正する",
          "3. `bundle exec rspec` で全テストが通ることを確認してから PR を作成する"
        ]
      when :schema
        [
          "1. `bin/rails db:migrate` を実行して pending な migration を確認する",
          "2. `db/schema.rb` の version が最新 migration 番号と一致しているか確認する",
          "3. 必要に応じて `bin/rails db:schema:load` でテスト DB を再構築する"
        ]
      else
        [
          "1. SolidQueue の Failed Jobs を確認してエラーメッセージを特定する",
          "2. エラーの原因を調査して手動で修正する",
          "3. 修正後に CI を再実行して通過を確認する"
        ]
      end
    end
  end
end
