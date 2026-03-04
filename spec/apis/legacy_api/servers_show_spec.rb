# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LegacyAPI::Servers#show", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }

  let(:admin_user) { create(:user, admin: true) }
  let(:other_organization) { create(:organization) }
  let(:foreign_server) { create(:server, organization: other_organization) }

  before do
    organization.update!(owner: admin_user)
  end

  it "returns server details inside the credential scope" do
    get "/api/v1/servers/#{server.uuid}",
        headers: { "X-Server-API-Key" => credential.key }

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)

    expect(json["status"]).to eq("success")
    expect(json.dig("data", "server", "uuid")).to eq(server.uuid)
  end

  it "allows cross-organization server reads for admin credentials" do
    get "/api/v1/servers/#{foreign_server.uuid}",
        headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "server", "uuid")).to eq(foreign_server.uuid)
  end

  it "does not disclose foreign servers for non-admin owners" do
    organization.update!(owner: create(:user, admin: false))

    get "/api/v1/servers/#{foreign_server.uuid}",
        headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("ServerNotFound")
  end
end
