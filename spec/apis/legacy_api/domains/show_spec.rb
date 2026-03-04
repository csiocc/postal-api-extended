# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LegacyAPI::Domains#show", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }

  let(:admin_user) { create(:user, admin: true) }
  let(:other_organization) { create(:organization) }
  let(:other_server) { create(:server, organization: other_organization) }
  let(:scoped_domain) { create(:domain, owner: server) }
  let(:foreign_domain) { create(:domain, owner: other_server) }

  before do
    organization.update!(owner: admin_user)
  end

  it "returns domain details inside the credential scope" do
    get "/api/v1/domains/#{scoped_domain.uuid}", headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)

    expect(json["status"]).to eq("success")
    expect(json.dig("data", "domain", "uuid")).to eq(scoped_domain.uuid)
    expect(json.dig("data", "domain", "dns", "spf", "record_type")).to eq("TXT")
  end

  it "allows cross-organization reads for admin credentials" do
    get "/api/v1/domains/#{foreign_domain.uuid}", headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "domain", "uuid")).to eq(foreign_domain.uuid)
  end

  it "does not disclose foreign domains for non-admin owners" do
    organization.update!(owner: create(:user, admin: false))

    get "/api/v1/domains/#{foreign_domain.uuid}", headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("DomainNotFound")
  end
end
