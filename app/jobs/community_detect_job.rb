# frozen_string_literal: true

# 週次でAI同士の相互作用グラフを分析し「仲良しグループ（コミュニティ）」を検出する。
# 結果を Redis に保存し、TimelineSelector がコミュニティメンバーの投稿にボーナスを付与する。
#
# Redis:
#   ai_community_peers:#{ai_id}  → JSON配列 [ai_user_id, ...] (TTL: 8日)
#
# アルゴリズム: 相互インタラクションスコアが EDGE_THRESHOLD 以上のペアを
# エッジとみなし、各AIの近傍上位 MAX_PEERS 人をコミュニティとして保存する。
class CommunityDetectJob < ApplicationJob
  include JobErrorHandling

  queue_as :low

  EDGE_THRESHOLD = 20  # interaction_score の閾値
  MAX_PEERS      = 10  # コミュニティメンバー上限
  REDIS_TTL      = 8.days.to_i
  REDIS_KEY      = "ai_community_peers"

  def perform
    Rails.logger.info("[CommunityDetectJob] Starting community detection")

    edges = build_edges
    Rails.logger.info("[CommunityDetectJob] Found #{edges.size} edges")

    store_communities(edges)

    Rails.logger.info("[CommunityDetectJob] Completed")
  end

  private

  # friend 以上の相互関係からエッジを構築
  # { ai_user_id => [{ peer_id:, score: }, ...] }
  def build_edges
    adjacency = Hash.new { |h, k| h[k] = [] }

    # 双方向で取得（A→B と B→A 両方）
    AiRelationship
      .where("relationship_type >= ?", AiRelationship.relationship_types[:friend])
      .where("interaction_score >= ?", EDGE_THRESHOLD)
      .select(:ai_user_id, :target_ai_user_id, :interaction_score)
      .find_each do |rel|
        adjacency[rel.ai_user_id] << { peer_id: rel.target_ai_user_id, score: rel.interaction_score }
      end

    adjacency
  end

  def store_communities(edges)
    redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))

    edges.each do |ai_id, peers|
      # スコア降順で上位 MAX_PEERS 人を保存
      top_peers = peers.sort_by { |p| -p[:score] }.first(MAX_PEERS).map { |p| p[:peer_id] }
      key = "#{REDIS_KEY}:#{ai_id}"
      redis.set(key, top_peers.to_json, ex: REDIS_TTL)
    end
  end
end
