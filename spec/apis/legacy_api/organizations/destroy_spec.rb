# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'LegacyAPI::Organizations#destroy', type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }

  let(:admin_user) { create(:user, admin: true) }
  let(:other_organization) { create(:organization) }

  before do
    organization.update!(owner: admin_user)
  end

  it 'allows cross-organization deletion for admin credentials' do
    delete "/api/v1/organizations/#{other_organization.uuid}",
           headers: { 'X-Server-API-Key' => credential.key }

    json = JSON.parse(response.body)
    expect(json['status']).to eq('success')
    expect(other_organization.reload.deleted_at).to be_present
  end

  it 'denies deletion for non-admin owners' do
    organization.update!(owner: create(:user, admin: false))

    delete "/api/v1/organizations/#{organization.uuid}",
           headers: { 'X-Server-API-Key' => credential.key }

    json = JSON.parse(response.body)
    expect(json['status']).to eq('error')
    expect(json.dig('data', 'code')).to eq('AccessDenied')
    expect(organization.reload.deleted_at).to be_nil
  end
end
