require "rails_helper"

RSpec.describe Ledgers::JobIdempotency do
  let(:dummy_class) do
    klass = Class.new do
      include Ledgers::JobIdempotency
      def self.name
        "DummyIdempotentJob"
      end
    end
    klass
  end

  before do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  after do
    Rails.cache = @original_cache
  end

  describe ".with_job_idempotency" do
    it "executes the block on first call and returns its value" do
      result = dummy_class.with_job_idempotency("k1") { :ok }

      expect(result).to eq(:ok)
    end

    it "skips the block when called again within TTL with the same key" do
      called = 0
      dummy_class.with_job_idempotency("k2") { called += 1 }
      second = dummy_class.with_job_idempotency("k2") { called += 1 }

      expect(called).to eq(1)
      expect(second).to be_nil
    end

    it "allows re-execution on a different key" do
      called = 0
      dummy_class.with_job_idempotency("k3a") { called += 1 }
      dummy_class.with_job_idempotency("k3b") { called += 1 }

      expect(called).to eq(2)
    end

    it "releases the lock when the block raises so the next attempt can retry" do
      attempts = 0
      expect do
        dummy_class.with_job_idempotency("k4") do
          attempts += 1
          raise "boom"
        end
      end.to raise_error("boom")

      dummy_class.with_job_idempotency("k4") { attempts += 1 }

      expect(attempts).to eq(2)
    end
  end
end
