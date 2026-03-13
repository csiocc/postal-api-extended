# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Users#index", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }

  let(:admin_user) { create(:user, admin: true) }
  let(:scoped_user) { create(:user, admin: false) }
  let(:other_organization) { create(:organization) }
  let(:other_org_user) { create(:user, admin: false) }

  before do
    organization.update!(owner: admin_user)
    scoped_user.organizations << organization
    other_org_user.organizations << other_organization
  end

  it "returns users across organizations for admin credentials" do
    get "/api/v1/manage/users", headers: { "X-Server-API-Key" => credential.key }

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    uuids = json["data"]["users"].map { |user| user["uuid"] }

    expect(json["status"]).to eq("success")
    expect(uuids).to include(admin_user.uuid, scoped_user.uuid, other_org_user.uuid)
    expect(json["data"]["total"]).to eq(uuids.size)
  end

  it "denies access to non-admin owners" do
    organization.update!(owner: create(:user, admin: false))

    get "/api/v1/manage/users", headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("AccessDenied")
  end
end
