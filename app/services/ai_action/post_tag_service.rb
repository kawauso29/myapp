module AiAction
  class PostTagService
    def self.save_tags(post, tag_names)
      return if tag_names.blank?

      tag_names.each do |name|
        tag = InterestTag.find_or_create_by!(name: name) do |t|
          t.category = "日常・雑談"
        end
        PostInterestTag.find_or_create_by!(ai_post: post, interest_tag: tag)
        tag.increment!(:usage_count)
      end

      post.update!(tags: tag_names)
    end
  end
end
