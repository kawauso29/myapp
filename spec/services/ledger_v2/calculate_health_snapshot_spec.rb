require "rails_helper"

RSpec.describe LedgerV2::CalculateHealthSnapshot, type: :service do
  # 集計ウィンドウ: now から 1日分
  let(:now) { Time.current }
  let(:window_start) { now - 1.day }

  def create_run(attrs = {})
    LedgerV2::Run.create!({
      runner_name:             "DailyRunner",
      trigger_type:            :schedule,
      started_at:              now - 30.minutes,
      duplicate_prevented_count: 0
    }.merge(attrs))
  end

  def create_ticket(attrs = {})
    LedgerV2::Ticket.create!({
      canonical_key:  "test:#{SecureRandom.hex(4)}",
      title:          "テストチケット",
      status:         :open,
      severity:       :medium,
      review_status:  :not_required,
      human_decision: :none,
      created_at:     now - 1.hour
    }.merge(attrs))
  end

  def create_artifact(attrs = {})
    LedgerV2::Artifact.create!({
      artifact_type:  "weekly_report",
      title:          "テストアーティファクト",
      format:         "markdown",
      review_status:  :pending,
      created_at:     now - 1.hour
    }.merge(attrs))
  end

  describe ".call" do
    context "データが存在しない場合" do
      it "すべての指標が 0 で HealthSnapshot が保存される" do
        snapshot = described_class.call(period: :daily, measured_at: now)

        expect(snapshot).to be_persisted
        expect(snapshot.ticket_noise_rate).to eq(0.0)
        expect(snapshot.artifact_acceptance_rate).to eq(0.0)
        expect(snapshot.runner_failure_rate).to eq(0.0)
        expect(snapshot.unresolved_ticket_age_avg).to eq(0.0)
        expect(snapshot.human_intervention_rate).to eq(0.0)
        expect(snapshot.kpi_improvement_after_ticket_rate).to eq(0.0)
        expect(snapshot.stop_trigger_count).to eq(0)
        expect(snapshot.duplicate_prevented_count).to eq(0)
        expect(snapshot.pending_review_count).to eq(0)
        expect(snapshot.open_ticket_count).to eq(0)
      end
    end

    context "dry_run: true の場合" do
      it "DB に保存せずに HealthSnapshot インスタンスを返す" do
        expect {
          described_class.call(period: :daily, measured_at: now, dry_run: true)
        }.not_to change(LedgerV2::HealthSnapshot, :count)
      end

      it "metadata_json に dry_run: true が記録される" do
        snapshot = described_class.call(period: :daily, measured_at: now, dry_run: true)
        expect(snapshot.metadata_json["dry_run"]).to be true
      end

      it "metadata_json に draft_pr_metrics が記録される" do
        snapshot = described_class.call(period: :daily, measured_at: now, dry_run: true)
        expect(snapshot.metadata_json["draft_pr_metrics"]).to include(
          "creation_success_rate" => 0.0,
          "created_count" => 0,
          "failed_count" => 0,
          "draft_pr_artifact_rejection_rate" => 0.0,
          "ci_repass_rate" => nil,
          "ci_repass_coverage_rate" => nil,
          "ci_terminal_count" => 0,
          "ci_retrying_count" => 0,
          "ci_terminal_reason_counts" => {}
        )
      end

      it "metadata_json に phase_d_metrics が記録される" do
        snapshot = described_class.call(period: :daily, measured_at: now, dry_run: true)
        expect(snapshot.metadata_json["phase_d_metrics"]).to include(
          "deploy_succeeded_count" => 0,
          "deploy_failed_count" => 0,
          "deploy_success_rate" => nil,
          "rollback_succeeded_count" => 0,
          "rollback_failed_count" => 0,
          "rollback_success_rate" => nil
        )
      end
    end

    context "kpi_improvement_after_ticket_rate の計算（EvaluateImprovement Event ベース）" do
      it "improvement_detected と improvement_not_detected がどちらもなければ 0.0 を返す" do
        snapshot = described_class.call(period: :daily, measured_at: now)
        expect(snapshot.kpi_improvement_after_ticket_rate).to eq(0.0)
      end

      it "improvement_detected のみ存在する場合は 1.0 になる" do
        run = create_run
        LedgerV2::Event.create!(
          run: run, event_type: "improvement_detected",
          severity: :info, occurred_at: now - 10.minutes,
          payload_json: { "ticket_id" => 1, "improved" => true }
        )

        snapshot = described_class.call(period: :daily, measured_at: now)
        expect(snapshot.kpi_improvement_after_ticket_rate).to eq(1.0)
      end

      it "improvement_detected 1件・improvement_not_detected 1件なら 0.5 になる" do
        run = create_run
        LedgerV2::Event.create!(
          run: run, event_type: "improvement_detected",
          severity: :info, occurred_at: now - 20.minutes,
          payload_json: { "ticket_id" => 1, "improved" => true }
        )
        LedgerV2::Event.create!(
          run: run, event_type: "improvement_not_detected",
          severity: :info, occurred_at: now - 10.minutes,
          payload_json: { "ticket_id" => 2, "improved" => false }
        )

        snapshot = described_class.call(period: :daily, measured_at: now)
        expect(snapshot.kpi_improvement_after_ticket_rate).to eq(0.5)
      end

      it "ウィンドウ外の Event は集計対象外" do
        run = create_run
        LedgerV2::Event.create!(
          run: run, event_type: "improvement_detected",
          severity: :info, occurred_at: now - 3.days,
          payload_json: { "ticket_id" => 1, "improved" => true }
        )

        snapshot = described_class.call(period: :daily, measured_at: now)
        expect(snapshot.kpi_improvement_after_ticket_rate).to eq(0.0)
      end
    end

    context "ticket_noise_rate の計算" do
      it "期間内の rejected / duplicate Ticket の割合を返す" do
        create_ticket(status: :rejected)
        create_ticket(status: :duplicate)
        create_ticket(status: :open)
        create_ticket(status: :resolved)

        snapshot = described_class.call(period: :daily, measured_at: now)
        # 4件中 2件がノイズ → 0.5
        expect(snapshot.ticket_noise_rate).to eq(0.5)
      end

      it "期間外の Ticket は集計対象外" do
        create_ticket(status: :rejected, created_at: now - 3.days)
        create_ticket(status: :open)

        snapshot = described_class.call(period: :daily, measured_at: now)
        # 期間内 1件、ノイズ 0件 → 0.0
        expect(snapshot.ticket_noise_rate).to eq(0.0)
      end
    end

    context "artifact_acceptance_rate の計算" do
      it "期間内の accepted / published Artifact（draft / pending 除く）の割合を返す" do
        create_artifact(review_status: :accepted)
        create_artifact(review_status: :published)
        create_artifact(review_status: :review_rejected)
        create_artifact(review_status: :draft)  # draft は除外

        snapshot = described_class.call(period: :daily, measured_at: now)
        # draft 除外後 3件中 2件が承認 → 0.6667
        expect(snapshot.artifact_acceptance_rate).to be_within(0.001).of(2.0 / 3.0)
      end

      it "pending な Artifact は分母に含めない（未決のため採用率を不当に下げない）" do
        create_artifact(review_status: :accepted)
        create_artifact(review_status: :pending)  # 未決 → 除外
        create_artifact(review_status: :draft)     # 未完成 → 除外

        snapshot = described_class.call(period: :daily, measured_at: now)
        # 最終判定済み: accepted(1) / 合計決定済み: 1 → 1.0
        expect(snapshot.artifact_acceptance_rate).to eq(1.0)
      end

      it "ウィンドウ内に最終判定済み Artifact がなくても全期間の採用率にフォールバックする" do
        # ウィンドウ外（2日前）に published Artifact を作成
        create_artifact(review_status: :published, created_at: now - 2.days)
        create_artifact(review_status: :published, created_at: now - 2.days)
        create_artifact(review_status: :review_rejected, created_at: now - 2.days)

        snapshot = described_class.call(period: :daily, measured_at: now)
        # ウィンドウ内は 0件 → 全期間で 3件中 2件が承認 → 0.6667
        expect(snapshot.artifact_acceptance_rate).to be_within(0.001).of(2.0 / 3.0)
      end

      it "全体でも最終判定済み Artifact が 0 件（全て pending / draft）なら 0.0 を返す" do
        create_artifact(review_status: :pending)
        create_artifact(review_status: :draft)


        snapshot = described_class.call(period: :daily, measured_at: now)
        expect(snapshot.artifact_acceptance_rate).to eq(0.0)
      end
    end

    context "runner_failure_rate の計算" do
      it "期間内の failed Run の割合を返す" do
        create_run(status: :success)
        create_run(status: :success)
        create_run(status: :failed)

        snapshot = described_class.call(period: :daily, measured_at: now)
        # 3件中 1件が失敗 → 0.3333
        expect(snapshot.runner_failure_rate).to be_within(0.001).of(1.0 / 3.0)
      end
    end

    context "duplicate_prevented_count の集計" do
      it "期間内の Run の duplicate_prevented_count の合計を返す" do
        create_run(status: :success, duplicate_prevented_count: 2)
        create_run(status: :success, duplicate_prevented_count: 5)

        snapshot = described_class.call(period: :daily, measured_at: now)
        expect(snapshot.duplicate_prevented_count).to eq(7)
      end
    end

    context "open_ticket_count の集計" do
      it "現在 active な Ticket 件数を返す" do
        create_ticket(status: :open)
        create_ticket(status: :in_progress)
        create_ticket(status: :deferred)
        create_ticket(status: :resolved)  # active 対象外

        snapshot = described_class.call(period: :daily, measured_at: now)
        expect(snapshot.open_ticket_count).to eq(3)
      end
    end

    context "pending_review_count の集計" do
      it "pending 状態の Artifact + Ticket の合計を返す" do
        create_artifact(review_status: :pending)
        create_artifact(review_status: :pending)
        create_ticket(review_status: :pending)

        snapshot = described_class.call(period: :daily, measured_at: now)
        expect(snapshot.pending_review_count).to eq(3)
      end
    end

    context "draft_pr_metrics の集計" do
      it "draft PR 作成成功率を metadata_json に記録する" do
        run = create_run
        LedgerV2::Event.create!(run: run, event_type: "draft_pr_created", occurred_at: now - 10.minutes)
        LedgerV2::Event.create!(run: run, event_type: "draft_pr_create_failed", occurred_at: now - 5.minutes)
        create_artifact(
          artifact_type: "ci_fix_suggestion",
          review_status: :review_rejected,
          metadata_json: {
            "draft_pr" => {
              "number" => 101,
              "ci_status" => "failure",
              "ci_terminal" => true,
              "ci_terminal_reason" => "ci_failed"
            }
          }
        )
        create_artifact(
          artifact_type: "ci_fix_suggestion",
          review_status: :accepted,
          metadata_json: {
            "draft_pr" => {
              "number" => 102,
              "ci_status" => "success",
              "ci_terminal" => true,
              "ci_terminal_reason" => "ci_passed"
            }
          }
        )
        create_artifact(
          artifact_type: "ci_fix_suggestion",
          review_status: :accepted,
          metadata_json: {
            "draft_pr" => {
              "number" => 103,
              "ci_status" => "success",
              "ci_terminal" => true,
              "ci_terminal_reason" => "pr_closed"
            }
          }
        )

        snapshot = described_class.call(period: :daily, measured_at: now)

        expect(snapshot.metadata_json.dig("draft_pr_metrics", "creation_success_rate")).to eq(0.5)
        expect(snapshot.metadata_json.dig("draft_pr_metrics", "created_count")).to eq(1)
        expect(snapshot.metadata_json.dig("draft_pr_metrics", "failed_count")).to eq(1)
        expect(snapshot.metadata_json.dig("draft_pr_metrics", "draft_pr_artifact_rejection_rate")).to be_within(0.001).of(1.0 / 3.0)
        expect(snapshot.metadata_json.dig("draft_pr_metrics", "ci_repass_rate")).to eq(0.5)
        expect(snapshot.metadata_json.dig("draft_pr_metrics", "ci_repass_coverage_rate")).to be_within(0.001).of(2.0 / 3.0)
        expect(snapshot.metadata_json.dig("draft_pr_metrics", "ci_terminal_count")).to eq(3)
        expect(snapshot.metadata_json.dig("draft_pr_metrics", "ci_retrying_count")).to eq(0)
        expect(snapshot.metadata_json.dig("draft_pr_metrics", "ci_terminal_reason_counts")).to eq(
          "ci_failed" => 1,
          "ci_passed" => 1,
          "pr_closed" => 1
        )
      end

      it "terminal 未到達の pending は ci_repass_rate の分母に含めない" do
        create_artifact(
          artifact_type: "ci_fix_suggestion",
          review_status: :accepted,
          metadata_json: {
            "draft_pr" => {
              "number" => 201,
              "ci_status" => "pending",
              "ci_terminal" => false,
              "ci_terminal_reason" => nil
            }
          }
        )
        create_artifact(
          artifact_type: "ci_fix_suggestion",
          review_status: :accepted,
          metadata_json: {
            "draft_pr" => {
              "number" => 202,
              "ci_status" => "success",
              "ci_terminal" => true,
              "ci_terminal_reason" => "ci_passed"
            }
          }
        )

        snapshot = described_class.call(period: :daily, measured_at: now)

        expect(snapshot.metadata_json.dig("draft_pr_metrics", "ci_repass_rate")).to eq(1.0)
        expect(snapshot.metadata_json.dig("draft_pr_metrics", "ci_repass_coverage_rate")).to eq(1.0)
        expect(snapshot.metadata_json.dig("draft_pr_metrics", "ci_terminal_count")).to eq(1)
        expect(snapshot.metadata_json.dig("draft_pr_metrics", "ci_retrying_count")).to eq(1)
        expect(snapshot.metadata_json.dig("draft_pr_metrics", "ci_terminal_reason_counts")).to eq(
          "ci_passed" => 1
        )
      end
    end

    context "phase_d_metrics の集計" do
      it "deploy / rollback Event が存在しない場合はすべてゼロ・rate は nil" do
        snapshot = described_class.call(period: :daily, measured_at: now)

        expect(snapshot.metadata_json.dig("phase_d_metrics", "deploy_succeeded_count")).to eq(0)
        expect(snapshot.metadata_json.dig("phase_d_metrics", "deploy_failed_count")).to eq(0)
        expect(snapshot.metadata_json.dig("phase_d_metrics", "deploy_success_rate")).to be_nil
        expect(snapshot.metadata_json.dig("phase_d_metrics", "rollback_succeeded_count")).to eq(0)
        expect(snapshot.metadata_json.dig("phase_d_metrics", "rollback_failed_count")).to eq(0)
        expect(snapshot.metadata_json.dig("phase_d_metrics", "rollback_success_rate")).to be_nil
      end

      it "deploy 成功 2件・失敗 1件の場合 deploy_success_rate が 0.6667 になる" do
        run = create_run
        2.times do
          LedgerV2::Event.create!(run: run, event_type: "phase_d_deploy_succeeded",
                                  severity: :info, occurred_at: now - 10.minutes, payload_json: {})
        end
        LedgerV2::Event.create!(run: run, event_type: "phase_d_deploy_failed",
                                severity: :error, occurred_at: now - 5.minutes, payload_json: {})

        snapshot = described_class.call(period: :daily, measured_at: now)

        expect(snapshot.metadata_json.dig("phase_d_metrics", "deploy_succeeded_count")).to eq(2)
        expect(snapshot.metadata_json.dig("phase_d_metrics", "deploy_failed_count")).to eq(1)
        expect(snapshot.metadata_json.dig("phase_d_metrics", "deploy_success_rate")).to be_within(0.001).of(2.0 / 3.0)
      end

      it "rollback 成功 1件・失敗 1件の場合 rollback_success_rate が 0.5 になる" do
        run = create_run
        LedgerV2::Event.create!(run: run, event_type: "phase_d_rollback_succeeded",
                                severity: :warning, occurred_at: now - 10.minutes, payload_json: {})
        LedgerV2::Event.create!(run: run, event_type: "phase_d_rollback_failed",
                                severity: :error, occurred_at: now - 5.minutes, payload_json: {})

        snapshot = described_class.call(period: :daily, measured_at: now)

        expect(snapshot.metadata_json.dig("phase_d_metrics", "rollback_succeeded_count")).to eq(1)
        expect(snapshot.metadata_json.dig("phase_d_metrics", "rollback_failed_count")).to eq(1)
        expect(snapshot.metadata_json.dig("phase_d_metrics", "rollback_success_rate")).to eq(0.5)
      end

      it "ウィンドウ外の Event は集計対象外" do
        run = create_run
        LedgerV2::Event.create!(run: run, event_type: "phase_d_deploy_succeeded",
                                severity: :info, occurred_at: now - 3.days, payload_json: {})

        snapshot = described_class.call(period: :daily, measured_at: now)

        expect(snapshot.metadata_json.dig("phase_d_metrics", "deploy_succeeded_count")).to eq(0)
        expect(snapshot.metadata_json.dig("phase_d_metrics", "deploy_success_rate")).to be_nil
      end
    end

    context "weekly period" do
      it "weekly で保存される" do
        snapshot = described_class.call(period: :weekly, measured_at: now)
        expect(snapshot.period_weekly?).to be true
      end

      it "metadata_json にウィンドウ範囲が記録される" do
        snapshot = described_class.call(period: :weekly, measured_at: now)
        expect(snapshot.metadata_json["window_start"]).to be_present
        expect(snapshot.metadata_json["window_end"]).to be_present
      end
    end

    context "不明な period を渡した場合" do
      it "ArgumentError を発生させる" do
        expect {
          described_class.call(period: :monthly, measured_at: now)
        }.to raise_error(ArgumentError, /unknown period/)
      end
    end
  end
end
