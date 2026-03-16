# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Domains#show", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:management_api_key) { create(:management_api_key, user: admin_user) }
  let(:organization) { create(:organization, owner: admin_user) }
  let(:server) { create(:server, organization: organization) }
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

  it "returns local domain details" do
    get "/api/v1/manage/domains/#{scoped_domain.uuid}", headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "domain", "uuid")).to eq(scoped_domain.uuid)
    expect(json.dig("data", "domain", "dns", "spf", "record_type")).to eq("TXT")
  end

  it "allows cross-organization domain reads" do
    get "/api/v1/manage/domains/#{foreign_domain.uuid}", headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "domain", "uuid")).to eq(foreign_domain.uuid)
  end

  it "returns dkim failure reasons" do
    get "/api/v1/manage/domains/#{dkim_failed_domain.uuid}", headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json.dig("data", "domain", "status_reason")).to eq("dkim_missing")
  end

  it "returns mx failure reasons" do
    get "/api/v1/manage/domains/#{mx_failed_domain.uuid}", headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json.dig("data", "domain", "status_reason")).to eq("mx_invalid")
  end

  it "returns return-path failure reasons" do
    get "/api/v1/manage/domains/#{return_path_failed_domain.uuid}", headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json.dig("data", "domain", "status_reason")).to eq("return_path_invalid")
  end
end
