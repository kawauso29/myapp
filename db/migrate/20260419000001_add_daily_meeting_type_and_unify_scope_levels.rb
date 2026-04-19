# frozen_string_literal: true

# 設計書 §12.6 選択肢A: meeting_type に :daily を追加。
# 設計書 §4: scope_level を全台帳で 4 値（company/portfolio/service/cross_service）に統一。
#
# - MeetingLedger / MeetingDefinition: enum に daily: 8 を追加（コード側のみ。DB は integer なので migration 不要）。
# - TicketLedger.source_meeting_type: enum に daily: 6 を追加（コード側のみ）。
# - CostLedger: scope_level short_term(3) → cross_service(3) にラベル変更（DB 値は変えない。コード側のみ）。
# - RolePermission: scope short_term(3) → cross_service(3) にラベル変更（DB 値は変えない。コード側のみ）。
# - TicketLedger / ComplianceRule: scope_level に cross_service: 3 を追加（コード側のみ）。
#
# DB integer 値はそのまま（short_term = 3 = cross_service として再ラベル）なので、
# この migration はデータ移行なし。schema.rb の version 更新のみが目的。
class AddDailyMeetingTypeAndUnifyScopeLevels < ActiveRecord::Migration[8.1]
  def up
    # No DDL changes needed — all modifications are enum label changes in Ruby code.
    # This migration exists to bump schema version so CI doesn't flag PendingMigrationError.
  end

  def down
    # No-op
  end
end
