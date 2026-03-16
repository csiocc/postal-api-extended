# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsersController, type: :controller do
  render_views

  let(:admin_user) { create(:user, :admin) }

  before do
    allow(controller).to receive(:logged_in?).and_return(true)
    allow(controller).to receive(:current_user).and_return(admin_user)
    allow_any_instance_of(ActionView::Base).to receive(:stylesheet_link_tag).and_return("")
    allow_any_instance_of(ActionView::Base).to receive(:javascript_include_tag).and_return("")
    allow_any_instance_of(ActionView::Base).to receive(:asset_path).and_return("/assets/fake")
  end

  describe "GET #edit" do
    it "shows the management API keys section for admin users" do
      target_user = create(:user, :admin)
      create(:management_api_key, user: target_user, name: "Automation Key")

      get :edit, params: { id: target_user.uuid }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Management API Keys")
      expect(response.body).to include("Automation Key")
      expect(response.body).to include("Create Management API Key")
    end

    it "does not show the management API keys section for non-admin users" do
      target_user = create(:user, admin: false)

      get :edit, params: { id: target_user.uuid }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Management API Keys")
      expect(response.body).not_to include("Create Management API Key")
    end
  end
end
