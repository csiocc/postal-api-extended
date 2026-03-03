# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'LegacyAPI::Organizations#show', type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }
  let(:global_admin_credential) do
    create(:credential,
           server: server,
           options: { 'global_admin' => true })
  end

  let(:admin_user) { create(:user, admin: true) }
  let(:other_organization) { create(:organization) }

  before do
    organization.update!(owner: admin_user)
  end

  it 'denies access for non-global credentials' do
    get "/api/v1/organizations/#{organization.uuid}",
        headers: { 'X-Server-API-Key' => credential.key }

    json = JSON.parse(response.body)
    expect(json['status']).to eq('error')
    expect(json.dig('data', 'code')).to eq('AccessDenied')
  end

  it 'allows reads for global-admin credentials' do
    get "/api/v1/organizations/#{other_organization.uuid}",
        headers: { 'X-Server-API-Key' => global_admin_credential.key }

    json = JSON.parse(response.body)
    expect(json['status']).to eq('success')
    expect(json.dig('data', 'organization', 'uuid')).to eq(other_organization.uuid)
  end
end
