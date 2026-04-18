class ConsolidateAiSnsUiIntoAiSns < ActiveRecord::Migration[8.1]
  def up
    # meeting_definitions
    execute <<~SQL
      UPDATE meeting_definitions SET service_id = 'ai_sns' WHERE service_id = 'ai_sns_ui'
    SQL

    # service_heartbeats
    execute <<~SQL
      UPDATE service_heartbeats SET service_id = 'ai_sns' WHERE service_id = 'ai_sns_ui'
    SQL

    # kpi_ledgers
    execute <<~SQL
      UPDATE kpi_ledgers SET service_id = 'ai_sns' WHERE service_id = 'ai_sns_ui'
    SQL

    # ticket_ledgers: service_id カラム + linked_kpis jsonb 内の service_id
    execute <<~SQL
      UPDATE ticket_ledgers SET service_id = 'ai_sns' WHERE service_id = 'ai_sns_ui'
    SQL
    execute <<~SQL
      UPDATE ticket_ledgers
      SET linked_kpis = jsonb_set(linked_kpis, '{service_id}', '"ai_sns"')
      WHERE linked_kpis->>'service_id' = 'ai_sns_ui'
    SQL

    # meeting_ledgers
    execute <<~SQL
      UPDATE meeting_ledgers SET service_id = 'ai_sns' WHERE service_id = 'ai_sns_ui'
    SQL

    # knowledge_ledgers: tags jsonb 内の service_id
    execute <<~SQL
      UPDATE knowledge_ledgers
      SET tags = jsonb_set(tags, '{service_id}', '"ai_sns"')
      WHERE tags->>'service_id' = 'ai_sns_ui'
    SQL

    # service_ledgers: ai_sns_ui 行を削除（ai_sns は既存）
    execute <<~SQL
      DELETE FROM service_ledgers WHERE service_id = 'ai_sns_ui'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
