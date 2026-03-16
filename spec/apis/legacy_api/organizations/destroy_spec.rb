# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ManagementAPI::Organizations#destroy', type: :request do
  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user, :admin) }
  let(:management_api_key) { create(:management_api_key, user: admin_user) }
  let(:other_organization) { create(:organization) }

  before do
    organization.update!(owner: admin_user)
  end

  it 'allows cross-organization deletion for admin credentials' do
    delete "/api/v1/manage/organizations/#{other_organization.uuid}",
           headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('success')
    expect(other_organization.reload.deleted_at).to be_present
  end

  it 'rejects revoked management keys' do
    management_api_key.revoke!
    delete "/api/v1/manage/organizations/#{organization.uuid}",
           headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('error')
    expect(json.dig('data', 'code')).to eq('ManagementAPIKeyRevoked')
    expect(organization.reload.deleted_at).to be_nil
  end
end
