class CategoriesController < ApplicationController
  before_action :authenticate_user!

  def create
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
      redirect_to history_path, notice: "Category created successfully!"
    else
      redirect_to history_path, alert: "Failed to create category: #{@category.errors.full_messages.join(', ')}"
    end
  end

  def destroy
    @category = current_user.categories.find(params[:id])
    @category.destroy
    redirect_to history_path, notice: "Category deleted!"
  end

  private

  def category_params
    params.require(:category).permit(:name, :icon, :icon_type, :color)
  end
end
