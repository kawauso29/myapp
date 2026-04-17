class AddTemplateIdToTicketLedgers < ActiveRecord::Migration[8.1]
  # Phase 35 / 補強9: Copilot 標準入力テンプレートの ID を ticket に保存する。
  #
  # これまで `GithubMapping::CopilotInputTemplate#template_id` は生成の都度文字列を
  # 計算していたが、テンプレートを後から辿り直すには ticket 側に保存しておく必要がある。
  # 文字列は "tmpl-<ticket_type>-<ticket_id>" 形式。
  def change
    add_column :ticket_ledgers, :template_id, :string
    add_index :ticket_ledgers, :template_id,
              unique: true,
              where: "(template_id IS NOT NULL)",
              name: "idx_ticket_ledgers_template_id"
  end
end
