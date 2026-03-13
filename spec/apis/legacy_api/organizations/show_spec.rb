# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ManagementAPI::Organizations#show', type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }

  let(:admin_user) { create(:user, admin: true) }
  let(:other_organization) { create(:organization) }

  before do
    organization.update!(owner: admin_user)
  end

  it 'allows cross-organization reads for admin credentials' do
    get "/api/v1/manage/organizations/#{other_organization.uuid}",
        headers: { 'X-Server-API-Key' => credential.key }

    json = JSON.parse(response.body)
    expect(json['status']).to eq('success')
    expect(json.dig('data', 'organization', 'uuid')).to eq(other_organization.uuid)
  end

  it 'returns scoped reads for non-admin owners' do
    organization.update!(owner: create(:user, admin: false))

    get "/api/v1/manage/organizations/#{organization.uuid}",
        headers: { 'X-Server-API-Key' => credential.key }

    json = JSON.parse(response.body)
    expect(json['status']).to eq('success')
    expect(json.dig('data', 'organization', 'uuid')).to eq(organization.uuid)
  end

  it 'does not disclose foreign organizations for non-admin owners' do
    organization.update!(owner: create(:user, admin: false))

    get "/api/v1/manage/organizations/#{other_organization.uuid}",
        headers: { 'X-Server-API-Key' => credential.key }

    json = JSON.parse(response.body)
    expect(json['status']).to eq('error')
    expect(json.dig('data', 'code')).to eq('OrganizationNotFound')
  end
end
