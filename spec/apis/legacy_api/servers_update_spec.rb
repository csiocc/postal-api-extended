# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Servers#update", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:admin_user) { create(:user, :admin) }
  let(:management_api_key) { create(:management_api_key, user: admin_user) }
  let(:target_server) { create(:server, organization: organization, name: "Original Server") }
  let(:other_organization) { create(:organization) }
  let(:foreign_server) { create(:server, organization: other_organization, name: "Foreign Server") }

  before do
    organization.update!(owner: admin_user)
  end

  def json_headers_for(api_key)
    {
      "X-Management-API-Key" => api_key,
      "Content-Type" => "application/json"
    }
  end

  it "allows cross-organization updates for management API keys" do
    patch "/api/v1/manage/servers/#{foreign_server.uuid}",
          params: { name: "Updated Server" }.to_json,
          headers: json_headers_for(management_api_key.key)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    foreign_server.reload
    expect(foreign_server.name).to eq("Updated Server")
  end

  it "updates the current organization server too" do
    patch "/api/v1/manage/servers/#{foreign_server.uuid}",
          params: { name: "Blocked Update" }.to_json,
          headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "server", "name")).to eq("Blocked Update")
  end

  it "returns parameter-error for invalid mode" do
    patch "/api/v1/manage/servers/#{target_server.uuid}",
          params: { mode: "InvalidMode" }.to_json,
          headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end
end
