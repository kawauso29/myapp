require "rails_helper"

RSpec.describe Ledgers::ServicePlanSeeder do
  let(:tmp_dir) { Rails.root.join("tmp", "spec_plan_seeder_#{SecureRandom.hex(4)}") }

  before { FileUtils.mkdir_p(tmp_dir) }
  after  { FileUtils.rm_rf(tmp_dir) }

  def write(filename, content)
    File.write(tmp_dir.join(filename), content)
  end

  it "loads all yaml files and upserts items per service_id" do
    write("ai_sns.yml", <<~YAML)
      service_id: ai_sns
      items:
        - item_key: S1
          title: "AI SNS 施策 S1"
          priority: high
          category: engagement
          kpi_hypothesis: "DAU +3%"
        - item_key: S2
          title: "AI SNS 施策 S2"
          priority: medium
    YAML
    write("voice_app.yml", <<~YAML)
      service_id: voice_app
      items:
        - item_key: V1
          title: "音声入力対応"
          priority: low
    YAML

    result = described_class.call(plans_dir: tmp_dir)

    expect(result.loaded).to eq(2)
    expect(result.upserted).to eq(3)

    s1 = TicketLedger.find_by(idempotency_key: "ai_sns_plan:S1")
    expect(s1.title).to eq("AI SNS 施策 S1")
    expect(s1.service_id).to eq("ai_sns")
    expect(s1).to be_priority_high
    expect(s1.improvement_pattern_key).to eq("engagement")

    v1 = TicketLedger.find_by(idempotency_key: "voice_app_plan:V1")
    expect(v1).to be_present
    expect(v1.service_id).to eq("voice_app")
    expect(v1).to be_priority_low
  end

  it "is idempotent on repeated runs" do
    write("ai_sns.yml", <<~YAML)
      service_id: ai_sns
      items:
        - item_key: I1
          title: "idempotent"
          priority: medium
    YAML

    described_class.call(plans_dir: tmp_dir)
    described_class.call(plans_dir: tmp_dir)

    expect(TicketLedger.where(idempotency_key: "ai_sns_plan:I1").count).to eq(1)
  end

  it "tolerates empty items list" do
    write("ai_sns.yml", "service_id: ai_sns\nitems: []\n")
    expect { described_class.call(plans_dir: tmp_dir) }.not_to raise_error
  end

  it "raises when service_id is missing" do
    write("broken.yml", "items: []\n")
    expect { described_class.call(plans_dir: tmp_dir) }.to raise_error(ArgumentError, /service_id/)
  end

  it "raises when item_key or title is missing" do
    write("ai_sns.yml", <<~YAML)
      service_id: ai_sns
      items:
        - title: "no key"
          priority: low
    YAML
    expect { described_class.call(plans_dir: tmp_dir) }.to raise_error(ArgumentError, /item_key/)
  end
end
