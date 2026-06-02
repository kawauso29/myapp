class AddLineSubmissionFields < ActiveRecord::Migration[8.1]
  def change
    add_column :linestamp_brands, :line_creator_name, :string, comment: "LINE申請: クリエイター名"
    add_column :linestamp_brands, :line_copyright, :string, comment: "LINE申請: コピーライト表記"
    add_column :linestamp_brands, :line_category, :string, comment: "LINE申請: キャラクター・カテゴリ"

    add_column :linestamp_packs, :line_title_ja, :string, comment: "LINE申請: タイトル(日本語) 最大40文字"
    add_column :linestamp_packs, :line_title_en, :string, comment: "LINE申請: タイトル(英語) 最大40文字"
    add_column :linestamp_packs, :line_desc_ja, :text, comment: "LINE申請: スタンプ説明文(日本語)"
    add_column :linestamp_packs, :line_desc_en, :text, comment: "LINE申請: スタンプ説明文(英語)"
  end
end
