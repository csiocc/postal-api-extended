# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LegacyAPI::Credentials#index", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization, name: "Credential Server") }
  let(:credential) { create(:credential, server: server) }
  let(:global_admin_credential) do
    create(:credential,
           server: server,
           options: { "global_admin" => true })
  end

  let(:admin_user) { create(:user, admin: true) }
  let!(:scoped_credential) { create(:credential, server: server, name: "Scoped Credential") }
  let(:other_organization) { create(:organization) }
  let(:other_server) { create(:server, organization: other_organization) }
  let!(:other_org_credential) { create(:credential, server: other_server, name: "Other Org Credential") }

  before do
    organization.update!(owner: admin_user)
  end

  it "returns only credentials in the current organization scope" do
    get "/api/v1/credentials", headers: { "X-Server-API-Key" => credential.key }

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    uuids = json["data"]["credentials"].map { |credential_data| credential_data["uuid"] }

    expect(json["status"]).to eq("success")
    expect(uuids).to include(credential.uuid, scoped_credential.uuid)
    expect(uuids).not_to include(other_org_credential.uuid)
    expect(json.dig("data", "total")).to eq(uuids.size)
  end

  it "allows cross-organization listing for global-admin credentials" do
    get "/api/v1/credentials", headers: { "X-Server-API-Key" => global_admin_credential.key }

    json = JSON.parse(response.body)
    uuids = json["data"]["credentials"].map { |credential_data| credential_data["uuid"] }

    expect(json["status"]).to eq("success")
    expect(uuids).to include(other_org_credential.uuid)
  end

  it "filters by server_id for global-admin credentials" do
    get "/api/v1/credentials",
        params: { server_id: other_server.id },
        headers: { "X-Server-API-Key" => global_admin_credential.key }

    json = JSON.parse(response.body)
    uuids = json["data"]["credentials"].map { |credential_data| credential_data["uuid"] }

    expect(json["status"]).to eq("success")
    expect(uuids).to eq([other_org_credential.uuid])
    expect(json.dig("data", "total")).to eq(1)
  end

  it "filters by server_id inside scoped organization" do
    get "/api/v1/credentials",
        params: { server_id: server.id },
        headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    uuids = json["data"]["credentials"].map { |credential_data| credential_data["uuid"] }

    expect(json["status"]).to eq("success")
    expect(uuids).to include(credential.uuid, scoped_credential.uuid)
    expect(uuids).not_to include(other_org_credential.uuid)
  end

  it "returns access denied for out-of-scope server_id filter" do
    get "/api/v1/credentials",
        params: { server_id: other_server.id },
        headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("AccessDenied")
  end

  it "returns server not found for unknown server_id filter" do
    get "/api/v1/credentials",
        params: { server_id: 9_999_999 },
        headers: { "X-Server-API-Key" => global_admin_credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("ServerNotFound")
  end

  it "returns parameter-error for invalid server_id filter" do
    get "/api/v1/credentials",
        params: { server_id: "abc" },
        headers: { "X-Server-API-Key" => global_admin_credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end

  it "denies access to non-admin owners" do
    regular_owner = create(:user, admin: false)
    organization.update!(owner: regular_owner)

    get "/api/v1/credentials", headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("AccessDenied")
  end
end
