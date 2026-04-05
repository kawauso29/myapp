class HomeController < ApplicationController
  def index
    redirect_to "/app/", status: 302
  end
end
