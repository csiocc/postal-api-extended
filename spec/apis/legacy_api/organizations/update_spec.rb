# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'LegacyAPI::Organizations#update', type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }

  let(:admin_user) { create(:user, admin: true) }
  let(:other_organization) { create(:organization) }

  before do
    organization.update!(owner: admin_user)
  end

  def json_headers_for(api_key)
    {
      'X-Server-API-Key' => api_key,
      'Content-Type' => 'application/json'
    }
  end

  it 'allows cross-organization updates for admin credentials' do
    patch "/api/v1/organizations/#{other_organization.uuid}",
          params: { name: 'Global Updated' }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('success')
    expect(json.dig('data', 'organization', 'name')).to eq('Global Updated')

    other_organization.reload
    expect(other_organization.name).to eq('Global Updated')
  end

  it 'allows scoped updates for non-admin owners' do
    organization.update!(owner: create(:user, admin: false))

    patch "/api/v1/organizations/#{organization.uuid}",
          params: { name: 'Scoped Updated', time_zone: 'Europe/Zurich' }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('success')
    expect(json.dig('data', 'organization', 'name')).to eq('Scoped Updated')
  end

  it 'does not disclose foreign organizations for non-admin owners' do
    organization.update!(owner: create(:user, admin: false))

    patch "/api/v1/organizations/#{other_organization.uuid}",
          params: { name: 'Blocked' }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('error')
    expect(json.dig('data', 'code')).to eq('OrganizationNotFound')
  end
end
