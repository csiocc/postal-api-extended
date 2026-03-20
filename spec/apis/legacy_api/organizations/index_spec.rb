# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ManagementAPI::Organizations#index', type: :request do
  let(:api_user) { create(:user, :admin) }
  let!(:organization) { create(:organization, owner: api_user) }
  let!(:management_api_key) { create(:management_api_key, user: api_user) }
  let!(:other_organization) { create(:organization) }

  it 'allows cross-organization listing for management API keys' do
    get '/api/v1/manage/organizations', headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    organizations = json.dig('data', 'organizations')

    expect(json['status']).to eq('success')
    expect(organizations).to be_an(Array)
    expect(organizations.map { |org| org['uuid'] }).to include(other_organization.uuid)
  end

  it "paginates organizations" do
    get "/api/v1/manage/organizations",
        params: { per_page: 1, page: 2 },
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)

    expect(json["status"]).to eq("success")
    expect(json.dig("data", "organizations").size).to eq(1)
    expect(json.dig("data", "total")).to eq(2)
    expect(json.dig("data", "pagination")).to eq(
      "page" => 2,
      "per_page" => 1,
      "total" => 2,
      "total_pages" => 2
    )
  end

  it "rejects missing management auth" do
    get "/api/v1/manage/organizations"

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("AccessDenied")
  end
end
