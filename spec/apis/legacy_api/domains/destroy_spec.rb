# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Domains#destroy", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }

  let(:admin_user) { create(:user, admin: true) }
  let!(:domain) { create(:domain, owner: server, name: "destroy-domain.example") }

  let(:other_organization) { create(:organization) }
  let(:other_server) { create(:server, organization: other_organization) }
  let!(:foreign_domain) { create(:domain, owner: other_server, name: "foreign-destroy-domain.example") }

  before do
    organization.update!(owner: admin_user)
  end

  it "deletes domains in scope" do
    expect do
      delete "/api/v1/manage/domains/#{domain.uuid}",
             headers: { "X-Server-API-Key" => credential.key }
    end.to change(Domain, :count).by(-1)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
  end

  it "does not delete foreign domains for admin credentials" do
    expect do
      delete "/api/v1/manage/domains/#{foreign_domain.uuid}",
             headers: { "X-Server-API-Key" => credential.key }
    end.not_to change(Domain, :count)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("DomainNotFound")
  end

  it "does not disclose foreign domains for non-admin owners" do
    organization.update!(owner: create(:user, admin: false))

    expect do
      delete "/api/v1/manage/domains/#{foreign_domain.uuid}",
             headers: { "X-Server-API-Key" => credential.key }
    end.not_to change(Domain, :count)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("DomainNotFound")
  end
end
