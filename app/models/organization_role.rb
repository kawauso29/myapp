# Phase 44d / §19: 組織ロール定義マスタ。
#
# MeetingDefinition の participant_roles（JSONB 文字列配列）をこのテーブルで検証する。
# `role_key` がユニークキー。active なロールのみ会議参加者として使用可能。
class OrganizationRole < ApplicationRecord
  enum :scope_level, {
    company: 0,
    portfolio: 1,
    service: 2,
    cross_service: 3
  }, prefix: true

  enum :category, {
    executive: 0,
    department: 1,
    specialist: 2
  }, prefix: true

  validates :role_key, :display_name, :scope_level, :category, presence: true
  validates :role_key, uniqueness: true
  validates :role_key, format: { with: /\A[a-z][a-z0-9_]*\z/, message: "must be lowercase with underscores" }

  scope :active, -> { where(active: true) }

  # 指定されたロールキー群がすべてマスタに存在するかを検証する。
  # @param role_keys [Array<String>]
  # @return [Array<String>] マスタに存在しないロールキーの配列（空なら全検証 OK）
  def self.validate_roles(role_keys)
    return [] if role_keys.blank?

    known = active.where(role_key: role_keys).pluck(:role_key)
    Array(role_keys) - known
  end
end
