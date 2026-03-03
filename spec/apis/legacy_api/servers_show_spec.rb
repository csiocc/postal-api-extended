# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LegacyAPI::Servers#show", type: :request do
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

  it "does not disclose servers outside the credential scope" do
    get "/api/v1/servers/#{foreign_server.uuid}",
        headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("ServerNotFound")
  end

  it "allows cross-organization server reads for global-admin credentials" do
    get "/api/v1/servers/#{foreign_server.uuid}",
        headers: { "X-Server-API-Key" => global_admin_credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "server", "uuid")).to eq(foreign_server.uuid)
  end

  it "does not treat string false as global access" do
    get "/api/v1/servers/#{foreign_server.uuid}",
        headers: { "X-Server-API-Key" => string_false_credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("ServerNotFound")
  end
end
