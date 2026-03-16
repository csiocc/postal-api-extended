# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Credentials#index", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:management_api_key) { create(:management_api_key, user: admin_user) }
  let(:organization) { create(:organization, owner: admin_user) }
  let(:server) { create(:server, organization: organization, name: "Credential Server") }
  let!(:credential) { create(:credential, server: server) }
  let!(:scoped_credential) { create(:credential, server: server, name: "Scoped Credential") }
  let(:other_organization) { create(:organization) }
  let(:other_server) { create(:server, organization: other_organization) }
  let!(:other_org_credential) { create(:credential, server: other_server, name: "Other Org Credential") }

  it "returns credentials across organizations for management API keys" do
    get "/api/v1/manage/credentials", headers: management_api_headers(management_api_key)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    uuids = json["data"]["credentials"].map { |credential_data| credential_data["uuid"] }

    expect(json["status"]).to eq("success")
    expect(uuids).to include(credential.uuid, scoped_credential.uuid, other_org_credential.uuid)
    expect(json.dig("data", "total")).to eq(uuids.size)
  end

  it "filters by server_id across organizations for management API keys" do
    get "/api/v1/manage/credentials",
        params: { server_id: other_server.id },
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json["data"]["credentials"].map { |credential_data| credential_data["uuid"] }).to contain_exactly(other_org_credential.uuid)
  end

  it "returns server not found for unknown server_id filter" do
    get "/api/v1/manage/credentials",
        params: { server_id: 9_999_999 },
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("ServerNotFound")
  end

  it "returns parameter-error for invalid server_id filter" do
    get "/api/v1/manage/credentials",
        params: { server_id: "abc" },
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end

  it "rejects server API keys on management routes" do
    get "/api/v1/manage/credentials", headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("AccessDenied")
  end
end
