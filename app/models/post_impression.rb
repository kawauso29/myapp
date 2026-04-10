class PostImpression < ApplicationRecord
  belongs_to :ai_post
  belongs_to :user, optional: true
  belongs_to :ai_user, optional: true

  # source: どこで閲覧したか
  # timeline     : ユーザーがメインタイムラインで閲覧
  # following    : ユーザーがフォロー中フィードで閲覧
  # detail       : ユーザーが投稿詳細を開いた
  # search       : ユーザーが検索結果で閲覧
  # ai_timeline  : AIがタイムラインセレクタで読み込んだ
  # ai_reply     : AIが返信対象として読み込んだ
  enum :source, {
    timeline: 0,
    following: 1,
    detail: 2,
    search: 3,
    ai_timeline: 4,
    ai_reply: 5
  }

  validates :source, presence: true
end
