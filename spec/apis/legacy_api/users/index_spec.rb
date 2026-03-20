# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Users#index", type: :request do
  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user, :admin) }
  let(:management_api_key) { create(:management_api_key, user: admin_user) }
  let(:scoped_user) { create(:user, admin: false) }
  let(:other_organization) { create(:organization) }
  let(:other_org_user) { create(:user, admin: false) }

  before do
    organization.update!(owner: admin_user)
    scoped_user.organizations << organization
    other_org_user.organizations << other_organization
  end

  it "returns users across organizations for admin management keys" do
    get "/api/v1/manage/users", headers: management_api_headers(management_api_key)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    uuids = json["data"]["users"].map { |user| user["uuid"] }

    expect(json["status"]).to eq("success")
    expect(uuids).to include(admin_user.uuid, scoped_user.uuid, other_org_user.uuid)
    expect(json["data"]["total"]).to eq(uuids.size)
  end

  it "paginates users" do
    get "/api/v1/manage/users",
        params: { page: 2, per_page: 2 },
        headers: management_api_headers(management_api_key)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)

    expect(json["status"]).to eq("success")
    expect(json.dig("data", "users").size).to eq(1)
    expect(json.dig("data", "total")).to eq(3)
    expect(json.dig("data", "pagination")).to eq(
      "page" => 2,
      "per_page" => 2,
      "total" => 3,
      "total_pages" => 2
    )
  end

  it "returns parameter-error for invalid pagination params" do
    get "/api/v1/manage/users",
        params: { page: 0, per_page: "abc" },
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("page must be greater than or equal to 1")
  end

  it "rejects server API keys on management routes" do
    server = create(:server, organization: organization)
    credential = create(:credential, server: server)

    get "/api/v1/manage/users", headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("AccessDenied")
  end

  it "rejects revoked management API keys" do
    management_api_key.revoke!

    get "/api/v1/manage/users", headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("ManagementAPIKeyRevoked")
  end
end
