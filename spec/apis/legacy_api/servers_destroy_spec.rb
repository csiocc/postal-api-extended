# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Servers#destroy", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization, name: "Credential Server") }
  let(:admin_user) { create(:user, :admin) }
  let(:management_api_key) { create(:management_api_key, user: admin_user) }
  let(:target_server) { create(:server, organization: organization, name: "Target Server") }
  let(:other_organization) { create(:organization) }
  let(:foreign_server) { create(:server, organization: other_organization) }

  before do
    organization.update!(owner: admin_user)
  end

  it "soft deletes a server inside the credential organization" do
    delete "/api/v1/manage/servers/#{target_server.uuid}",
           headers: management_api_headers(management_api_key)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(target_server.reload.deleted_at).to be_present
  end

  it "soft deletes foreign servers for management API keys" do
    delete "/api/v1/manage/servers/#{foreign_server.uuid}",
           headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(foreign_server.reload.deleted_at).to be_present
  end

  it "returns error for non-existent server" do
    delete "/api/v1/manage/servers/invalid-uuid",
           headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("ServerNotFound")
  end
end
