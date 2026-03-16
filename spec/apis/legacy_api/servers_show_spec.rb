# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Servers#show", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:admin_user) { create(:user, :admin) }
  let(:management_api_key) { create(:management_api_key, user: admin_user) }
  let(:other_organization) { create(:organization) }
  let(:foreign_server) { create(:server, organization: other_organization) }

  before do
    organization.update!(owner: admin_user)
  end

  it "returns server details inside the credential scope" do
    get "/api/v1/manage/servers/#{server.uuid}",
        headers: management_api_headers(management_api_key)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)

    expect(json["status"]).to eq("success")
    expect(json.dig("data", "server", "uuid")).to eq(server.uuid)
  end

  it "allows cross-organization server reads for management API keys" do
    get "/api/v1/manage/servers/#{foreign_server.uuid}",
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "server", "uuid")).to eq(foreign_server.uuid)
  end

  it "returns not found for unknown servers" do
    get "/api/v1/manage/servers/invalid-uuid",
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("ServerNotFound")
  end
end
