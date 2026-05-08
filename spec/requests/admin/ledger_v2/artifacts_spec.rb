require "rails_helper"

RSpec.describe "Admin::LedgerV2::Artifacts", type: :request do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return(nil)
  end

  def create_artifact(overrides = {})
    LedgerV2::Artifact.create!({
      artifact_type: "weekly_review",
      title:         "週次レビュー Artifact",
      format:        "markdown",
      review_status: :draft
    }.merge(overrides))
  end

  describe "GET /admin/ledger_v2/artifacts" do
    context "Artifact がない場合" do
      it "200 OK を返す" do
        get "/admin/ledger_v2/artifacts"

        expect(response).to have_http_status(:ok)
      end

      it "Artifact がない旨を表示する" do
        get "/admin/ledger_v2/artifacts"

        expect(response.body).to include("Artifact がありません")
      end
    end

    context "draft Artifact が存在する場合" do
      let!(:artifact) { create_artifact(title: "週次改善レポート", review_status: :draft) }

      it "Artifact のタイトルを表示する" do
        get "/admin/ledger_v2/artifacts"

        expect(response.body).to include("週次改善レポート")
      end

      it "artifact_type を表示する" do
        get "/admin/ledger_v2/artifacts"

        expect(response.body).to include("weekly_review")
      end

      it "Accept ボタンを表示する" do
        get "/admin/ledger_v2/artifacts"

        expect(response.body).to include("Accept")
      end

      it "Reject ボタンを表示する" do
        get "/admin/ledger_v2/artifacts"

        expect(response.body).to include("Reject")
      end

      it "Defer ボタンを表示する" do
        get "/admin/ledger_v2/artifacts"

        expect(response.body).to include("Defer")
      end
    end

    context "accepted Artifact が存在する場合" do
      let!(:artifact) { create_artifact(review_status: :accepted) }

      it "Publish ボタンを表示する" do
        get "/admin/ledger_v2/artifacts"

        expect(response.body).to include("Publish")
      end
    end

    context "review_rejected Artifact が存在する場合" do
      let!(:artifact) { create_artifact(review_status: :review_rejected) }

      it "Reopen ボタンを表示する" do
        get "/admin/ledger_v2/artifacts"

        expect(response.body).to include("Reopen")
      end
    end

    context "status フィルターを指定した場合" do
      let!(:draft_artifact)   { create_artifact(title: "下書き Artifact",   review_status: :draft) }
      let!(:pending_artifact) { create_artifact(title: "pending Artifact", review_status: :pending) }

      it "draft のみ表示される" do
        get "/admin/ledger_v2/artifacts", params: { status: "draft" }

        expect(response.body).to include("下書き Artifact")
        expect(response.body).not_to include("pending Artifact")
      end

      it "pending のみ表示される" do
        get "/admin/ledger_v2/artifacts", params: { status: "pending" }

        expect(response.body).to include("pending Artifact")
        expect(response.body).not_to include("下書き Artifact")
      end
    end

    context "artifact_type フィルターを指定した場合" do
      let!(:weekly_artifact) { create_artifact(title: "週次",   artifact_type: "weekly_review") }
      let!(:daily_artifact)  { create_artifact(title: "日次",   artifact_type: "daily_summary") }

      it "weekly_review のみ表示される" do
        get "/admin/ledger_v2/artifacts", params: { artifact_type: "weekly_review" }

        expect(response.body).to include("週次")
        expect(response.body).not_to include("日次")
      end
    end

    context "monthly_review フィルターを指定した場合" do
      let!(:monthly_artifact) { create_artifact(title: "月次レビュー", artifact_type: "monthly_review") }
      let!(:weekly_artifact)  { create_artifact(title: "週次レビュー", artifact_type: "weekly_review") }

      it "monthly_review のみ表示される" do
        get "/admin/ledger_v2/artifacts", params: { artifact_type: "monthly_review" }

        expect(response.body).to include("月次レビュー")
        expect(response.body).not_to include("週次レビュー")
      end

      it "フィルターの選択肢に monthly_review が含まれる" do
        get "/admin/ledger_v2/artifacts"

        expect(response.body).to include("monthly_review")
      end
    end
  end

  describe "GET /admin/ledger_v2/artifacts/:id" do
    let!(:artifact) do
      create_artifact(
        title:         "週次レビュー本文テスト",
        review_status: :pending,
        body:          "## 週次レビュー\n\nこれは本文のテストです。"
      )
    end

    it "200 OK を返す" do
      get "/admin/ledger_v2/artifacts/#{artifact.id}"

      expect(response).to have_http_status(:ok)
    end

    it "Artifact のタイトルを表示する" do
      get "/admin/ledger_v2/artifacts/#{artifact.id}"

      expect(response.body).to include("週次レビュー本文テスト")
    end

    it "Artifact の本文を表示する" do
      get "/admin/ledger_v2/artifacts/#{artifact.id}"

      expect(response.body).to include("週次レビュー\n\nこれは本文のテストです。")
    end

    it "pending 状態のとき Accept ボタンを表示する" do
      get "/admin/ledger_v2/artifacts/#{artifact.id}"

      expect(response.body).to include("Accept")
    end

    it "pending 状態のとき Defer ボタンを表示する" do
      get "/admin/ledger_v2/artifacts/#{artifact.id}"

      expect(response.body).to include("Defer")
    end

    it "pending 状態のとき Reject ボタンを表示する" do
      get "/admin/ledger_v2/artifacts/#{artifact.id}"

      expect(response.body).to include("Reject")
    end

    context "accepted 状態のとき" do
      let!(:artifact) { create_artifact(review_status: :accepted) }

      it "Publish ボタンを表示する" do
        get "/admin/ledger_v2/artifacts/#{artifact.id}"

        expect(response.body).to include("Publish")
      end
    end

    context "review_rejected 状態のとき" do
      let!(:artifact) { create_artifact(review_status: :review_rejected) }

      it "Reopen ボタンを表示する" do
        get "/admin/ledger_v2/artifacts/#{artifact.id}"

        expect(response.body).to include("Reopen")
      end
    end

    it "本文がない場合でも 200 OK を返す" do
      artifact.update!(body: nil)
      get "/admin/ledger_v2/artifacts/#{artifact.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("本文がありません")
    end
  end

  describe "PATCH /admin/ledger_v2/artifacts/:id" do
    context "accept アクション" do
      let!(:artifact) { create_artifact(review_status: :pending) }

      it "review_status が accepted になる" do
        patch "/admin/ledger_v2/artifacts/#{artifact.id}", params: { review_action: "accept" }

        expect(artifact.reload.review_status).to eq("accepted")
      end

      it "reviewed_by が admin になる" do
        patch "/admin/ledger_v2/artifacts/#{artifact.id}", params: { review_action: "accept" }

        expect(artifact.reload.reviewed_by).to eq("admin")
      end

      it "reviewed_at が設定される" do
        patch "/admin/ledger_v2/artifacts/#{artifact.id}", params: { review_action: "accept" }

        expect(artifact.reload.reviewed_at).not_to be_nil
      end

      it "Artifact 一覧にリダイレクトする" do
        patch "/admin/ledger_v2/artifacts/#{artifact.id}", params: { review_action: "accept" }

        expect(response).to redirect_to(admin_ledger_v2_artifacts_path)
      end

      it "draft PR 作成連動サービスを呼び出す" do
        allow(LedgerV2::CreateDraftPullRequest).to receive(:call).and_return(
          LedgerV2::CreateDraftPullRequest::Result.new(created?: false, skipped?: true, reason: "unsupported artifact_type")
        )

        patch "/admin/ledger_v2/artifacts/#{artifact.id}", params: { review_action: "accept" }

        expect(LedgerV2::CreateDraftPullRequest).to have_received(:call).with(artifact: artifact)
      end
    end

    context "reject アクション" do
      let!(:artifact) { create_artifact(review_status: :draft) }

      it "review_status が review_rejected になる" do
        patch "/admin/ledger_v2/artifacts/#{artifact.id}", params: { review_action: "reject" }

        expect(artifact.reload.review_status).to eq("review_rejected")
      end

      it "review_comment が保存される" do
        patch "/admin/ledger_v2/artifacts/#{artifact.id}", params: { review_action: "reject", review_comment: "品質不足" }

        expect(artifact.reload.review_comment).to eq("品質不足")
      end

      it "reviewed_by が admin になる" do
        patch "/admin/ledger_v2/artifacts/#{artifact.id}", params: { review_action: "reject" }

        expect(artifact.reload.reviewed_by).to eq("admin")
      end
    end

    context "defer アクション" do
      let!(:artifact) { create_artifact(review_status: :pending) }

      it "review_status が review_deferred になる" do
        patch "/admin/ledger_v2/artifacts/#{artifact.id}", params: { review_action: "defer" }

        expect(artifact.reload.review_status).to eq("review_deferred")
      end

      it "reviewed_by が admin になる" do
        patch "/admin/ledger_v2/artifacts/#{artifact.id}", params: { review_action: "defer" }

        expect(artifact.reload.reviewed_by).to eq("admin")
      end
    end

    context "publish アクション" do
      let!(:artifact) { create_artifact(review_status: :accepted) }

      it "review_status が published になる" do
        patch "/admin/ledger_v2/artifacts/#{artifact.id}", params: { review_action: "publish" }

        expect(artifact.reload.review_status).to eq("published")
      end

      it "published_at が設定される" do
        patch "/admin/ledger_v2/artifacts/#{artifact.id}", params: { review_action: "publish" }

        expect(artifact.reload.published_at).not_to be_nil
      end

      it "reviewed_by が admin になる" do
        patch "/admin/ledger_v2/artifacts/#{artifact.id}", params: { review_action: "publish" }

        expect(artifact.reload.reviewed_by).to eq("admin")
      end

      it "Artifact 一覧にリダイレクトする" do
        patch "/admin/ledger_v2/artifacts/#{artifact.id}", params: { review_action: "publish" }

        expect(response).to redirect_to(admin_ledger_v2_artifacts_path)
      end
    end

    context "reopen アクション" do
      let!(:artifact) { create_artifact(review_status: :review_rejected, reviewed_by: "admin", reviewed_at: Time.current) }

      it "review_status が pending になる" do
        patch "/admin/ledger_v2/artifacts/#{artifact.id}", params: { review_action: "reopen" }

        expect(artifact.reload.review_status).to eq("pending")
      end

      it "reviewed_by がクリアされる" do
        patch "/admin/ledger_v2/artifacts/#{artifact.id}", params: { review_action: "reopen" }

        expect(artifact.reload.reviewed_by).to be_nil
      end

      it "reviewed_at がクリアされる" do
        patch "/admin/ledger_v2/artifacts/#{artifact.id}", params: { review_action: "reopen" }

        expect(artifact.reload.reviewed_at).to be_nil
      end
    end

    context "不正な review_action" do
      let!(:artifact) { create_artifact }

      it "Artifact 一覧にリダイレクトする" do
        patch "/admin/ledger_v2/artifacts/#{artifact.id}", params: { review_action: "hack" }

        expect(response).to redirect_to(admin_ledger_v2_artifacts_path)
      end

      it "Artifact の状態が変わらない" do
        original_status = artifact.review_status
        patch "/admin/ledger_v2/artifacts/#{artifact.id}", params: { review_action: "hack" }

        expect(artifact.reload.review_status).to eq(original_status)
      end
    end
  end
end
