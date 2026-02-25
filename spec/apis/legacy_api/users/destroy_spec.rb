# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "LegacyAPI::Users#destroy", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }
  let(:admin_user) { create(:user, admin: true) }
  let(:target_user) { create(:user) }

  before do
    organization.update(owner: admin_user)
  end

  it "deletes user successfully" do
    # Ensure target user exists first
    expect(target_user).to be_persisted

    expect {
      delete "/api/v1/users/#{target_user.uuid}",
             headers: { "X-Server-API-Key" => credential.key }
    }.to change(User, :count).by(-1)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
  end

  it "prevents self-deletion" do
    delete "/api/v1/users/#{admin_user.uuid}",
           headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("CannotModifySelf")
  end

  it "returns error for non-existent user" do
    delete "/api/v1/users/invalid-uuid",
           headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("UserNotFound")
  end
end
