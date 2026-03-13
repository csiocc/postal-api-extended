# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Servers#create", type: :request do
  let(:organization) { create(:organization) }
  let!(:server) { create(:server, organization: organization) }
  let!(:credential) { create(:credential, server: server) }

  let(:admin_user) { create(:user, admin: true) }
  let(:other_organization) { create(:organization) }

  before do
    organization.update!(owner: admin_user)
  end

  let(:valid_params) do
    {
      name: "API Server",
      permalink: "api-server",
      mode: "Live",
      organization_id: organization.id
    }
  end

  def json_headers_for(api_key)
    {
      "X-Server-API-Key" => api_key,
      "Content-Type" => "application/json"
    }
  end

  it "denies creating a server outside the credential organization for admin credentials" do
    expect do
      post "/api/v1/manage/servers",
           params: valid_params.merge(
             name: "Cross Org Server",
             permalink: "cross-org-server",
             organization_id: other_organization.id
           ).to_json,
           headers: json_headers_for(credential.key)
    end.not_to change(Server, :count)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("AccessDenied")
  end

  it "denies creating a server outside scope for non-admin owners" do
    organization.update!(owner: create(:user, admin: false))

    out_of_scope_params = valid_params.merge(
      name: "Other Org Server",
      permalink: "other-org-server",
      organization_id: other_organization.id
    )

    expect do
      post "/api/v1/manage/servers",
           params: out_of_scope_params.to_json,
           headers: json_headers_for(credential.key)
    end.not_to change(Server, :count)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("AccessDenied")
  end

  it "allows creating a server in the current organization for non-admin owners" do
    organization.update!(owner: create(:user, admin: false))
    post "/api/v1/manage/servers",
         params: valid_params.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    created_server = Server.find_by!(uuid: json.dig("data", "server", "uuid"))
    expect(created_server.organization_id).to eq(organization.id)
  end

  it "defaults to the credential organization when organization_id is omitted" do
    post "/api/v1/manage/servers",
         params: valid_params.except(:organization_id).merge(permalink: "default-org-server").to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    created_server = Server.find_by!(uuid: json.dig("data", "server", "uuid"))
    expect(created_server.organization_id).to eq(organization.id)
  end

  it "returns parameter-error for invalid organization_id" do
    post "/api/v1/manage/servers",
         params: valid_params.merge(organization_id: "abc").to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("organization_id must be an integer")
  end

  it "returns OrganizationNotFound for unknown organization_id" do
    post "/api/v1/manage/servers",
         params: valid_params.merge(organization_id: 9_999_999).to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("OrganizationNotFound")
  end

  it "returns parameter-error for invalid mode" do
    invalid_params = valid_params.merge(mode: "BrokenMode")

    post "/api/v1/manage/servers",
         params: invalid_params.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end

  it "returns parameter-error for malformed JSON payloads" do
    post "/api/v1/manage/servers",
         params: '{"name":"broken-json"',
         headers: json_headers_for(credential.key)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("Request body must contain valid JSON.")
  end

  it "returns AccessDenied when the credential has no user context" do
    organization.update_column(:owner_id, nil)

    post "/api/v1/manage/servers",
         params: valid_params.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("AccessDenied")
  end
end
