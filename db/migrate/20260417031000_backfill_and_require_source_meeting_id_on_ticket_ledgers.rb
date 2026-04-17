class BackfillAndRequireSourceMeetingIdOnTicketLedgers < ActiveRecord::Migration[8.1]
  # Phase 30c / 補強3: `ticket_ledgers.source_meeting_id` を NOT NULL にする。
  # バックフィル戦略:
  #   1. MeetingDefinition(meeting_key: "system_auto_improvement") を取得または新規作成
  #   2. 「legacy_backfill」idempotency_key を持つ MeetingLedger を 1 件作成
  #   3. source_meeting_id が NULL の既存 ticket_ledger を全部その会議に紐付ける
  #   4. NOT NULL 制約を付与
  def up
    say_with_time "backfilling source_meeting_id on ticket_ledgers" do
      backfill_null_source_meetings!
    end
    change_column_null :ticket_ledgers, :source_meeting_id, false
  end

  def down
    change_column_null :ticket_ledgers, :source_meeting_id, true
  end

  private

  def backfill_null_source_meetings!
    null_count = execute_count("SELECT COUNT(*) FROM ticket_ledgers WHERE source_meeting_id IS NULL")
    return if null_count.zero?

    definition_id = find_or_create_system_definition!
    meeting_id = find_or_create_legacy_meeting!(definition_id)

    execute <<~SQL.squish
      UPDATE ticket_ledgers
      SET source_meeting_id = #{meeting_id.to_i}
      WHERE source_meeting_id IS NULL
    SQL
  end

  def execute_count(sql)
    result = ActiveRecord::Base.connection.select_value(sql)
    result.to_i
  end

  def find_or_create_system_definition!
    existing = ActiveRecord::Base.connection.select_value(
      "SELECT id FROM meeting_definitions WHERE meeting_key = 'system_auto_improvement' LIMIT 1"
    )
    return existing if existing

    now = ActiveRecord::Base.connection.quote(Time.current)
    ActiveRecord::Base.connection.select_value(<<~SQL.squish)
      INSERT INTO meeting_definitions
        (meeting_key, meeting_type, scope_level, chair_role, participant_roles,
         active, allowed_cycles, writes_ledgers, created_at, updated_at)
      VALUES
        ('system_auto_improvement', 3, 0, 'system',
         '["system"]'::jsonb, TRUE, '[]'::jsonb,
         '["meeting_ledger","ticket_ledger"]'::jsonb, #{now}, #{now})
      RETURNING id
    SQL
  end

  def find_or_create_legacy_meeting!(definition_id)
    existing = ActiveRecord::Base.connection.select_value(
      "SELECT id FROM meeting_ledgers WHERE idempotency_key = 'system:legacy_backfill' LIMIT 1"
    )
    return existing if existing

    now = ActiveRecord::Base.connection.quote(Time.current)
    ActiveRecord::Base.connection.select_value(<<~SQL.squish)
      INSERT INTO meeting_ledgers
        (meeting_definition_id, meeting_key, meeting_type, scope_level,
         chair, participants, role_fill_rate, held_at, status,
         idempotency_key, created_at, updated_at)
      VALUES
        (#{definition_id.to_i}, 'system_auto_improvement', 3, 0,
         'system', '["system"]'::jsonb, 1.0, #{now}, 1,
         'system:legacy_backfill', #{now}, #{now})
      RETURNING id
    SQL
  end
end
