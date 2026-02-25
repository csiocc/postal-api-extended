# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "LegacyAPI::Users#update", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }
  let(:admin_user) { create(:user, admin: true) }
  let(:target_user) { create(:user, first_name: "Original") }

  before do
    organization.update(owner: admin_user)
  end

  it "updates user with valid parameters" do
    patch "/api/v1/users/#{target_user.uuid}",
          params: { first_name: "Updated" }.to_json,
          headers: {
            "X-Server-API-Key" => credential.key,
            "Content-Type" => "application/json"
          }

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json["data"]["user"]["first_name"]).to eq("Updated")
    
    target_user.reload
    expect(target_user.first_name).to eq("Updated")
  end

  it "prevents admin from removing own admin status" do
    # attempting to modify admin_user's admin status should fail
    
    patch "/api/v1/users/#{admin_user.uuid}",
          params: { admin: false }.to_json,
          headers: {
            "X-Server-API-Key" => credential.key,
            "Content-Type" => "application/json"
          }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("CannotModifySelf")
  end
end
