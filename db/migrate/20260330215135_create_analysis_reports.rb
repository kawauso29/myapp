class CreateAnalysisReports < ActiveRecord::Migration[8.1]
  def change
    create_table :analysis_reports do |t|
      t.datetime :period_start
      t.datetime :period_end
      t.string :report_type
      t.jsonb :loss_patterns
      t.jsonb :good_skip_patterns
      t.jsonb :agent_accuracy
      t.text :improvement_suggestions
      t.string :status

      t.timestamps
    end
  end
end
