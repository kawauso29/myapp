class Admin::RepositoryController < Admin::BaseController
  # /admin のトップ。リポジトリ全体の機能管理(Linestamp / Picro 等)と
  # 進行中プロジェクトの一覧を表示する簡素なダッシュボード。
  def index
    @linestamp_stats = {
      brands: ::Linestamp::Brand.count,
      packs: ::Linestamp::Pack.count,
      stamps: ::Linestamp::Stamp.count,
      processed_stamps: ::Linestamp::Stamp.where(status: "processed").count
    }
    @picro_count = defined?(::PicroMessage) ? ::PicroMessage.count : 0
  rescue ActiveRecord::StatementInvalid
    # マイグレ未済等で落ちないよう defensive
    @linestamp_stats = { brands: 0, packs: 0, stamps: 0, processed_stamps: 0 }
    @picro_count = 0
  end

  # 既存ルートのスタブ(routes.rb で宣言されているが実装が無かったもの)
  def sync_env
    head :ok
  end

  def trigger_db_snapshot
    head :ok
  end
end
