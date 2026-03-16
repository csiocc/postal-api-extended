# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ManagementAPI::Organizations#create', type: :request do
  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user, :admin) }
  let(:management_api_key) { create(:management_api_key, user: admin_user) }
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
      'X-Management-API-Key' => api_key,
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
      post '/api/v1/manage/organizations',
           params: admin_params.to_json,
           headers: json_headers_for(management_api_key.key)
    end.to change(Organization, :count).by(1)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('success')
    expect(json.dig('data', 'organization', 'permalink')).to eq('admin-created-org')

    created_organization = Organization.find_by!(uuid: json.dig('data', 'organization', 'uuid'))
    expect(created_organization.owner_id).to eq(other_owner.id)
    expect(created_organization.organization_users.find_by(user: other_owner)).to have_attributes(
      admin: true,
      all_servers: true
    )
    expect(other_owner.organizations_scope).to include(created_organization)
  end

  it 'creates an owner membership when the current api user becomes the owner' do
    expect do
      post '/api/v1/manage/organizations',
           params: valid_params.merge(name: 'self owned org', permalink: 'self-owned-org').to_json,
           headers: json_headers_for(management_api_key.key)
    end.to change(Organization, :count).by(1)

    json = JSON.parse(response.body)
    created_organization = Organization.find_by!(uuid: json.dig('data', 'organization', 'uuid'))

    expect(created_organization.owner_id).to eq(admin_user.id)
    expect(created_organization.organization_users.find_by(user: admin_user)).to have_attributes(
      admin: true,
      all_servers: true
    )
  end

  it 'rejects revoked management keys' do
    management_api_key.revoke!
    post '/api/v1/manage/organizations',
         params: valid_params.to_json,
         headers: json_headers_for(management_api_key.key)
    json = JSON.parse(response.body)
    expect(json['status']).to eq('error')
    expect(json.dig('data', 'code')).to eq('ManagementAPIKeyRevoked')
  end

  it 'returns parameter-error for invalid permalink with admin credentials' do
    invalid_params = valid_params.merge(permalink: 'BAD_PERMALINK')

    post '/api/v1/manage/organizations',
         params: invalid_params.to_json,
         headers: json_headers_for(management_api_key.key)

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
      post '/api/v1/manage/organizations',
           params: invalid_owner_params.to_json,
           headers: json_headers_for(management_api_key.key)
    end.not_to change(Organization, :count)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('error')
    expect(json.dig('data', 'code')).to eq('UserNotFound')
  end

end
