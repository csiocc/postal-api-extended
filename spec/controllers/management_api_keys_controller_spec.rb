# frozen_string_literal: true

require "rails_helper"

RSpec.describe ManagementAPIKeysController, type: :controller do
  let(:admin_user) { create(:user, :admin) }

  before do
    allow(controller).to receive(:logged_in?).and_return(true)
    allow(controller).to receive(:current_user).and_return(admin_user)
  end

  describe "POST #create" do
    it "creates a management API key and exposes the plaintext in flash once" do
      target_user = create(:user, :admin)

      expect do
        post :create, params: { user_id: target_user.uuid, management_api_key: { name: "Automation Key" } }, format: :json
      end.to change(ManagementAPIKey, :count).by(1)

      created_key = ManagementAPIKey.last

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include("redirect_to" => edit_user_path(target_user))
      expect(created_key.name).to eq("Automation Key")
      expect(created_key.key).to be_nil
      expect(flash[:management_api_key_created]).to include(
        "name" => "Automation Key"
      )
      expect(created_key.key_digest).to eq(ManagementAPIKey.digest_for(flash[:management_api_key_created]["key"]))
    end

    it "rejects keys for non-admin users" do
      target_user = create(:user, admin: false)

      expect do
        post :create, params: { user_id: target_user.uuid, management_api_key: { name: "Automation Key" } }, format: :json
      end.not_to change(ManagementAPIKey, :count)

      expect(response).to have_http_status(:ok)
      expect(flash[:alert]).to eq("Management API keys can only be created for admin users.")
    end
  end

  describe "DELETE #destroy" do
    it "revokes an active management API key" do
      target_user = create(:user, :admin)
      management_api_key = create(:management_api_key, user: target_user, revoked_at: nil)

      delete :destroy, params: { user_id: target_user.uuid, id: management_api_key.uuid }, format: :json

      expect(response).to have_http_status(:ok)
      expect(management_api_key.reload).to be_revoked
      expect(flash[:notice]).to eq("Management API key #{management_api_key.name} revoked successfully.")
    end
  end
end
