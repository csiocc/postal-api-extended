# frozen_string_literal: true

class ManagementAPIKeysController < ApplicationController

  before_action :admin_required
  before_action :load_user

  def create
    unless @user.admin?
      redirect_to_with_json edit_user_path(@user), alert: "Management API keys can only be created for admin users."
      return
    end

    management_api_key = @user.management_api_keys.build(name: key_params[:name])

    if management_api_key.save
      flash[:management_api_key_created] = {
        "name" => management_api_key.name,
        "key" => management_api_key.key
      }
      redirect_to_with_json edit_user_path(@user), notice: "Management API key #{management_api_key.name} created successfully."
    else
      redirect_to_with_json edit_user_path(@user), alert: management_api_key.errors.full_messages.join(", ")
    end
  end

  def destroy
    management_api_key = @user.management_api_keys.find_by!(uuid: params[:id])
    management_api_key.revoke!

    redirect_to_with_json edit_user_path(@user), notice: "Management API key #{management_api_key.name} revoked successfully."
  end

  private

  def load_user
    @user = User.find_by!(uuid: params[:user_id])
  end

  def key_params
    params.require(:management_api_key).permit(:name)
  end

end
