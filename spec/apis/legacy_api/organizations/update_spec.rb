# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ManagementAPI::Organizations#update', type: :request do
  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user, :admin) }
  let(:management_api_key) { create(:management_api_key, user: admin_user) }
  let(:other_organization) { create(:organization) }

  before do
    organization.update!(owner: admin_user)
  end

  def json_headers_for(api_key)
    {
      'X-Management-API-Key' => api_key,
      'Content-Type' => 'application/json'
    }
  end

  it 'allows cross-organization updates for admin credentials' do
    patch "/api/v1/manage/organizations/#{other_organization.uuid}",
          params: { name: 'Global Updated' }.to_json,
          headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('success')
    expect(json.dig('data', 'organization', 'name')).to eq('Global Updated')

    other_organization.reload
    expect(other_organization.name).to eq('Global Updated')
  end

  it 'updates the current organization too' do
    patch "/api/v1/manage/organizations/#{organization.uuid}",
          params: { name: 'Scoped Updated', time_zone: 'Europe/Zurich' }.to_json,
          headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json['status']).to eq('success')
    expect(json.dig('data', 'organization', 'name')).to eq('Scoped Updated')
  end

  it "returns parameter-error when the update is invalid" do
    patch "/api/v1/manage/organizations/#{organization.uuid}",
          params: { name: "" }.to_json,
          headers: json_headers_for(management_api_key.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to include("Name can't be blank").or include("name can't be blank")
  end
end
