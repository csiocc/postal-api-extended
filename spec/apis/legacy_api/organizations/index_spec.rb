# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'LegacyAPI::Organizations#index', type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }

  let(:admin_user) { create(:user, admin: true) }
  let(:other_organization) { create(:organization) }

  before do
    organization.update!(owner: admin_user)
  end

  it 'allows cross-organization listing for admin credentials' do
    get '/api/v1/organizations', headers: { 'X-Server-API-Key' => credential.key }

    json = JSON.parse(response.body)
    organizations = json.dig('data', 'organizations')

    expect(json['status']).to eq('success')
    expect(organizations).to be_an(Array)
    expect(organizations.map { |org| org['uuid'] }).to include(other_organization.uuid)
  end

  it 'returns scoped organizations for non-admin owners' do
    organization.update!(owner: create(:user, admin: false))

    get '/api/v1/organizations', headers: { 'X-Server-API-Key' => credential.key }

    json = JSON.parse(response.body)
    organizations = json.dig('data', 'organizations')

    expect(json['status']).to eq('success')
    expect(organizations.map { |org| org['uuid'] }).to contain_exactly(organization.uuid)
  end

end
