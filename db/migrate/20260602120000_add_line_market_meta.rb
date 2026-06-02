class AddLineMarketMeta < ActiveRecord::Migration[8.1]
  def up
    unless column_exists?(:linestamp_brands, :line_creator_name)
      add_column :linestamp_brands, :line_creator_name, :string,
                 comment: "LINE クリエイター名(全パック共通・ブランド固定)"
    end
    unless column_exists?(:linestamp_brands, :line_copyright)
      add_column :linestamp_brands, :line_copyright, :string,
                 comment: "LINE コピーライト表記(50文字以内)"
    end

    unless column_exists?(:linestamp_packs, :line_title_ja)
      add_column :linestamp_packs, :line_title_ja, :string,
                 comment: "LINE掲載タイトル 日本語(40文字以内)"
    end
    unless column_exists?(:linestamp_packs, :line_title_en)
      add_column :linestamp_packs, :line_title_en, :string,
                 comment: "LINE掲載タイトル 英語(40文字以内)"
    end
    unless column_exists?(:linestamp_packs, :line_desc_ja)
      add_column :linestamp_packs, :line_desc_ja, :text,
                 comment: "LINE掲載説明文 日本語(160文字以内)"
    end
    unless column_exists?(:linestamp_packs, :line_desc_en)
      add_column :linestamp_packs, :line_desc_en, :text,
                 comment: "LINE掲載説明文 英語(160文字以内)"
    end
    unless column_exists?(:linestamp_packs, :line_meta_prompt)
      add_column :linestamp_packs, :line_meta_prompt, :text,
                 comment: "英語版タイトル/説明文/タグ生成用 Cowork プロンプト"
    end
  end

  def down
    remove_column :linestamp_brands, :line_creator_name, if_exists: true
    remove_column :linestamp_brands, :line_copyright, if_exists: true
    remove_column :linestamp_packs, :line_title_ja, if_exists: true
    remove_column :linestamp_packs, :line_title_en, if_exists: true
    remove_column :linestamp_packs, :line_desc_ja, if_exists: true
    remove_column :linestamp_packs, :line_desc_en, if_exists: true
    remove_column :linestamp_packs, :line_meta_prompt, if_exists: true
  end
end
