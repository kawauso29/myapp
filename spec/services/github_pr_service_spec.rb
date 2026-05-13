require "rails_helper"

RSpec.describe GithubPrService do
  describe ".fetch_ci_status" do
    around do |example|
      original = ENV["DEPLOY_TOKEN"]
      ENV["DEPLOY_TOKEN"] = "token"
      example.run
      ENV["DEPLOY_TOKEN"] = original
    end

    it "PR と check runs から success を集計する" do
      pr_response = double(body: {
        "html_url" => "https://example.com/pr/123",
        "state" => "open",
        "draft" => true,
        "head" => { "sha" => "abc123" }
      }.to_json)
      check_runs_response = double(body: {
        "check_runs" => [
          { "name" => "test", "status" => "completed", "conclusion" => "success", "details_url" => "https://example.com/check/1" }
        ]
      }.to_json)
      statuses_response = double(body: {
        "state" => "success",
        "statuses" => []
      }.to_json)
      http = instance_double(Net::HTTP)
      [pr_response, check_runs_response, statuses_response].each do |response|
        allow(response).to receive(:is_a?) { |klass| klass == Net::HTTPOK }
      end

      allow(Net::HTTP).to receive(:new).with("api.github.com", 443).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(pr_response, check_runs_response, statuses_response)

      result = described_class.fetch_ci_status(pr_number: 123)

      expect(result["status"]).to eq("success")
      expect(result["failed_checks"]).to eq([])
      expect(result["head_sha"]).to eq("abc123")
    end

    it "失敗した check runs と commit status を failed_checks に集約する" do
      pr_response = double(body: {
        "html_url" => "https://example.com/pr/123",
        "state" => "open",
        "draft" => true,
        "head" => { "sha" => "def456" }
      }.to_json)
      check_runs_response = double(body: {
        "check_runs" => [
          { "name" => "test", "status" => "completed", "conclusion" => "failure", "details_url" => "https://example.com/check/1" }
        ]
      }.to_json)
      statuses_response = double(body: {
        "state" => "failure",
        "statuses" => [
          { "context" => "lint", "state" => "failure", "target_url" => "https://example.com/status/1" }
        ]
      }.to_json)
      http = instance_double(Net::HTTP)
      [pr_response, check_runs_response, statuses_response].each do |response|
        allow(response).to receive(:is_a?) { |klass| klass == Net::HTTPOK }
      end

      allow(Net::HTTP).to receive(:new).with("api.github.com", 443).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(pr_response, check_runs_response, statuses_response)

      result = described_class.fetch_ci_status(pr_number: 123)

      expect(result["status"]).to eq("failure")
      expect(result["failed_checks"]).to contain_exactly("test", "lint")
    end

    it "DEPLOY_TOKEN 未設定時は nil を返す" do
      original = ENV["DEPLOY_TOKEN"]
      ENV["DEPLOY_TOKEN"] = nil

      expect(described_class.fetch_ci_status(pr_number: 123)).to be_nil

      ENV["DEPLOY_TOKEN"] = original
    end
  end
end
