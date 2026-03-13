# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ManagementAPI::Organizations#index', type: :request do
  let(:api_user) { create(:user, admin: true) }
  let!(:organization) { create(:organization, owner: api_user) }
  let!(:server) { create(:server, organization: organization) }
  let!(:credential) { create(:credential, server: server) }
  let!(:other_organization) { create(:organization) }

  it 'allows cross-organization listing for admin credentials' do
    get '/api/v1/manage/organizations', headers: { 'X-Server-API-Key' => credential.key }

    json = JSON.parse(response.body)
    organizations = json.dig('data', 'organizations')

    expect(json['status']).to eq('success')
    expect(organizations).to be_an(Array)
    expect(organizations.map { |org| org['uuid'] }).to include(other_organization.uuid)
  end

  it 'returns scoped organizations for non-admin owners' do
    non_admin_user = create(:user, admin: false)
    scoped_organization = create(:organization, owner: non_admin_user)
    scoped_server = create(:server, organization: scoped_organization)
    scoped_credential = create(:credential, server: scoped_server)
    create(:organization)

    get '/api/v1/manage/organizations', headers: { 'X-Server-API-Key' => scoped_credential.key }

    json = JSON.parse(response.body)
    organizations = json.dig('data', 'organizations')

    expect(json['status']).to eq('success')
    expect(organizations.map { |org| org['uuid'] }).to contain_exactly(scoped_organization.uuid)
  end

  it "returns AccessDenied when the credential has no user context" do
    organization.update_column(:owner_id, nil)

    get "/api/v1/manage/organizations", headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("AccessDenied")
  end
end
