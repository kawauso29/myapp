#!/usr/bin/env bash
# myapp 剪定スクリプト: Linestamp + Picro 以外の AI SNS / Ledger / LedgerV2 / Trading を削除
#
# 使い方:
#   1. リポジトリのルートに置く
#   2. bash prune_myapp.sh
#   3. git status で確認 → コミット
#
# 注意:
#   - git rm を使うので diff として記録される（git 履歴には残る）
#   - --ignore-unmatch なので、既に消えているファイルがあってもエラーにならない
#   - schema.rb / routes.rb は既に整理済み前提（migration を整合させるだけ）

set -euo pipefail

echo "==[ 1/12] guide/ を削除（AI SNS 仕様書）"
git rm -rf --ignore-unmatch guide

echo "==[ 2/12] admin controllers（AI SNS / Ledger / LedgerV2）"
git rm -rf --ignore-unmatch \
  app/controllers/admin/ai_sns_controller.rb \
  app/controllers/admin/users_controller.rb \
  app/controllers/admin/dev_initiatives_controller.rb \
  app/controllers/admin/ops \
  app/controllers/admin/ledger_v2

echo "==[ 3/12] API v1（linestamp 以外を全削除）"
for d in app/controllers/api/v1/*; do
  [[ "$(basename "$d")" == "linestamp" ]] && continue
  git rm -rf --ignore-unmatch "$d"
done

echo "==[ 4/12] channels / concerns / serializers / helpers"
git rm -rf --ignore-unmatch \
  app/channels/global_timeline_channel.rb \
  app/channels/post_thread_channel.rb \
  app/channels/user_notification_channel.rb \
  app/models/concerns/age_progression.rb \
  app/models/concerns/relationship_score_calculator.rb \
  app/serializers \
  app/helpers/admin_ledger_v2_helper.rb \
  app/helpers/admin_ops_ledgers_helper.rb

echo "==[ 5/12] models（AI SNS + Ledger 系）"
git rm -rf --ignore-unmatch \
  app/models/ai_*.rb \
  app/models/ledger_v2.rb \
  app/models/ledger_v2 \
  app/models/artifact_ledger.rb \
  app/models/audit_decision_ledger.rb \
  app/models/cost_ledger.rb \
  app/models/customer_feedback_ledger.rb \
  app/models/experiment_ledger.rb \
  app/models/hr_evaluation_ledger.rb \
  app/models/knowledge_ledger.rb \
  app/models/kpi_ledger.rb \
  app/models/meeting_ledger.rb \
  app/models/operator_override_ledger.rb \
  app/models/org_change_ledger.rb \
  app/models/portfolio_strategy_ledger.rb \
  app/models/service_ledger.rb \
  app/models/stop_ledger.rb \
  app/models/ticket_ledger.rb \
  app/models/user_notification.rb \
  app/models/user_favorite_ai.rb \
  app/models/user_ai_like.rb \
  app/models/user_community_follow.rb \
  app/models/post_interest_tag.rb \
  app/models/post_report.rb \
  app/models/interest_tag.rb \
  app/models/kpi_snapshot.rb \
  app/models/dev_initiative.rb \
  app/models/service_heartbeat.rb \
  app/models/service_schedule_definition.rb \
  app/models/service_time_axis_setting.rb \
  app/models/organization_role.rb \
  app/models/role_permission.rb \
  app/models/compliance_rule.rb \
  app/models/lane_capacity_cap.rb \
  app/models/meeting_definition.rb

echo "==[ 6/12] jobs（linestamp + picro_check + slack_forward は残す）"
git rm -rf --ignore-unmatch \
  app/jobs/ai_action_check_job.rb \
  app/jobs/annual_plan_ledger_run_job.rb \
  app/jobs/avatar_update_job.rb \
  app/jobs/birthday_check_job.rb \
  app/jobs/community_detect_job.rb \
  app/jobs/daily_ledger_run_job.rb \
  app/jobs/daily_memory_summarize_job.rb \
  app/jobs/daily_schedule_generate_job.rb \
  app/jobs/daily_state_generate_job.rb \
  app/jobs/dm_check_job.rb \
  app/jobs/dm_generate_job.rb \
  app/jobs/dynamic_params_update_job.rb \
  app/jobs/hourly_state_update_job.rb \
  app/jobs/hr_evaluation_run_job.rb \
  app/jobs/kpi_auto_collect_job.rb \
  app/jobs/kpi_grade_evaluate_job.rb \
  app/jobs/life_event_chain_job.rb \
  app/jobs/life_event_check_job.rb \
  app/jobs/life_story_generate_job.rb \
  app/jobs/milestone_check_job.rb \
  app/jobs/monitor_failed_jobs_job.rb \
  app/jobs/monthly_ops_ledger_run_job.rb \
  app/jobs/owner_score_update_job.rb \
  app/jobs/post_generate_job.rb \
  app/jobs/post_motivation_calculate_job.rb \
  app/jobs/quarterly_review_ledger_run_job.rb \
  app/jobs/relationship_decay_job.rb \
  app/jobs/relationship_memory_update_job.rb \
  app/jobs/reply_generate_job.rb \
  app/jobs/ticket_overdue_check_job.rb \
  app/jobs/ui_check_ledger_run_job.rb \
  app/jobs/weekly_dept_ledger_run_job.rb \
  app/jobs/ledger_v2

echo "==[ 7/12] services（AI SNS / Ledger 系）"
git rm -rf --ignore-unmatch \
  app/services/ai_action \
  app/services/ai_creation \
  app/services/daily \
  app/services/events \
  app/services/ledger_v2 \
  app/services/ledgers \
  app/services/moderation \
  app/services/notification \
  app/services/github_mapping \
  app/services/notification_service.rb \
  app/services/admin/ai_sns_plan_service.rb

echo "==[ 8/12] admin views（AI SNS / Ledger / LedgerV2 / dev_initiatives / users）"
git rm -rf --ignore-unmatch \
  app/views/admin/ai_sns \
  app/views/admin/ops \
  app/views/admin/ledger_v2 \
  app/views/admin/dev_initiatives \
  app/views/admin/users

echo "==[ 9/12] initializers / config yaml"
git rm -rf --ignore-unmatch \
  config/initializers/ledger_v2.rb \
  config/initializers/stripe.rb \
  config/initializers/active_job_unknown_class_retry.rb \
  config/initializers/solid_queue_boot_cleanup.rb \
  config/events.yml \
  config/ng_words.yml

echo "==[10/12] db/migrate（20260525020449 以降と picro/users/jwt 以外を削除）"
KEEP=(
  "20260317000001_create_picro_messages.rb"
  "20260401000001_create_users.rb"
  "20260401000023_create_jwt_denylists.rb"
)
for f in db/migrate/*.rb; do
  name=$(basename "$f")
  ts="${name%%_*}"
  # 20260525020449 以降（linestamp + active_storage）は全部残す
  if [[ "$ts" -ge 20260525020449 ]]; then
    continue
  fi
  # それ以前は KEEP リストのみ残す
  keep=0
  for k in "${KEEP[@]}"; do
    [[ "$name" == "$k" ]] && keep=1 && break
  done
  [[ $keep -eq 0 ]] && git rm -f --ignore-unmatch "$f"
done

echo "==[11/12] db extras / docs / .github"
git rm -rf --ignore-unmatch \
  db/snapshots/db_snapshot.json \
  db/seeds/seed_ai_data.rb \
  db/seeds/plans \
  docs/architecture.md \
  docs/ai_sns_improvement_plan.md \
  docs/projects/ledger-v2-migration.md \
  docs/projects/operating-spec-phase-30-plan.md \
  docs/ops \
  .github/ISSUE_TEMPLATE/ai_sns_feature_request.yml

echo "==[12/12] specs / factories"
git rm -rf --ignore-unmatch \
  spec/features/ledger_v2 \
  spec/jobs/ledger_v2 \
  spec/models/ledger_v2 \
  spec/requests/admin/ledger_v2 \
  spec/requests/admin/ops \
  spec/services/daily \
  spec/services/events \
  spec/services/ledger_v2 \
  spec/services/ledgers \
  spec/services/ai_action \
  spec/services/ai_creation \
  spec/services/notification \
  spec/services/moderation \
  spec/services/github_mapping \
  spec/factories/ai_avatar_states.rb \
  spec/factories/ai_daily_states.rb \
  spec/factories/ai_dynamic_params.rb \
  spec/factories/ai_personalities.rb \
  spec/factories/ai_posts.rb \
  spec/factories/ai_profiles.rb \
  spec/factories/ai_relationships.rb \
  spec/factories/ai_story_reactions.rb \
  spec/factories/ai_users.rb \
  spec/factories/artifact_ledgers.rb \
  spec/factories/compliance_rules.rb \
  spec/factories/experiment_ledgers.rb \
  spec/factories/kpi_ledgers.rb \
  spec/factories/kpi_snapshots.rb \
  spec/factories/meeting_definitions.rb \
  spec/factories/meeting_ledgers.rb \
  spec/factories/phase_32_to_41_ledgers.rb \
  spec/factories/post_reports.rb \
  spec/factories/role_permissions.rb \
  spec/factories/service_heartbeats.rb \
  spec/factories/service_ledgers.rb \
  spec/factories/ticket_ledgers.rb \
  spec/jobs/milestone_check_job_spec.rb \
  spec/jobs/post_generate_job_spec.rb \
  spec/models/ai_personality_spec.rb \
  spec/models/ai_post_spec.rb \
  spec/models/ai_relationship_spec.rb \
  spec/models/ai_story_reaction_spec.rb \
  spec/models/artifact_ledger_self_reference_spec.rb \
  spec/models/artifact_ledger_spec.rb \
  spec/models/audit_decision_ledger_spec.rb \
  spec/models/cost_ledger_spec.rb \
  spec/models/experiment_ledger_spec.rb \
  spec/models/kpi_ledger_spec.rb \
  spec/models/kpi_ledger_target_value_spec.rb \
  spec/models/meeting_ledger_spec.rb \
  spec/models/operator_override_ledger_spec.rb \
  spec/models/service_ledger_spec.rb \
  spec/models/stop_ledger_spec.rb \
  spec/models/ticket_ledger_spec.rb \
  spec/requests/admin/ai_sns_spec.rb \
  spec/requests/api/v1/ai_users_spec.rb \
  spec/requests/api/v1/auth_spec.rb \
  spec/requests/api/v1/communities_spec.rb \
  spec/requests/api/v1/favorites_spec.rb \
  spec/requests/api/v1/likes_spec.rb \
  spec/requests/api/v1/me_spec.rb \
  spec/requests/api/v1/posts_spec.rb \
  spec/requests/api/v1/stories_spec.rb \
  spec/requests/api/v1/webhooks_spec.rb

echo ""
echo "==[ 完了 ] 削除を反映しました。次のコマンドで確認とコミットを:"
echo ""
echo "  git status"
echo "  git diff --stat HEAD"
echo "  git commit -m 'Prune: remove AI SNS / Ledger / LedgerV2 / Trading subsystems'"
echo ""
