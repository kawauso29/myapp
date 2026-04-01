require "rails_helper"

RSpec.describe "Api::V1::Posts", type: :request do
  let(:ai_user) { create(:ai_user) }

  describe "GET /api/v1/posts" do
    before do
      create_list(:ai_post, 3, ai_user: ai_user)
      create(:ai_post, :hidden, ai_user: ai_user)
    end

    it "returns visible posts without authentication" do
      get "/api/v1/posts"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"].length).to eq(3)
    end

    it "excludes hidden posts" do
      get "/api/v1/posts"

      json = JSON.parse(response.body)
      json["data"].each do |post|
        expect(post["is_visible"]).not_to eq(false)
      end
    end

    it "returns posts ordered by created_at desc" do
      get "/api/v1/posts"

      json = JSON.parse(response.body)
      timestamps = json["data"].map { |p| p["created_at"] }
      expect(timestamps).to eq(timestamps.sort.reverse)
    end

    it "includes meta with next_cursor and has_more" do
      get "/api/v1/posts"

      json = JSON.parse(response.body)
      expect(json["meta"]).to include("next_cursor", "has_more")
    end

    context "with cursor pagination" do
      before do
        # Create enough posts to test pagination
        AiPost.destroy_all
        @old_posts = (1..5).map do |i|
          create(:ai_post, ai_user: ai_user, created_at: i.hours.ago)
        end
      end

      it "returns posts before the cursor timestamp" do
        cursor = @old_posts[1].created_at.iso8601(3)
        get "/api/v1/posts", params: { before: cursor }

        json = JSON.parse(response.body)
        returned_ids = json["data"].map { |p| p["id"] }
        # Should only include posts created before the cursor
        expect(returned_ids).not_to include(@old_posts[0].id)
        expect(returned_ids).not_to include(@old_posts[1].id)
      end
    end

    context "with has_more flag" do
      before do
        AiPost.destroy_all
      end

      it "returns has_more: false when fewer than 20 posts" do
        create_list(:ai_post, 5, ai_user: ai_user)
        get "/api/v1/posts"

        json = JSON.parse(response.body)
        expect(json["meta"]["has_more"]).to be false
      end

      it "returns has_more: true when exactly 20 posts returned" do
        create_list(:ai_post, 25, ai_user: ai_user)
        get "/api/v1/posts"

        json = JSON.parse(response.body)
        expect(json["data"].length).to eq(20)
        expect(json["meta"]["has_more"]).to be true
      end
    end
  end

  describe "GET /api/v1/posts/:id" do
    let(:post_record) { create(:ai_post, ai_user: ai_user) }

    it "returns the post without authentication" do
      get "/api/v1/posts/#{post_record.id}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["id"]).to eq(post_record.id)
      expect(json["data"]["content"]).to eq(post_record.content)
    end

    it "includes replies in the response" do
      reply1 = create(:ai_post, ai_user: ai_user, reply_to_post_id: post_record.id, created_at: 1.hour.ago)
      reply2 = create(:ai_post, ai_user: ai_user, reply_to_post_id: post_record.id, created_at: 30.minutes.ago)

      get "/api/v1/posts/#{post_record.id}"

      json = JSON.parse(response.body)
      reply_ids = json["data"]["replies"].map { |r| r["id"] }
      expect(reply_ids).to eq([reply1.id, reply2.id]) # ordered by created_at asc
    end

    it "excludes hidden replies" do
      create(:ai_post, ai_user: ai_user, reply_to_post_id: post_record.id, is_visible: true)
      create(:ai_post, ai_user: ai_user, reply_to_post_id: post_record.id, is_visible: false)

      get "/api/v1/posts/#{post_record.id}"

      json = JSON.parse(response.body)
      expect(json["data"]["replies"].length).to eq(1)
    end

    it "returns 404 for non-existent post" do
      get "/api/v1/posts/999999"

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for hidden post" do
      hidden_post = create(:ai_post, :hidden, ai_user: ai_user)

      get "/api/v1/posts/#{hidden_post.id}"

      expect(response).to have_http_status(:not_found)
    end
  end
end
