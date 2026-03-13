# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Credentials#create", type: :request do
  let(:organization) { create(:organization) }
  let!(:server) { create(:server, organization: organization) }
  let!(:credential) { create(:credential, server: server) }

  let(:admin_user) { create(:user, admin: true) }
  let(:other_organization) { create(:organization) }
  let!(:other_server) { create(:server, organization: other_organization) }

  before do
    organization.update!(owner: admin_user)
  end

  let(:valid_params) do
    {
      type: "API",
      name: "API Credential"
    }
  end

  def json_headers_for(api_key)
    {
      "X-Server-API-Key" => api_key,
      "Content-Type" => "application/json"
    }
  end

  it "denies creating a credential on a foreign server for admin credentials" do
    expect do
      post "/api/v1/manage/credentials",
           params: valid_params.merge(server_id: other_server.id).to_json,
           headers: json_headers_for(credential.key)
    end.not_to change(Credential, :count)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("AccessDenied")
  end

  it "denies creating credentials on foreign servers for non-admin owners" do
    organization.update!(owner: create(:user, admin: false))

    out_of_scope_params = valid_params.merge(server_id: other_server.id)

    expect do
      post "/api/v1/manage/credentials",
           params: out_of_scope_params.to_json,
           headers: json_headers_for(credential.key)
    end.not_to change(Credential, :count)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("AccessDenied")
  end

  it "creates credentials on the current server for non-admin owners" do
    organization.update!(owner: create(:user, admin: false))
    post "/api/v1/manage/credentials",
         params: valid_params.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    created_credential = Credential.find_by!(uuid: json.dig("data", "credential", "uuid"))
    expect(created_credential.server_id).to eq(server.id)
  end

  it "allows explicitly targeting the current server by server_id" do
    post "/api/v1/manage/credentials",
         params: valid_params.merge(server_id: server.id).to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    created_credential = Credential.find_by!(uuid: json.dig("data", "credential", "uuid"))
    expect(created_credential.server_id).to eq(server.id)
  end

  it "accepts numeric hold values" do
    post "/api/v1/manage/credentials",
         params: valid_params.merge(name: "Held Credential", hold: 1).to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "credential", "hold")).to eq(true)
  end

  it "returns parameter-error for invalid server_id" do
    post "/api/v1/manage/credentials",
         params: valid_params.merge(server_id: "abc").to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("server_id must be an integer")
  end

  it "returns ServerNotFound for unknown server_id" do
    post "/api/v1/manage/credentials",
         params: valid_params.merge(server_id: 9_999_999).to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("ServerNotFound")
  end

  it "defaults type to SMTP when no type is provided" do
    params_without_type = { name: "Default SMTP Credential" }

    post "/api/v1/manage/credentials",
         params: params_without_type.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    created_credential = Credential.find_by!(uuid: json.dig("data", "credential", "uuid"))
    expect(created_credential.type).to eq("SMTP")
  end

  it "returns parameter-error for invalid type" do
    invalid_params = valid_params.merge(type: "BROKEN")

    post "/api/v1/manage/credentials",
         params: invalid_params.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end

  it "returns parameter-error for malformed JSON payloads" do
    post "/api/v1/manage/credentials",
         params: '{"name":"broken-json"',
         headers: json_headers_for(credential.key)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("Request body must contain valid JSON.")
  end

  it "returns AccessDenied when the credential has no user context" do
    organization.update_column(:owner_id, nil)

    post "/api/v1/manage/credentials",
         params: valid_params.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("AccessDenied")
  end
end
