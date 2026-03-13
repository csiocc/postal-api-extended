# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'LegacyAPI::Users#create', type: :request do
  let(:api_user) { create(:user, admin: true) }
  let!(:organization) { create(:organization, owner: api_user) }
  let!(:server) { create(:server, organization: organization) }
  let!(:credential) { create(:credential, server: server) }
  let!(:other_organization) { create(:organization) }

  let(:email_address) { "newuser-#{SecureRandom.hex(4)}@test.com" }

  let(:valid_params) do
    {
      email_address: email_address,
      first_name: 'Test',
      last_name: 'User',
      password: 'password123',
      password_confirmation: 'password123',
      organization_ids: [organization.id, other_organization.id]
    }
  end

  def json_headers_for(api_key)
    {
      'X-Server-API-Key' => api_key,
      'Content-Type' => 'application/json'
    }
  end

  it 'creates a new user with cross-organization assignments for admin credentials' do
    expect do
      post '/api/v1/users',
           params: valid_params.to_json,
           headers: json_headers_for(credential.key)
    end.to change(User, :count).by(1)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json['status']).to eq('success')
    expect(json['data']['user']['email_address']).to eq(email_address)
    expect(json['data']['user']['organizations'].map { |org| org['uuid'] })
      .to contain_exactly(organization.uuid, other_organization.uuid)
  end

  it 'denies access for non-admin organization owners' do
    non_admin_user = create(:user, admin: false)
    non_admin_organization = create(:organization, owner: non_admin_user)
    non_admin_server = create(:server, organization: non_admin_organization)
    non_admin_credential = create(:credential, server: non_admin_server)

    expect do
      post '/api/v1/users',
           params: valid_params.to_json,
           headers: json_headers_for(non_admin_credential.key)
    end.not_to change(User, :count)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('error')
    expect(json['data']['code']).to eq('AccessDenied')
  end

  it 'returns parameter-error for invalid email' do
    invalid_params = valid_params.merge(email_address: 'invalid-email')

    post '/api/v1/users',
         params: invalid_params.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('parameter-error')
  end

  it 'returns parameter-error for password mismatch' do
    invalid_params = valid_params.merge(password_confirmation: 'different')

    post '/api/v1/users',
         params: invalid_params.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('parameter-error')
  end

  it "returns parameter-error for invalid admin values" do
    post "/api/v1/users",
         params: valid_params.merge(admin: "maybe").to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("admin must be a boolean")
  end

  it "accepts numeric admin values" do
    post "/api/v1/users",
         params: valid_params.merge(email_address: "admin-#{SecureRandom.hex(4)}@test.com", admin: 1).to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "user", "admin")).to eq(true)
  end

  it "returns parameter-error when organization_ids is not an array" do
    post "/api/v1/users",
         params: valid_params.merge(organization_ids: organization.id).to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("organization_ids must be an array of organization IDs")
  end

  it "returns parameter-error when organization_ids contains non-integers" do
    post "/api/v1/users",
         params: valid_params.merge(organization_ids: [organization.id, "abc"]).to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("organization_ids must contain only integer IDs")
  end

  it 'returns parameter-error for malformed JSON payloads' do
    post '/api/v1/users',
         params: '{"email_address":"broken-json"',
         headers: json_headers_for(credential.key)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json['status']).to eq('parameter-error')
    expect(json.dig('data', 'message')).to eq('Request body must contain valid JSON.')
  end
end
