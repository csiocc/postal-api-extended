# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LegacyAPI::Servers#index", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization, name: "Credential Server") }
  let(:credential) { create(:credential, server: server) }

  let(:admin_user) { create(:user, admin: true) }
  let!(:scoped_server) { create(:server, organization: organization, name: "Scoped Server") }
  let(:other_organization) { create(:organization) }
  let!(:other_org_server) { create(:server, organization: other_organization) }

  before do
    organization.update!(owner: admin_user)
  end

  it "returns servers across organizations for admin credentials" do
    get "/api/v1/servers", headers: { "X-Server-API-Key" => credential.key }

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    uuids = json["data"]["servers"].map { |server_data| server_data["uuid"] }

    expect(json["status"]).to eq("success")
    expect(uuids).to include(server.uuid, scoped_server.uuid)
    expect(uuids).to include(other_org_server.uuid)
    expect(json.dig("data", "total")).to eq(uuids.size)
  end

  it "returns only scoped servers for non-admin owners" do
    organization.update!(owner: create(:user, admin: false))

    get "/api/v1/servers", headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    uuids = json["data"]["servers"].map { |server_data| server_data["uuid"] }

    expect(json["status"]).to eq("success")
    expect(uuids).to include(server.uuid, scoped_server.uuid)
    expect(uuids).not_to include(other_org_server.uuid)
  end
end
