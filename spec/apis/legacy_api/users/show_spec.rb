# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "LegacyAPI::Users#show", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }
  let(:global_admin_credential) do
    create(:credential,
           server: server,
           options: { "global_admin" => true })
  end
  let(:string_false_credential) do
    create(:credential,
           server: server,
           options: { "global_admin" => "false" })
  end

  let(:admin_user) { create(:user, admin: true) }
  let(:target_user) { create(:user) }
  let(:other_organization) { create(:organization) }
  let(:foreign_user) { create(:user) }

  before do
    organization.update!(owner: admin_user)
    target_user.organizations << organization
    foreign_user.organizations << other_organization
  end

  it "returns user details for users inside the credential scope" do
    get "/api/v1/users/#{target_user.uuid}",
        headers: { "X-Server-API-Key" => credential.key }

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)

    expect(json["status"]).to eq("success")
    expect(json.dig("data", "user", "uuid")).to eq(target_user.uuid)
  end

  it "does not disclose users outside the credential scope" do
    get "/api/v1/users/#{foreign_user.uuid}",
        headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("UserNotFound")
  end

  it "allows cross-organization user reads for global-admin credentials" do
    get "/api/v1/users/#{foreign_user.uuid}",
        headers: { "X-Server-API-Key" => global_admin_credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "user", "uuid")).to eq(foreign_user.uuid)
  end

  it "does not treat string false as global access" do
    get "/api/v1/users/#{foreign_user.uuid}",
        headers: { "X-Server-API-Key" => string_false_credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("UserNotFound")
  end
end
