# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Domains#destroy", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:management_api_key) { create(:management_api_key, user: admin_user) }
  let(:organization) { create(:organization, owner: admin_user) }
  let(:server) { create(:server, organization: organization) }
  let!(:domain) { create(:domain, owner: server, name: "destroy-domain.example") }
  let(:other_organization) { create(:organization) }
  let(:other_server) { create(:server, organization: other_organization) }
  let!(:foreign_domain) { create(:domain, owner: other_server, name: "foreign-destroy-domain.example") }

  it "deletes local domains" do
    expect do
      delete "/api/v1/manage/domains/#{domain.uuid}",
             headers: management_api_headers(management_api_key)
    end.to change(Domain, :count).by(-1)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
  end

  it "deletes foreign domains for management API keys" do
    expect do
      delete "/api/v1/manage/domains/#{foreign_domain.uuid}",
             headers: management_api_headers(management_api_key)
    end.to change(Domain, :count).by(-1)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
  end
end
