require "rails_helper"

RSpec.describe "Admin::LedgerV2::Tickets", type: :request do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return(nil)
  end

  def create_ticket(overrides = {})
    LedgerV2::Ticket.create!({
      canonical_key:  "test:metric:daily:#{SecureRandom.hex(4)}",
      title:          "テスト Ticket",
      status:         :open,
      severity:       :medium,
      review_status:  :not_required,
      human_decision: :none,
      metric_name:    "ai_sns_posts_count"
    }.merge(overrides))
  end

  describe "GET /admin/ledger_v2/tickets" do
    context "Ticket がない場合" do
      it "200 OK を返す" do
        get "/admin/ledger_v2/tickets"

        expect(response).to have_http_status(:ok)
      end

      it "Ticket がない旨を表示する" do
        get "/admin/ledger_v2/tickets"

        expect(response.body).to include("Ticket がありません")
      end
    end

    context "open Ticket が存在する場合" do
      let!(:ticket) { create_ticket(title: "投稿数異常検知", severity: :high) }

      it "Ticket のタイトルを表示する" do
        get "/admin/ledger_v2/tickets"

        expect(response.body).to include("投稿数異常検知")
      end

      it "severity を表示する" do
        get "/admin/ledger_v2/tickets"

        expect(response.body).to include("high")
      end

      it "Accept ボタンを表示する" do
        get "/admin/ledger_v2/tickets"

        expect(response.body).to include("Accept")
      end

      it "Reject ボタンを表示する" do
        get "/admin/ledger_v2/tickets"

        expect(response.body).to include("Reject")
      end
    end

    context "status フィルターを指定した場合" do
      let!(:open_ticket)     { create_ticket(title: "open チケット",     status: :open) }
      let!(:deferred_ticket) { create_ticket(title: "deferred チケット", status: :deferred) }

      it "open のみ表示される" do
        get "/admin/ledger_v2/tickets", params: { status: "open" }

        expect(response.body).to include("open チケット")
        expect(response.body).not_to include("deferred チケット")
      end

      it "deferred のみ表示される" do
        get "/admin/ledger_v2/tickets", params: { status: "deferred" }

        expect(response.body).to include("deferred チケット")
        expect(response.body).not_to include("open チケット")
      end
    end

    context "severity フィルターを指定した場合" do
      let!(:high_ticket)   { create_ticket(title: "高 severity", severity: :high) }
      let!(:low_ticket)    { create_ticket(title: "低 severity", severity: :low) }

      it "high のみ表示される" do
        get "/admin/ledger_v2/tickets", params: { severity: "high" }

        expect(response.body).to include("高 severity")
        expect(response.body).not_to include("低 severity")
      end
    end

    context "rejected Ticket が存在する場合" do
      let!(:rejected_ticket) { create_ticket(title: "却下済みチケット", status: :rejected) }

      it "Reopen ボタンを表示する" do
        get "/admin/ledger_v2/tickets"

        expect(response.body).to include("Reopen")
      end
    end
  end

  describe "PATCH /admin/ledger_v2/tickets/:id" do
    context "accept アクション" do
      let!(:ticket) { create_ticket(status: :open, review_status: :not_required, human_decision: :none) }

      it "human_decision が accepted になる" do
        patch "/admin/ledger_v2/tickets/#{ticket.id}", params: { review_action: "accept" }

        expect(ticket.reload.human_decision).to eq("accepted")
      end

      it "review_status が accepted になる" do
        patch "/admin/ledger_v2/tickets/#{ticket.id}", params: { review_action: "accept" }

        expect(ticket.reload.review_status).to eq("accepted")
      end

      it "Ticket 一覧にリダイレクトする" do
        patch "/admin/ledger_v2/tickets/#{ticket.id}", params: { review_action: "accept" }

        expect(response).to redirect_to(admin_ledger_v2_tickets_path)
      end
    end

    context "reject アクション" do
      let!(:ticket) { create_ticket(status: :open) }

      it "status が rejected になる" do
        patch "/admin/ledger_v2/tickets/#{ticket.id}", params: { review_action: "reject", rejected_reason: "ノイズ" }

        expect(ticket.reload.status).to eq("rejected")
      end

      it "human_decision が rejected になる" do
        patch "/admin/ledger_v2/tickets/#{ticket.id}", params: { review_action: "reject" }

        expect(ticket.reload.human_decision).to eq("rejected")
      end

      it "rejected_reason が保存される" do
        patch "/admin/ledger_v2/tickets/#{ticket.id}", params: { review_action: "reject", rejected_reason: "ノイズデータ" }

        expect(ticket.reload.rejected_reason).to eq("ノイズデータ")
      end

      it "review_status が review_rejected になる" do
        patch "/admin/ledger_v2/tickets/#{ticket.id}", params: { review_action: "reject" }

        expect(ticket.reload.review_status).to eq("review_rejected")
      end
    end

    context "defer アクション" do
      let!(:ticket) { create_ticket(status: :open) }

      it "status が deferred になる" do
        patch "/admin/ledger_v2/tickets/#{ticket.id}", params: { review_action: "defer" }

        expect(ticket.reload.status).to eq("deferred")
      end

      it "human_decision が deferred になる" do
        patch "/admin/ledger_v2/tickets/#{ticket.id}", params: { review_action: "defer" }

        expect(ticket.reload.human_decision).to eq("deferred")
      end

      it "review_status が review_deferred になる" do
        patch "/admin/ledger_v2/tickets/#{ticket.id}", params: { review_action: "defer" }

        expect(ticket.reload.review_status).to eq("review_deferred")
      end
    end

    context "reopen アクション" do
      let!(:ticket) { create_ticket(status: :rejected, human_decision: :rejected, review_status: :review_rejected) }

      it "status が open になる" do
        patch "/admin/ledger_v2/tickets/#{ticket.id}", params: { review_action: "reopen" }

        expect(ticket.reload.status).to eq("open")
      end

      it "human_decision が none になる" do
        patch "/admin/ledger_v2/tickets/#{ticket.id}", params: { review_action: "reopen" }

        expect(ticket.reload.human_decision).to eq("none")
      end

      it "review_status が pending になる" do
        patch "/admin/ledger_v2/tickets/#{ticket.id}", params: { review_action: "reopen" }

        expect(ticket.reload.review_status).to eq("pending")
      end
    end

    context "不正な review_action" do
      let!(:ticket) { create_ticket }

      it "Ticket 一覧にリダイレクトする" do
        patch "/admin/ledger_v2/tickets/#{ticket.id}", params: { review_action: "hack" }

        expect(response).to redirect_to(admin_ledger_v2_tickets_path)
      end

      it "Ticket の状態が変わらない" do
        original_status = ticket.status
        patch "/admin/ledger_v2/tickets/#{ticket.id}", params: { review_action: "hack" }

        expect(ticket.reload.status).to eq(original_status)
      end
    end
  end
end
