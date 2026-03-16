# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Credentials#destroy", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:management_api_key) { create(:management_api_key, user: admin_user) }
  let(:organization) { create(:organization, owner: admin_user) }
  let(:server) { create(:server, organization: organization) }
  let!(:target_credential) { create(:credential, server: server) }
  let(:other_organization) { create(:organization) }
  let!(:foreign_server) { create(:server, organization: other_organization) }
  let!(:foreign_credential) { create(:credential, server: foreign_server) }

  it "deletes foreign credentials for management API keys" do
    expect do
      delete "/api/v1/manage/credentials/#{foreign_credential.uuid}",
             headers: management_api_headers(management_api_key)
    end.to change(Credential, :count).by(-1)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
  end

  it "deletes local credentials too" do
    expect do
      delete "/api/v1/manage/credentials/#{target_credential.uuid}",
             headers: management_api_headers(management_api_key)
    end.to change(Credential, :count).by(-1)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
  end

  it "returns error for non-existent credential" do
    delete "/api/v1/manage/credentials/invalid-uuid",
           headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("CredentialNotFound")
  end
end
