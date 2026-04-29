module AdminLedgerV2Helper
  # Run status に応じたインラインスタイルを返す。
  def run_status_style(status)
    case status.to_s
    when "success"  then "color:#68d391; font-weight:600;"
    when "failed"   then "color:#fc8181; font-weight:600;"
    when "blocked"  then "color:#f6ad55; font-weight:600;"
    when "skipped"  then "color:#718096;"
    when "running"  then "color:#63b3ed; font-weight:600;"
    else "color:#a0aec0;"
    end
  end

  # Ticket severity に応じたインラインスタイルを返す。
  def ticket_severity_style(severity)
    case severity.to_s
    when "critical" then "color:#fc8181; font-weight:700;"
    when "high"     then "color:#f6ad55; font-weight:600;"
    when "medium"   then "color:#e2e8f0;"
    when "low"      then "color:#718096;"
    else "color:#a0aec0;"
    end
  end

  # Artifact review_status に応じたインラインスタイルを返す。
  def artifact_review_status_style(status)
    case status.to_s
    when "published"       then "color:#68d391; font-weight:600;"
    when "accepted"        then "color:#48bb78;"
    when "pending"         then "color:#63b3ed;"
    when "draft"           then "color:#718096;"
    when "review_rejected" then "color:#fc8181; font-weight:600;"
    when "review_deferred" then "color:#f6ad55;"
    when "needs_more_info" then "color:#ed8936;"
    else "color:#a0aec0;"
    end
  end
end
