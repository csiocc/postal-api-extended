# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LegacyAPI::Servers#update", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }

  let(:admin_user) { create(:user, admin: true) }
  let(:target_server) { create(:server, organization: organization, name: "Original Server") }
  let(:other_organization) { create(:organization) }
  let(:foreign_server) { create(:server, organization: other_organization, name: "Foreign Server") }

  before do
    organization.update!(owner: admin_user)
  end

  def json_headers_for(api_key)
    {
      "X-Server-API-Key" => api_key,
      "Content-Type" => "application/json"
    }
  end

  it "updates servers across organizations for admin credentials" do
    patch "/api/v1/servers/#{foreign_server.uuid}",
          params: { name: "Updated Server" }.to_json,
          headers: json_headers_for(credential.key)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "server", "name")).to eq("Updated Server")

    foreign_server.reload
    expect(foreign_server.name).to eq("Updated Server")
  end

  it "blocks cross-organization updates for non-admin owners" do
    organization.update!(owner: create(:user, admin: false))

    patch "/api/v1/servers/#{foreign_server.uuid}",
          params: { name: "Blocked Update" }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("ServerNotFound")
  end

  it "allows own-scope updates for non-admin owners" do
    organization.update!(owner: create(:user, admin: false))

    patch "/api/v1/servers/#{target_server.uuid}",
          params: { name: "Scoped Updated" }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "server", "name")).to eq("Scoped Updated")

    target_server.reload
    expect(target_server.name).to eq("Scoped Updated")
  end

  it "returns parameter-error for invalid mode" do
    patch "/api/v1/servers/#{target_server.uuid}",
          params: { mode: "InvalidMode" }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end
end
