# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Credentials#show", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }

  let(:admin_user) { create(:user, admin: true) }
  let(:target_credential) { create(:credential, server: server) }
  let(:other_organization) { create(:organization) }
  let(:foreign_server) { create(:server, organization: other_organization) }
  let(:foreign_credential) { create(:credential, server: foreign_server) }

  before do
    organization.update!(owner: admin_user)
  end

  it "returns credential details inside the credential scope" do
    get "/api/v1/manage/credentials/#{target_credential.uuid}",
        headers: { "X-Server-API-Key" => credential.key }

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)

    expect(json["status"]).to eq("success")
    expect(json.dig("data", "credential", "uuid")).to eq(target_credential.uuid)
  end

  it "does not disclose foreign credentials for admin credentials" do
    get "/api/v1/manage/credentials/#{foreign_credential.uuid}",
        headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("CredentialNotFound")
  end

  it "does not disclose foreign credentials for non-admin owners" do
    organization.update!(owner: create(:user, admin: false))

    get "/api/v1/manage/credentials/#{foreign_credential.uuid}",
        headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("CredentialNotFound")
  end
end
