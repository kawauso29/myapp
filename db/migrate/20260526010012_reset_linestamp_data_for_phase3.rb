# frozen_string_literal: true

# Sprint G: Clean start - delete all linestamp records and ActiveStorage attachments
# This is irreversible by design (explicit instruction from project owner).
class ResetLinestampDataForPhase3 < ActiveRecord::Migration[8.0]
  def up
    # Delete in dependency order: joins → submissions → stamps → packs → brands → researches

    say_with_time "Deleting linestamp join tables" do
      %w[
        linestamp_brand_communication_themes
        linestamp_pack_communication_themes
        linestamp_stamp_communication_themes
        linestamp_research_communication_themes
        linestamp_brand_attribute_values
        linestamp_pack_attribute_values
        linestamp_stamp_attribute_values
        linestamp_research_attribute_values
      ].each { |t| execute("DELETE FROM #{t}") if table_exists?(t) }
    end

    say_with_time "Deleting linestamp_submissions" do
      execute("DELETE FROM linestamp_submissions") if table_exists?(:linestamp_submissions)
    end

    say_with_time "Deleting linestamp_stamps" do
      execute("DELETE FROM linestamp_stamps") if table_exists?(:linestamp_stamps)
    end

    say_with_time "Deleting linestamp_packs" do
      execute("DELETE FROM linestamp_packs") if table_exists?(:linestamp_packs)
    end

    say_with_time "Deleting linestamp_brands" do
      execute("DELETE FROM linestamp_brands") if table_exists?(:linestamp_brands)
    end

    say_with_time "Deleting linestamp_researches" do
      execute("DELETE FROM linestamp_researches") if table_exists?(:linestamp_researches)
    end

    say_with_time "Deleting linestamp_seed_applications" do
      execute("DELETE FROM linestamp_seed_applications") if table_exists?(:linestamp_seed_applications)
    end

    say_with_time "Deleting ActiveStorage attachments for Linestamp records" do
      if table_exists?(:active_storage_attachments)
        execute(<<~SQL)
          DELETE FROM active_storage_attachments
          WHERE record_type LIKE 'Linestamp::%'
        SQL
      end
    end

    say_with_time "Deleting orphaned ActiveStorage blobs" do
      if table_exists?(:active_storage_blobs) && table_exists?(:active_storage_attachments)
        execute(<<~SQL)
          DELETE FROM active_storage_blobs
          WHERE id NOT IN (SELECT blob_id FROM active_storage_attachments)
        SQL
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
