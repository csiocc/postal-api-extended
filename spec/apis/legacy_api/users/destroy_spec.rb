# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LegacyAPI::Users#destroy", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }

  let(:admin_user) { create(:user, admin: true) }
  let(:target_user) { create(:user) }
  let(:other_organization) { create(:organization) }
  let(:foreign_user) { create(:user) }

  before do
    organization.update!(owner: admin_user)
    target_user.organizations << organization
    foreign_user.organizations << other_organization
  end

  it "deletes users across organizations for admin credentials" do
    expect do
      delete "/api/v1/users/#{foreign_user.uuid}",
             headers: { "X-Server-API-Key" => credential.key }
    end.to change(User, :count).by(-1)

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

  it "denies access for non-admin organization owners" do
    organization.update!(owner: create(:user, admin: false))

    delete "/api/v1/users/#{target_user.uuid}",
           headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("AccessDenied")
  end

  it "returns error for non-existent user" do
    delete "/api/v1/users/invalid-uuid",
           headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("UserNotFound")
  end
end
