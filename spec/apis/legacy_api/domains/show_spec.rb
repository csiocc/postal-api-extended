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
  let(:dkim_failed_domain) do
    create(:domain,
           owner: server,
           verified_at: Time.now,
           spf_status: "OK",
           dkim_status: "Missing",
           mx_status: "OK",
           return_path_status: "OK",
           dns_checked_at: Time.now)
  end
  let(:mx_failed_domain) do
    create(:domain,
           owner: server,
           verified_at: Time.now,
           spf_status: "OK",
           dkim_status: "OK",
           mx_status: "Invalid",
           return_path_status: "OK",
           dns_checked_at: Time.now)
  end
  let(:return_path_failed_domain) do
    create(:domain,
           owner: server,
           verified_at: Time.now,
           spf_status: "OK",
           dkim_status: "OK",
           mx_status: "OK",
           return_path_status: "Invalid",
           dns_checked_at: Time.now)
  end

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

  it "does not disclose foreign domains for admin credentials" do
    get "/api/v1/domains/#{foreign_domain.uuid}", headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("DomainNotFound")
  end

  it "does not disclose foreign domains for non-admin owners" do
    organization.update!(owner: create(:user, admin: false))

    get "/api/v1/domains/#{foreign_domain.uuid}", headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("DomainNotFound")
  end

  it "returns dkim failure reasons" do
    get "/api/v1/domains/#{dkim_failed_domain.uuid}", headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json.dig("data", "domain", "status_reason")).to eq("dkim_missing")
  end

  it "returns mx failure reasons" do
    get "/api/v1/domains/#{mx_failed_domain.uuid}", headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json.dig("data", "domain", "status_reason")).to eq("mx_invalid")
  end

  it "returns return-path failure reasons" do
    get "/api/v1/domains/#{return_path_failed_domain.uuid}", headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json.dig("data", "domain", "status_reason")).to eq("return_path_invalid")
  end
end
