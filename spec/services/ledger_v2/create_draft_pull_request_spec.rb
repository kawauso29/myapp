require "rails_helper"

RSpec.describe LedgerV2::CreateDraftPullRequest, type: :service do
  let(:run) { LedgerV2::Run.create!(runner_name: "WeeklyRunner", trigger_type: :schedule) }
  let(:ticket) do
    LedgerV2::Ticket.create!(
      canonical_key: "ledger_v2:ci_success_rate:below_minimum:daily:2026-05-08",
      title: "CI 成功率が閾値を下回っています",
      status: :open,
      severity: :high,
      metric_name: "ci_success_rate",
      review_status: :not_required,
      human_decision: :none
    )
  end
  let(:artifact) do
    LedgerV2::Artifact.create!(
      artifact_type: "ci_fix_suggestion",
      title: "CI 修正案",
      body: "rubocop を確認する",
      format: "markdown",
      review_status: :accepted,
      run: run,
      related_ticket: ticket
    )
  end

  before do
    allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_pr).and_return(true)
  end

  it "accepted ci_fix_suggestion から draft PR を作成する" do
    allow(GithubPrService).to receive(:create_pr).and_return({ "number" => 123, "html_url" => "https://example.com/pr/123" })

    result = described_class.call(artifact: artifact)

    expect(result.created?).to be true
    expect(result.pr_number).to eq(123)
    expect(GithubPrService).to have_received(:create_pr).with(
      title: "ledger-v2: CI 修正案 Artifact ##{artifact.id}",
      body: include("draft PR のみ作成"),
      branch_prefix: "copilot/ledger-v2-ci-fix-#{artifact.id}",
      draft: true,
      path_prefix: "docs/ledger_v2_draft_prs"
    )
  end

  it "作成結果を Artifact metadata_json に保存する" do
    allow(GithubPrService).to receive(:create_pr).and_return({ "number" => 123, "html_url" => "https://example.com/pr/123" })

    described_class.call(artifact: artifact)

    expect(artifact.reload.metadata_json.dig("draft_pr", "number")).to eq(123)
    expect(artifact.metadata_json.dig("draft_pr", "url")).to eq("https://example.com/pr/123")
    expect(artifact.metadata_json.dig("draft_pr", "ci_status")).to eq("pending")
    expect(artifact.metadata_json.dig("draft_pr", "ci_decision")).to eq("continue")
    expect(artifact.metadata_json.dig("draft_pr", "ci_retry_count")).to eq(0)
    expect(artifact.metadata_json.dig("draft_pr", "ci_terminal")).to be false
    expect(artifact.metadata_json.dig("draft_pr", "ci_terminal_reason")).to be_nil
  end

  it "draft_pr_created Event を記録する" do
    allow(GithubPrService).to receive(:create_pr).and_return({ "number" => 123, "html_url" => "https://example.com/pr/123" })

    expect {
      described_class.call(artifact: artifact)
    }.to change {
      LedgerV2::Event.where(event_type: "draft_pr_created").count
    }.by(1)
  end

  it "同じ Artifact では PR を二重作成しない" do
    artifact.update!(metadata_json: { "draft_pr" => { "number" => 123 } })
    allow(GithubPrService).to receive(:create_pr)

    result = described_class.call(artifact: artifact)

    expect(result.skipped?).to be true
    expect(GithubPrService).not_to have_received(:create_pr)
  end

  it "ci_fix_suggestion 以外は対象外にする" do
    artifact.update!(artifact_type: "weekly_review")
    allow(GithubPrService).to receive(:create_pr)

    result = described_class.call(artifact: artifact)

    expect(result.skipped?).to be true
    expect(GithubPrService).not_to have_received(:create_pr)
  end

  it "accepted 以外は対象外にする" do
    artifact.update!(review_status: :pending)
    allow(GithubPrService).to receive(:create_pr)

    result = described_class.call(artifact: artifact)

    expect(result.skipped?).to be true
    expect(GithubPrService).not_to have_received(:create_pr)
  end

  it "GitHub PR 作成失敗時は failure Event を記録する" do
    allow(GithubPrService).to receive(:create_pr).and_return(nil)

    expect {
      described_class.call(artifact: artifact)
    }.to change {
      LedgerV2::Event.where(event_type: "draft_pr_create_failed").count
    }.by(1)
  end

  it "GitHub PR 作成失敗時は metadata_json に失敗理由を保存する" do
    allow(GithubPrService).to receive(:create_pr).and_return(nil)

    described_class.call(artifact: artifact)

    expect(artifact.reload.metadata_json.dig("draft_pr", "create_status")).to eq("failed")
    expect(artifact.metadata_json.dig("draft_pr", "creation_error")).to eq("GitHub PR creation failed")
  end
end
