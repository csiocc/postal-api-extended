# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ManagementAPI::Organizations#show', type: :request do
  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user, :admin) }
  let(:management_api_key) { create(:management_api_key, user: admin_user) }
  let(:other_organization) { create(:organization) }

  before do
    organization.update!(owner: admin_user)
  end

  it 'allows cross-organization reads for admin credentials' do
    get "/api/v1/manage/organizations/#{other_organization.uuid}",
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('success')
    expect(json.dig('data', 'organization', 'uuid')).to eq(other_organization.uuid)
  end

  it 'returns organization details for the owned organization' do
    get "/api/v1/manage/organizations/#{organization.uuid}",
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('success')
    expect(json.dig('data', 'organization', 'uuid')).to eq(organization.uuid)
  end

  it 'returns not found for unknown organizations' do
    get "/api/v1/manage/organizations/invalid-uuid",
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('error')
    expect(json.dig('data', 'code')).to eq('OrganizationNotFound')
  end
end
