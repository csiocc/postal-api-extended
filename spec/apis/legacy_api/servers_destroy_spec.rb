# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LegacyAPI::Servers#destroy", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization, name: "Credential Server") }
  let(:credential) { create(:credential, server: server) }

  let(:admin_user) { create(:user, admin: true) }
  let(:target_server) { create(:server, organization: organization, name: "Target Server") }
  let(:other_organization) { create(:organization) }
  let(:foreign_server) { create(:server, organization: other_organization) }

  before do
    organization.update!(owner: admin_user)
  end

  it "soft deletes a server inside the credential organization" do
    delete "/api/v1/servers/#{target_server.uuid}",
           headers: { "X-Server-API-Key" => credential.key }

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(target_server.reload.deleted_at).to be_present
  end

  it "does not delete foreign servers for admin credentials" do
    delete "/api/v1/servers/#{foreign_server.uuid}",
           headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("ServerNotFound")
    expect(foreign_server.reload.deleted_at).to be_nil
  end

  it "blocks cross-organization deletion for non-admin owners" do
    organization.update!(owner: create(:user, admin: false))

    delete "/api/v1/servers/#{foreign_server.uuid}",
           headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("ServerNotFound")
    expect(foreign_server.reload.deleted_at).to be_nil
  end

  it "allows own-organization deletion for non-admin owners" do
    organization.update!(owner: create(:user, admin: false))

    delete "/api/v1/servers/#{target_server.uuid}",
           headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(target_server.reload.deleted_at).to be_present
  end

  it "returns error for non-existent server" do
    delete "/api/v1/servers/invalid-uuid",
           headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("ServerNotFound")
  end
end
