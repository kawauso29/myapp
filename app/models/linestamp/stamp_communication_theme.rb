# frozen_string_literal: true

class Linestamp::StampCommunicationTheme < ApplicationRecord
  self.table_name = "linestamp_stamp_communication_themes"

  belongs_to :stamp, class_name: "Linestamp::Stamp"
  belongs_to :communication_theme, class_name: "Linestamp::CommunicationTheme"

  after_save    :sync_parent_primary_id, if: :saved_change_to_primary?
  after_destroy :sync_parent_primary_id

  private

  def sync_parent_primary_id
    return unless stamp

    primary_join = stamp.stamp_communication_themes.find_by(primary: true)
    stamp.update_column(:primary_communication_theme_id, primary_join&.communication_theme_id)
  end
end
