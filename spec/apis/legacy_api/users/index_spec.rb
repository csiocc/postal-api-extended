# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "LegacyAPI::Users#index", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }
  let(:global_admin_credential) do
    create(:credential,
           server: server,
           options: { "global_admin" => true })
  end

  let(:admin_user) { create(:user, admin: true) }
  let(:scoped_user) { create(:user, admin: false) }
  let(:other_organization) { create(:organization) }
  let(:other_org_user) { create(:user, admin: false) }

  before do
    organization.update!(owner: admin_user)
    scoped_user.organizations << organization
    other_org_user.organizations << other_organization
  end

  it "returns only users in the credential organization scope" do
    get "/api/v1/users", headers: { "X-Server-API-Key" => credential.key }

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    uuids = json["data"]["users"].map { |user| user["uuid"] }

    expect(json["status"]).to eq("success")
    expect(uuids).to include(admin_user.uuid, scoped_user.uuid)
    expect(uuids).not_to include(other_org_user.uuid)
    expect(json["data"]["total"]).to eq(uuids.size)
  end

  it "allows cross-organization listing for global-admin credentials" do
    get "/api/v1/users", headers: { "X-Server-API-Key" => global_admin_credential.key }

    json = JSON.parse(response.body)
    uuids = json["data"]["users"].map { |user| user["uuid"] }

    expect(json["status"]).to eq("success")
    expect(uuids).to include(other_org_user.uuid)
  end

  it "denies access to non-admin owners" do
    regular_owner = create(:user, admin: false)
    organization.update!(owner: regular_owner)

    get "/api/v1/users", headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("AccessDenied")
  end
end
