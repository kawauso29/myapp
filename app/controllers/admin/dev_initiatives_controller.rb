class Admin::DevInitiativesController < Admin::BaseController
  def index
    @initiatives = DevInitiative.all.ordered
    @stats = {
      todo:        DevInitiative.status_todo.count,
      in_progress: DevInitiative.status_in_progress.count,
      done:        DevInitiative.status_done.count,
      total:       DevInitiative.count
    }
  end

  def update
    @initiative = DevInitiative.find(params[:id])
    if @initiative.update(initiative_params)
      redirect_back fallback_location: admin_dev_initiatives_path, notice: "[#{@initiative.item_key}] を更新しました"
    else
      redirect_back fallback_location: admin_dev_initiatives_path, alert: "更新に失敗しました: #{@initiative.errors.full_messages.join(', ')}"
    end
  end

  def update_status
    @initiative = DevInitiative.find(params[:id])
    new_status = params[:status].to_s

    case new_status
    when "in_progress"
      @initiative.assign_attributes(status: :in_progress, started_at: Time.current)
    when "done"
      @initiative.assign_attributes(status: :done, completed_at: Time.current)
    when "todo"
      @initiative.assign_attributes(status: :todo, started_at: nil, completed_at: nil)
    else
      return redirect_back fallback_location: admin_dev_initiatives_path, alert: "不正なステータスです"
    end

    if @initiative.save
      redirect_back fallback_location: admin_dev_initiatives_path, notice: "[#{@initiative.item_key}] → #{new_status} に更新しました"
    else
      redirect_back fallback_location: admin_dev_initiatives_path, alert: "更新に失敗しました"
    end
  end

  private

  def initiative_params
    params.require(:dev_initiative).permit(:title, :category, :priority, :status, :kpi_hypothesis, :kpi_result, :pr_branch, :notes)
  end
end
