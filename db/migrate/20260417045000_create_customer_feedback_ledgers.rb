class CreateCustomerFeedbackLedgers < ActiveRecord::Migration[8.1]
  # Phase 39 / §32.1: 顧客フィードバック導線。
  #
  # アプリ内問い合わせ・Slack 報告・NPS 等のインプットを 1 台帳に集約し、
  # `Feedback::Intake` が improvement ticket や investigation ticket へ昇格させる。
  def change
    create_table :customer_feedback_ledgers do |t|
      # 0: in_app / 1: slack / 2: email / 3: nps / 4: external_review / 5: manual
      t.integer :source, null: false

      # 0: company / 1: portfolio / 2: service / 3: cross_service
      t.integer :scope_level, null: false
      t.string :service_id

      t.text :raw_text, null: false
      t.string :submitted_by

      # 0: new / 1: categorized / 2: escalated / 3: closed
      t.integer :status, default: 0, null: false

      # NLP / ルールベースでの分類タグ（sentiment / topic 等）
      t.jsonb :categorization, default: {}, null: false

      t.bigint :linked_ticket_id
      t.string :idempotency_key

      t.datetime :received_at, null: false
      t.timestamps
    end

    add_index :customer_feedback_ledgers, [ :status, :source ]
    add_index :customer_feedback_ledgers, [ :scope_level, :service_id, :received_at ],
              name: "idx_cust_feedback_scope_received"
    add_index :customer_feedback_ledgers, :linked_ticket_id
    add_index :customer_feedback_ledgers, :idempotency_key, unique: true, where: "(idempotency_key IS NOT NULL)"
  end
end
