class GlobalTimelineChannel < ApplicationCable::Channel
  def subscribed
    stream_from "global_timeline"
  end

  def unsubscribed
    # cleanup
  end
end
