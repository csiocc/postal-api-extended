# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LegacyAPI::Credentials#destroy", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let!(:credential) { create(:credential, server: server) }

  let(:admin_user) { create(:user, admin: true) }
  let!(:target_credential) { create(:credential, server: server) }
  let(:other_organization) { create(:organization) }
  let!(:foreign_server) { create(:server, organization: other_organization) }
  let!(:foreign_credential) { create(:credential, server: foreign_server) }

  before do
    organization.update!(owner: admin_user)
  end

  it "does not delete foreign credentials for admin credentials" do
    expect do
      delete "/api/v1/credentials/#{foreign_credential.uuid}",
             headers: { "X-Server-API-Key" => credential.key }
    end.not_to change(Credential, :count)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("CredentialNotFound")
  end

  it "blocks cross-organization deletion for non-admin owners" do
    organization.update!(owner: create(:user, admin: false))

    expect do
      delete "/api/v1/credentials/#{foreign_credential.uuid}",
             headers: { "X-Server-API-Key" => credential.key }
    end.not_to change(Credential, :count)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("CredentialNotFound")
  end

  it "allows scoped deletion for non-admin owners" do
    organization.update!(owner: create(:user, admin: false))

    expect do
      delete "/api/v1/credentials/#{target_credential.uuid}",
             headers: { "X-Server-API-Key" => credential.key }
    end.to change(Credential, :count).by(-1)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
  end

  it "returns error for non-existent credential" do
    delete "/api/v1/credentials/invalid-uuid",
           headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("CredentialNotFound")
  end
end
