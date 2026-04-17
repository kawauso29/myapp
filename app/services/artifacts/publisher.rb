module Artifacts
  # Phase 31 / §16: 成果物 6 種類を台帳に書き込むためのサービス層。
  #
  # 使い方:
  #   Artifacts::Publisher.publish(
  #     artifact_type: :kpi_definition,
  #     title: "AI SNS KPI 定義書",
  #     scope_level: :service,
  #     service_id: "ai_sns",
  #     content: { kpis: [...] },
  #     source_ticket: ticket,
  #     author: "business_owner"
  #   )
  #
  # 既存版（`artifact_type + title` で一意）がある場合は自動的に `supersedes` チェーンに連結し、
  # 古い版は `status: :superseded` に変える。
  class Publisher
    Result = Struct.new(:artifact, :previous, :superseded?, keyword_init: true)

    def self.publish(**args)
      new(**args).call
    end

    def initialize(artifact_type:, title:, scope_level:, content:, service_id: nil,
                   source_meeting: nil, source_ticket: nil, author: nil, idempotency_key: nil)
      @artifact_type = artifact_type
      @title = title
      @scope_level = scope_level
      @service_id = service_id
      @content = content || {}
      @source_meeting = source_meeting
      @source_ticket = source_ticket
      @author = author
      @idempotency_key = idempotency_key
    end

    def call
      ArtifactLedger.transaction do
        previous = ArtifactLedger
                     .where(artifact_type: @artifact_type, title: @title)
                     .order(artifact_version: :desc)
                     .first

        new_version = (previous&.artifact_version || 0) + 1

        artifact = ArtifactLedger.create!(
          artifact_type: @artifact_type,
          scope_level: @scope_level,
          service_id: @service_id,
          title: @title,
          artifact_version: new_version,
          content: @content,
          status: :published,
          published_at: Time.current,
          supersedes: previous,
          source_meeting: @source_meeting,
          source_ticket: @source_ticket,
          author: @author,
          idempotency_key: @idempotency_key
        )

        previous&.update!(status: :superseded) if previous && !previous.status_superseded?

        Result.new(artifact: artifact, previous: previous, superseded?: previous.present?)
      end
    end
  end
end
