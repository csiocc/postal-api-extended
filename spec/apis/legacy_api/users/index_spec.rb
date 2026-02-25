# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "LegacyAPI::Users#index", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }
  let(:admin_user) { create(:user, admin: true) }
  let(:regular_user) { create(:user, admin: false) }

  before do
    organization.update(owner: admin_user)
  end

  it "returns all users" do
    create(:user, admin: false) # Ensure thers at least one more user
    
    get "/api/v1/users", headers: { "X-Server-API-Key" => credential.key }
    
    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json["data"]["users"]).to be_an(Array)
    expect(json["data"]["total"]).to be_a(Integer)
  end

  it "includes user details in response" do
    create(:user, admin: false)
    
    get "/api/v1/users", headers: { "X-Server-API-Key" => credential.key }
    
    json = JSON.parse(response.body)
    user = json["data"]["users"].first
    
    expect(user).to have_key("uuid")
    expect(user).to have_key("email_address")
    expect(user).to have_key("first_name")
    expect(user).to have_key("last_name")
    expect(user).to have_key("admin")
  end
  
  it "denies access to non-admin owners" do
    regular_owner = create(:user, admin: false)
    organization.update(owner: regular_owner)
    
    get "/api/v1/users", headers: { "X-Server-API-Key" => credential.key }
    
    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json["data"]["code"]).to eq("AccessDenied")
  end
end
