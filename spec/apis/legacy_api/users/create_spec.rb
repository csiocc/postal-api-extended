# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "LegacyAPI::Users#create", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }
  let(:admin_user) { create(:user, admin: true) }

  before do
    organization.update(owner: admin_user)
  end

  let(:valid_params) do
    {
      email_address: "newuser@test.com",
      first_name: "Test",
      last_name: "User",
      password: "password123",
      password_confirmation: "password123"
    }
  end

  it "creates a new user with valid parameters" do
    expect {
      post "/api/v1/users",
           params: valid_params.to_json,
           headers: {
             "X-Server-API-Key" => credential.key,
             "Content-Type" => "application/json"
           }
    }.to change(User, :count).by(1)

    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json["data"]["user"]["email_address"]).to eq("newuser@test.com")
  end

  it "returns error for invalid email" do
    invalid_params = valid_params.merge(email_address: "invalid-email")
    
    post "/api/v1/users",
         params: invalid_params.to_json,
         headers: {
           "X-Server-API-Key" => credential.key,
           "Content-Type" => "application/json"
         }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end

  it "returns error for password mismatch" do
    invalid_params = valid_params.merge(password_confirmation: "different")
    
    post "/api/v1/users",
         params: invalid_params.to_json,
         headers: {
           "X-Server-API-Key" => credential.key,
           "Content-Type" => "application/json"
         }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end
end
