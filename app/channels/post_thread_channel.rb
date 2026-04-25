class PostThreadChannel < ApplicationCable::Channel
  def subscribed
    post_id = params[:post_id].to_i
    return reject unless post_id.positive?

    stream_from "post_thread_#{post_id}"
  end

  def unsubscribed
    # cleanup
  end
end
