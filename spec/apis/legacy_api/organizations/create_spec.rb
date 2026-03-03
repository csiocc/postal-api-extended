# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'LegacyAPI::Organizations#create', type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }
  let(:global_admin_credential) do
    create(:credential,
           server: server,
           options: { 'global_admin' => true })
  end

  let(:admin_user) { create(:user, admin: true) }

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

  it 'denies access for non-global credentials' do
    expect do
      post '/api/v1/organizations',
           params: valid_params.to_json,
           headers: json_headers_for(credential.key)
    end.not_to change(Organization, :count)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('error')
    expect(json.dig('data', 'code')).to eq('AccessDenied')
  end

  it 'returns parameter-error for invalid permalink with global-admin credentials' do
    invalid_params = valid_params.merge(permalink: 'BAD_PERMALINK')

    post '/api/v1/organizations',
         params: invalid_params.to_json,
         headers: json_headers_for(global_admin_credential.key)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('parameter-error')
  end

  it 'allows organization creation for global-admin credentials' do
    global_admin_params = valid_params.merge(
      name: 'global admin org',
      permalink: 'global-admin-org'
    )

    expect do
      post '/api/v1/organizations',
           params: global_admin_params.to_json,
           headers: json_headers_for(global_admin_credential.key)
    end.to change(Organization, :count).by(1)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('success')
    expect(json.dig('data', 'organization', 'permalink')).to eq('global-admin-org')
  end

end
