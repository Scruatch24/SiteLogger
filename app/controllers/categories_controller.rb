class CategoriesController < ApplicationController
  before_action :authenticate_user!

  def create
    unless current_user.profile&.paid?
      redirect_to history_path, alert: t("pro_feature_locked", default: "This feature requires a PRO account.") and return
    end

    @category = current_user.categories.build(category_params)

    if params[:category][:icon_type] == "custom" && params[:category][:custom_icon].present?
      @category.custom_icon.attach(params[:category][:custom_icon])
      @category.icon_type = "custom"
    else
      @category.icon = params[:category][:premade_icon]
      @category.icon_type = "premade"
    end

    if @category.save
      if params[:auto_assign_log_id].present?
        log = current_user.logs.find_by(id: params[:auto_assign_log_id])
        log.categories << @category if log
      end
      redirect_to history_path, notice: t("category_created")
    else
      redirect_to history_path, alert: "#{t('category_failed')}: #{@category.errors.full_messages.join(', ')}"
    end
  end

  def destroy
    @category = current_user.categories.find(params[:id])
    @category.destroy
    redirect_to history_path, notice: t("category_deleted")
  end

  private

  def category_params
    params.require(:category).permit(:name, :icon, :icon_type, :color)
  end
end
