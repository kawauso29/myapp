# frozen_string_literal: true

# 週次でAI同士の相互作用グラフを分析し「仲良しグループ（コミュニティ）」を検出する。
# 結果を Redis に保存し、TimelineSelector がコミュニティメンバーの投稿にボーナスを付与する。
# また DB の AiCommunity テーブルにコミュニティを永続化し、フロントエンドで「サークル」として可視化する。
#
# Redis:
#   ai_community_peers:#{ai_id}  → JSON配列 [ai_user_id, ...] (TTL: 8日)
#
# アルゴリズム: 相互インタラクションスコアが EDGE_THRESHOLD 以上のペアを
# エッジとみなし、各AIの近傍上位 MAX_PEERS 人をコミュニティとして保存する。
# さらにクラスタリングで共通興味タグに基づいたコミュニティ名を自動生成する。
class CommunityDetectJob < ApplicationJob
  include JobErrorHandling

  queue_as :low

  EDGE_THRESHOLD = 20  # interaction_score の閾値
  MAX_PEERS      = 10  # コミュニティメンバー上限
  MIN_CLUSTER    = 3   # コミュニティ最小メンバー数
  REDIS_TTL      = 8.days.to_i
  REDIS_KEY      = "ai_community_peers"

  CATEGORY_EMOJI = {
    "料理" => "🍳", "ゲーム" => "🎮", "音楽" => "🎵", "読書" => "📚",
    "スポーツ" => "⚽", "旅行" => "✈️", "映画" => "🎬", "テクノロジー" => "💻",
    "アート" => "🎨", "ファッション" => "👗", "フィットネス" => "💪",
    "写真" => "📷", "アウトドア" => "🏕️", "カフェ" => "☕"
  }.freeze

  def perform
    Rails.logger.info("[CommunityDetectJob] Starting community detection")

    edges = build_edges
    Rails.logger.info("[CommunityDetectJob] Found #{edges.size} edges")

    store_communities_in_redis(edges)
    clusters = detect_clusters(edges)
    persist_communities(clusters)

    Rails.logger.info("[CommunityDetectJob] Completed — #{clusters.size} communities persisted")
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
      .select(:id, :ai_user_id, :target_ai_user_id, :interaction_score)
      .find_each do |rel|
        adjacency[rel.ai_user_id] << { peer_id: rel.target_ai_user_id, score: rel.interaction_score }
      end

    adjacency
  end

  def store_communities_in_redis(edges)
    redis = $redis

    edges.each do |ai_id, peers|
      top_peers = peers.sort_by { |p| -p[:score] }.first(MAX_PEERS).map { |p| p[:peer_id] }
      key = "#{REDIS_KEY}:#{ai_id}"
      redis.set(key, top_peers.to_json, ex: REDIS_TTL)
    end
  end

  # 簡易クラスタリング: 共通する近傍が多いAI同士をグループ化
  def detect_clusters(edges)
    visited = Set.new
    clusters = []

    edges.each_key do |ai_id|
      next if visited.include?(ai_id)

      cluster = bfs_cluster(ai_id, edges, visited)
      clusters << cluster if cluster.size >= MIN_CLUSTER
    end

    clusters
  end

  def bfs_cluster(start_id, edges, visited)
    queue = [start_id]
    cluster = Set.new

    while queue.any?
      current = queue.shift
      next if visited.include?(current)

      visited.add(current)
      cluster.add(current)

      peers = edges[current]&.map { |p| p[:peer_id] } || []
      peers.each do |peer_id|
        queue << peer_id unless visited.include?(peer_id)
      end
    end

    cluster.to_a
  end

  def persist_communities(clusters)
    existing_names = AiCommunity.pluck(:name).to_set

    clusters.each do |member_ids|
      label = generate_community_label(member_ids)
      next if label.blank?

      community = AiCommunity.find_or_initialize_by(name: label[:name])
      community.description = label[:description]
      community.category = label[:category]
      community.emoji = label[:emoji]
      community.save!

      # メンバーシップを同期
      current_member_ids = community.ai_community_memberships.pluck(:ai_user_id).to_set
      new_ids = member_ids.to_set

      # 追加
      (new_ids - current_member_ids).each do |ai_id|
        community.ai_community_memberships.create(ai_user_id: ai_id)
      rescue ActiveRecord::RecordNotUnique
        nil
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn("[CommunityDetectJob] Membership creation failed: #{e.message}")
      end

      # 削除（クラスタから外れたメンバー）
      (current_member_ids - new_ids).each do |ai_id|
        community.ai_community_memberships.where(ai_user_id: ai_id).destroy_all
      end

      # counter_cache を正しく更新
      AiCommunity.reset_counters(community.id, :ai_community_memberships)
    end
  end

  def generate_community_label(member_ids)
    # メンバーの共通興味タグからコミュニティ名を生成
    tag_counts = AiInterestTag
                   .where(ai_user_id: member_ids)
                   .joins(:interest_tag)
                   .group("interest_tags.name", "interest_tags.category")
                   .order(Arel.sql("COUNT(*) DESC"))
                   .limit(3)
                   .pluck("interest_tags.name", "interest_tags.category", Arel.sql("COUNT(*)"))

    if tag_counts.any?
      top_tag_name = tag_counts.first[0]
      top_category = tag_counts.first[1]
      emoji = find_emoji(top_tag_name, top_category)
      description_tags = tag_counts.map(&:first).join("・")

      {
        name: "#{top_tag_name}好きサークル",
        description: "#{description_tags}に興味があるAIたちのグループ",
        category: top_category || top_tag_name,
        emoji: emoji
      }
    else
      # タグがない場合は関係性ベースの名前
      {
        name: "仲良しグループ ##{member_ids.min}",
        description: "#{member_ids.size}人の仲良しAIたちのグループ",
        category: "仲良し",
        emoji: "👥"
      }
    end
  end

  def find_emoji(tag_name, category)
    CATEGORY_EMOJI.each do |keyword, emoji|
      return emoji if tag_name&.include?(keyword) || category&.include?(keyword)
    end
    "👥"
  end
end
