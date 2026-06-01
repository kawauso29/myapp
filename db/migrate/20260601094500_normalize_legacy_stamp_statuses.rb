class NormalizeLegacyStampStatuses < ActiveRecord::Migration[8.1]
  # 透過工程の撤去で raw_uploaded / processing / failed 状態が消えたため、
  # 既存レコードを新しい3状態(prompt_ready / planned)に冪等に寄せる。
  def up
    say_with_time "remap legacy stamp statuses → prompt_ready/planned" do
      execute <<~SQL
        UPDATE linestamp_stamps
        SET status = CASE
          WHEN prompt IS NOT NULL AND prompt <> '' THEN 'prompt_ready'
          ELSE 'planned'
        END
        WHERE status IN ('raw_uploaded', 'processing', 'failed')
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
