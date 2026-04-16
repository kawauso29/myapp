require "net/http"
require "json"

module Ledgers
  class TicketLedgerGithubIssueSyncer
    GITHUB_API_BASE = "https://api.github.com".freeze
    DEFAULT_REPO = "kawauso29/myapp".freeze
    DEFAULT_DRY_RUN = true
    TOKEN_ENV_KEYS = %w[GOVERNANCE_GITHUB_TOKEN GITHUB_TOKEN].freeze

    def self.call(scope: TicketLedger.all, dry_run: nil, repo: nil)
      new(scope:, dry_run:, repo:).call
    end

    def initialize(scope:, dry_run:, repo:)
      @scope = scope
      @repo = repo.presence || ENV.fetch("GOVERNANCE_GITHUB_REPO", DEFAULT_REPO)
      @dry_run = dry_run.nil? ? default_dry_run : dry_run
      @token = TOKEN_ENV_KEYS.lazy.map { |key| ENV[key].presence }.find(&:present?)
    end

    def call
      summary = {
        operation: "sync_github_issues",
        dry_run:,
        repo:,
        scanned: 0,
        eligible: 0,
        created: 0,
        updated: 0,
        skipped: 0,
        failed: 0,
        details: []
      }

      scope.find_each do |ticket|
        summary[:scanned] += 1

        unless ticket.github_issue_sync_eligible?
          summary[:skipped] += 1
          summary[:details] << detail_payload(ticket:, action: "skip_ineligible")
          next
        end

        summary[:eligible] += 1
        detail = sync_ticket(ticket)
        summary[:details] << detail

        case detail[:action]
        when "create", "create_dry_run"
          summary[:created] += 1
        when "update", "update_dry_run"
          summary[:updated] += 1
        when "skip_missing_token"
          summary[:skipped] += 1
        when "error"
          summary[:failed] += 1
        end
      end

      summary
    end

    private

    attr_reader :scope, :repo, :dry_run, :token

    def default_dry_run
      value = ENV.fetch("GOVERNANCE_GITHUB_SYNC_DRY_RUN", DEFAULT_DRY_RUN.to_s)
      ActiveModel::Type::Boolean.new.cast(value)
    end

    def sync_ticket(ticket)
      action = ticket.github_issue_number.present? ? "update" : "create"
      payload = issue_payload_for(ticket)

      if dry_run
        return detail_payload(ticket:, action: "#{action}_dry_run", issue_title: payload[:title])
      end

      unless token.present?
        message = "missing GitHub token (GOVERNANCE_GITHUB_TOKEN or GITHUB_TOKEN)"
        persist_sync_state(ticket:, status: "error", error_message: message)
        return detail_payload(ticket:, action: "skip_missing_token", error: message)
      end

      response = action == "update" ? update_issue(ticket:, payload:) : create_issue(payload:)
      persist_linkage!(ticket:, response:)
      detail_payload(
        ticket:,
        action:,
        issue_number: response.fetch("number"),
        issue_url: response.fetch("html_url"),
        issue_title: payload[:title]
      )
    rescue StandardError => e
      persist_sync_state(ticket:, status: "error", error_message: "#{e.class}: #{e.message}")
      detail_payload(ticket:, action: "error", error: "#{e.class}: #{e.message}")
    end

    def create_issue(payload:)
      request_json(
        method: :post,
        path: "/repos/#{repo}/issues",
        payload:
      )
    end

    def update_issue(ticket:, payload:)
      request_json(
        method: :patch,
        path: "/repos/#{repo}/issues/#{ticket.github_issue_number}",
        payload:
      )
    end

    def request_json(method:, path:, payload:)
      uri = URI("#{GITHUB_API_BASE}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 20

      req_class = {
        post: Net::HTTP::Post,
        patch: Net::HTTP::Patch
      }.fetch(method) { |unsupported_method| raise ArgumentError, "Unsupported HTTP method: #{unsupported_method}" }

      request = req_class.new(uri.request_uri)
      request["Authorization"] = "Bearer #{token}"
      request["Accept"] = "application/vnd.github+json"
      request["X-GitHub-Api-Version"] = "2022-11-28"
      request["Content-Type"] = "application/json"
      request.body = payload.to_json

      response = http.request(request)
      parsed = JSON.parse(response.body.presence || "{}")
      return parsed if response.code.to_i.between?(200, 299)

      error_message = parsed["message"].presence || response.body
      raise "GitHub API error (#{response.code}): #{error_message}"
    end

    def issue_payload_for(ticket)
      {
        title: issue_title_for(ticket),
        body: issue_body_for(ticket)
      }
    end

    def issue_title_for(ticket)
      "[#{ticket.service_id.presence || "company"}] #{ticket.ticket_type}: #{ticket.title}"
    end

    def issue_body_for(ticket)
      <<~BODY
        ## Human Notes
        - Add implementation notes, progress, and discussion here.

        ## Ledger Metadata (DO NOT EDIT)
        <!-- governance-ledger-ticket:begin -->
        - ticket_ledger_id: #{ticket.id}
        - github_repo: #{repo}
        - ticket_type: #{ticket.ticket_type}
        - status: #{ticket.status}
        - scope_level: #{ticket.scope_level}
        - service_id: #{ticket.service_id.presence || "N/A"}
        - priority: #{ticket.priority}
        - assignee: #{ticket.assignee.presence || "N/A"}
        - due_date: #{ticket.due_date&.iso8601 || "N/A"}
        - source_meeting_type: #{ticket.source_meeting_type.presence || "N/A"}
        - linked_kpis_json: #{ticket.linked_kpis.to_json}
        - linked_artifacts_json: #{ticket.linked_artifacts.to_json}
        <!-- governance-ledger-ticket:end -->
      BODY
    end

    def persist_linkage!(ticket:, response:)
      ticket.update!(
        github_repo: repo,
        github_issue_number: response.fetch("number"),
        github_issue_url: response.fetch("html_url"),
        github_issue_synced_at: Time.current,
        github_issue_sync_status: "synced",
        github_issue_sync_error: nil
      )
    end

    def persist_sync_state(ticket:, status:, error_message:)
      return if dry_run

      ticket.update(
        github_repo: repo,
        github_issue_synced_at: Time.current,
        github_issue_sync_status: status,
        github_issue_sync_error: error_message
      )
    end

    def detail_payload(ticket:, action:, issue_number: nil, issue_url: nil, issue_title: nil, error: nil)
      {
        ticket_id: ticket.id,
        action:,
        issue_number: issue_number || ticket.github_issue_number,
        issue_url: issue_url || ticket.github_issue_url,
        issue_title:,
        error:
      }.compact
    end
  end
end
