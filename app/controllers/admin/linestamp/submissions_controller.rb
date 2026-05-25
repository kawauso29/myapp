class Admin::Linestamp::SubmissionsController < Admin::BaseController
  def index
    @submissions = ::Linestamp::Submission.includes(pack: :brand).order(updated_at: :desc)
  end
end
