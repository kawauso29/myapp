require "rails_helper"

RSpec.describe LedgerV2::OpenTicket, type: :service do
  let(:run) { LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule) }

  def call_open_ticket(overrides = {})
    described_class.call(**{
      run:           run,
      canonical_key: "ai_sns:global:post_count:low:2026w18",
      title:         "投稿数が低下しています"
    }.merge(overrides))
  end

  describe ".call" do
    context "通常の Ticket 作成" do
      it "新規 Ticket が作成され created? true を返す" do
        result = call_open_ticket

        expect(result.created?).to be true
        expect(result.ticket).to be_a(LedgerV2::Ticket)
        expect(result.ticket).to be_persisted
      end

      it "Ticket の canonical_key と title が正しく保存される" do
        result = call_open_ticket(
          canonical_key: "ci:main:success_rate:low:2026w18",
          title:         "CI 成功率が低下"
        )

        expect(result.ticket.canonical_key).to eq("ci:main:success_rate:low:2026w18")
        expect(result.ticket.title).to eq("CI 成功率が低下")
      end

      it "opened_by_run に渡した run が関連付けられる" do
        result = call_open_ticket

        expect(result.ticket.opened_by_run).to eq(run)
      end

      it "ticket_opened Event が作成される" do
        expect {
          call_open_ticket
        }.to change { LedgerV2::Event.where(event_type: "ticket_opened").count }.by(1)
      end

      it "ticket_opened Event の payload_json に canonical_key が含まれる" do
        call_open_ticket(canonical_key: "ai_sns:global:post_count:low:2026w18")

        event = LedgerV2::Event.where(event_type: "ticket_opened").last
        expect(event.payload_json["canonical_key"]).to eq("ai_sns:global:post_count:low:2026w18")
      end

      it "severity を指定すると Ticket に反映される" do
        result = call_open_ticket(severity: :high)

        expect(result.ticket.severity_high?).to be true
      end

      it "duplicate_result.duplicate? は false になる" do
        result = call_open_ticket

        expect(result.duplicate_result.duplicate?).to be false
      end
    end

    context "重複 Ticket の抑止" do
      it "同じ canonical_key の active Ticket が存在する場合、新規 Ticket を作成しない" do
        LedgerV2::Ticket.create!(
          canonical_key: "ai_sns:global:post_count:low:2026w18",
          title:         "既存チケット"
        )

        expect {
          call_open_ticket
        }.not_to change(LedgerV2::Ticket, :count)
      end

      it "duplicate 時は created? false を返す" do
        LedgerV2::Ticket.create!(
          canonical_key: "ai_sns:global:post_count:low:2026w18",
          title:         "既存チケット"
        )

        result = call_open_ticket

        expect(result.created?).to be false
        expect(result.duplicate_result.duplicate?).to be true
      end

      it "duplicate 時に ticket_duplicate_prevented Event が作成される" do
        LedgerV2::Ticket.create!(
          canonical_key: "ai_sns:global:post_count:low:2026w18",
          title:         "既存チケット"
        )

        expect {
          call_open_ticket
        }.to change { LedgerV2::Event.where(event_type: "ticket_duplicate_prevented").count }.by(1)
      end

      it "duplicate 時に返す ticket は既存の Ticket" do
        existing = LedgerV2::Ticket.create!(
          canonical_key: "ai_sns:global:post_count:low:2026w18",
          title:         "既存チケット"
        )

        result = call_open_ticket

        expect(result.ticket.id).to eq(existing.id)
      end
    end

    context "resolved 後の再起票" do
      it "resolved Ticket がある場合は新規 Ticket を作成できる" do
        LedgerV2::Ticket.create!(
          canonical_key: "ai_sns:global:post_count:low:2026w18",
          title:         "解決済みチケット",
          status:        :resolved
        )

        result = call_open_ticket

        expect(result.created?).to be true
        expect(result.ticket).to be_persisted
      end
    end

    context "dry_run: true" do
      it "Ticket を作成しない" do
        expect {
          call_open_ticket(dry_run: true)
        }.not_to change(LedgerV2::Ticket, :count)
      end

      it "Event を作成しない" do
        expect {
          call_open_ticket(dry_run: true)
        }.not_to change(LedgerV2::Event, :count)
      end

      it "created? false を返す" do
        result = call_open_ticket(dry_run: true)

        expect(result.created?).to be false
        expect(result.ticket).to be_nil
      end

      it "duplicate でも Event を作成しない" do
        LedgerV2::Ticket.create!(
          canonical_key: "ai_sns:global:post_count:low:2026w18",
          title:         "既存チケット"
        )

        expect {
          call_open_ticket(dry_run: true)
        }.not_to change(LedgerV2::Event, :count)
      end
    end

    context "バリデーション" do
      it "canonical_key が空の場合は ArgumentError を raise する" do
        expect {
          described_class.call(run: run, canonical_key: "", title: "テスト")
        }.to raise_error(ArgumentError, /canonical_key/)
      end

      it "title が空の場合は ArgumentError を raise する" do
        expect {
          described_class.call(run: run, canonical_key: "some:key", title: "")
        }.to raise_error(ArgumentError, /title/)
      end
    end
  end

  describe "Result 値オブジェクト" do
    it "created? メソッドが存在する" do
      result = LedgerV2::OpenTicket::Result.new(ticket: nil, duplicate_result: nil, created: false)
      expect(result.created?).to be false
    end
  end
end
