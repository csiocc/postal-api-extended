# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Servers#index", type: :request do
  let(:organization) { create(:organization) }
  let!(:server) { create(:server, organization: organization, name: "Credential Server") }
  let(:admin_user) { create(:user, :admin) }
  let(:management_api_key) { create(:management_api_key, user: admin_user) }
  let!(:scoped_server) { create(:server, organization: organization, name: "Scoped Server") }
  let(:other_organization) { create(:organization) }
  let!(:other_org_server) { create(:server, organization: other_organization) }

  before do
    organization.update!(owner: admin_user)
  end

  it "returns servers across organizations for management API keys" do
    get "/api/v1/manage/servers", headers: management_api_headers(management_api_key)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    uuids = json["data"]["servers"].map { |server_data| server_data["uuid"] }

    expect(json["status"]).to eq("success")
    expect(uuids).to include(server.uuid, scoped_server.uuid)
    expect(uuids).to include(other_org_server.uuid)
    expect(json.dig("data", "total")).to eq(uuids.size)
  end

  it "rejects server API keys on management routes" do
    credential = create(:credential, server: server)
    get "/api/v1/manage/servers", headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("AccessDenied")
  end
end
