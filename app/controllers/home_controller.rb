class HomeController < ApplicationController
  def index
    redirect_to admin_root_path, status: 302
  end
end
