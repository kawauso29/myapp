class CreateLedgerCoreTables < ActiveRecord::Migration[8.1]
  def change
    create_table :meeting_definitions do |t|
      t.string :meeting_key, null: false
      t.integer :meeting_type, null: false
      t.integer :scope_level, null: false
      t.string :service_id
      t.string :chair_role, null: false
      t.jsonb :participant_roles, null: false, default: []
      t.jsonb :writes_ledgers, null: false, default: []
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :meeting_definitions, :meeting_key, unique: true
    add_index :meeting_definitions, [ :meeting_type, :scope_level ]

    create_table :meeting_ledgers do |t|
      t.references :meeting_definition, null: false, foreign_key: true
      t.string :meeting_key, null: false
      t.integer :meeting_type, null: false
      t.integer :scope_level, null: false
      t.string :service_id
      t.string :chair, null: false
      t.jsonb :participants, null: false, default: []
      t.jsonb :input_materials, null: false, default: []
      t.jsonb :decisions, null: false, default: []
      t.jsonb :hold_items, null: false, default: []
      t.jsonb :tickets_to_create, null: false, default: []
      t.jsonb :escalations, null: false, default: []
      t.jsonb :directives, null: false, default: []
      t.integer :status, null: false, default: 0
      t.datetime :held_at, null: false

      t.timestamps
    end

    add_index :meeting_ledgers, [ :meeting_key, :held_at ]

    create_table :ticket_ledgers do |t|
      t.string :ticket_type, null: false
      t.string :title, null: false
      t.integer :scope_level, null: false
      t.string :service_id
      t.string :business_owner
      t.integer :source_meeting_type
      t.references :source_meeting, foreign_key: { to_table: :meeting_ledgers }
      t.string :owner_dept
      t.string :owner_agent
      t.jsonb :linked_kpis, null: false, default: []
      t.jsonb :linked_artifacts, null: false, default: []
      t.integer :priority, null: false, default: 1
      t.integer :status, null: false, default: 0
      t.integer :due_cycle
      t.integer :escalation_to

      t.timestamps
    end

    add_index :ticket_ledgers, [ :status, :escalation_to ]
    add_index :ticket_ledgers, :service_id

    create_table :service_heartbeats do |t|
      t.references :meeting_definition, null: false, foreign_key: true
      t.string :service_id
      t.integer :due_cycle, null: false
      t.integer :status, null: false, default: 0
      t.datetime :last_run_at
      t.datetime :next_run_at

      t.timestamps
    end

    add_index :service_heartbeats, [ :meeting_definition_id, :service_id ], unique: true
    add_index :service_heartbeats, [ :status, :next_run_at ]
  end
end
