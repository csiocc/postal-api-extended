# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Credentials#show", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:management_api_key) { create(:management_api_key, user: admin_user) }
  let(:organization) { create(:organization, owner: admin_user) }
  let(:server) { create(:server, organization: organization) }
  let(:target_credential) { create(:credential, server: server) }
  let(:other_organization) { create(:organization) }
  let(:foreign_server) { create(:server, organization: other_organization) }
  let(:foreign_credential) { create(:credential, server: foreign_server) }

  it "returns credential details for local credentials" do
    get "/api/v1/manage/credentials/#{target_credential.uuid}",
        headers: management_api_headers(management_api_key)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "credential", "uuid")).to eq(target_credential.uuid)
  end

  it "allows cross-organization credential reads for management API keys" do
    get "/api/v1/manage/credentials/#{foreign_credential.uuid}",
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "credential", "uuid")).to eq(foreign_credential.uuid)
  end

  it "returns not found for unknown credentials" do
    get "/api/v1/manage/credentials/invalid-uuid",
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("CredentialNotFound")
  end
end
