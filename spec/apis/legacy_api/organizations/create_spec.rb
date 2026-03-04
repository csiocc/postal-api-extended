# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'LegacyAPI::Organizations#create', type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }

  let(:admin_user) { create(:user, admin: true) }
  let(:other_owner) { create(:user, admin: false) }

  before do
    organization.update!(owner: admin_user)
  end

  let(:valid_params) do
    {
      name: 'test org',
      permalink: 'test-org',
      time_zone: 'UTC'
    }
  end

  def json_headers_for(api_key)
    {
      'X-Server-API-Key' => api_key,
      'Content-Type' => 'application/json'
    }
  end

  it 'allows organization creation for admin credentials' do
    admin_params = valid_params.merge(
      name: 'admin created org',
      permalink: 'admin-created-org',
      owner_uuid: other_owner.uuid
    )

    expect do
      post '/api/v1/organizations',
           params: admin_params.to_json,
           headers: json_headers_for(credential.key)
    end.to change(Organization, :count).by(1)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('success')
    expect(json.dig('data', 'organization', 'permalink')).to eq('admin-created-org')

    created_organization = Organization.find_by!(uuid: json.dig('data', 'organization', 'uuid'))
    expect(created_organization.owner_id).to eq(other_owner.id)
  end

  it 'denies organization creation for non-admin owners' do
    organization.update!(owner: create(:user, admin: false))

    expect do
      post '/api/v1/organizations',
           params: valid_params.to_json,
           headers: json_headers_for(credential.key)
    end.not_to change(Organization, :count)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('error')
    expect(json.dig('data', 'code')).to eq('AccessDenied')
  end

  it 'returns parameter-error for invalid permalink with admin credentials' do
    invalid_params = valid_params.merge(permalink: 'BAD_PERMALINK')

    post '/api/v1/organizations',
         params: invalid_params.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('parameter-error')
  end

  it 'returns UserNotFound when owner_uuid does not exist' do
    invalid_owner_params = valid_params.merge(
      name: 'invalid owner org',
      permalink: 'invalid-owner-org',
      owner_uuid: '00000000-0000-0000-0000-000000000000'
    )

    expect do
      post '/api/v1/organizations',
           params: invalid_owner_params.to_json,
           headers: json_headers_for(credential.key)
    end.not_to change(Organization, :count)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('error')
    expect(json.dig('data', 'code')).to eq('UserNotFound')
  end

end
