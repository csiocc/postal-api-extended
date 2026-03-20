# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Domains#index", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:management_api_key) { create(:management_api_key, user: admin_user) }
  let(:organization) { create(:organization, owner: admin_user) }
  let(:server) { create(:server, organization: organization) }
  let(:other_organization) { create(:organization) }
  let(:other_server) { create(:server, organization: other_organization) }

  let!(:server_domain) { create(:domain, :unverified, owner: server, name: "server-domain.example") }
  let!(:organization_domain) { create(:domain, :unverified, owner: organization, name: "organization-domain.example") }
  let!(:verified_domain) do
    create(:domain,
           owner: server,
           name: "verified-domain.example",
           verified_at: Time.now,
           spf_status: "OK",
           dkim_status: "OK",
           mx_status: "OK",
           return_path_status: "OK",
           dns_checked_at: Time.now)
  end
  let!(:pending_dns_domain) do
    create(:domain,
           owner: server,
           name: "pending-dns-domain.example",
           verified_at: Time.now,
           spf_status: nil,
           dns_checked_at: nil)
  end
  let!(:failed_domain) do
    create(:domain,
           owner: server,
           name: "failed-domain.example",
           verified_at: Time.now,
           spf_status: "Invalid",
           dkim_status: "OK",
           mx_status: "OK",
           return_path_status: "OK",
           dns_checked_at: Time.now)
  end
  let!(:other_org_domain) { create(:domain, owner: other_server, name: "other-org-domain.example") }

  it "returns domains across organizations for management API keys" do
    get "/api/v1/manage/domains", headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    names = json.dig("data", "domains").map { |domain_data| domain_data["name"] }

    expect(json["status"]).to eq("success")
    expect(names).to include(server_domain.name, organization_domain.name, other_org_domain.name)
  end

  it "paginates domains after filters are applied" do
    get "/api/v1/manage/domains",
        params: { scope: "server", page: 1, per_page: 2 },
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)

    expect(json["status"]).to eq("success")
    expect(json.dig("data", "domains").size).to eq(2)
    expect(json.dig("data", "total")).to eq(5)
    expect(json.dig("data", "pagination")).to eq(
      "page" => 1,
      "per_page" => 2,
      "total" => 5,
      "total_pages" => 3
    )
  end

  it "filters by scope=organization" do
    get "/api/v1/manage/domains",
        params: { scope: "organization" },
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    names = json.dig("data", "domains").map { |domain_data| domain_data["name"] }

    expect(json["status"]).to eq("success")
    expect(names).to include(organization_domain.name)
    expect(names).not_to include(server_domain.name)
  end

  it "returns parameter-error for invalid scope filters" do
    get "/api/v1/manage/domains",
        params: { scope: "team" },
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("scope must be one of: server, organization")
  end

  it "filters by server_id" do
    get "/api/v1/manage/domains",
        params: { server_id: server.id },
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    names = json.dig("data", "domains").map { |domain_data| domain_data["name"] }

    expect(json["status"]).to eq("success")
    expect(names).to include(server_domain.name, verified_domain.name, failed_domain.name)
    expect(names).not_to include(organization_domain.name)
  end

  it "filters by organization_id" do
    get "/api/v1/manage/domains",
        params: { organization_id: organization.id },
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    names = json.dig("data", "domains").map { |domain_data| domain_data["name"] }

    expect(json["status"]).to eq("success")
    expect(names).to eq([organization_domain.name])
  end

  it "filters by status=pending" do
    get "/api/v1/manage/domains",
        params: { status: "pending" },
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    names = json.dig("data", "domains").map { |domain_data| domain_data["name"] }

    expect(json["status"]).to eq("success")
    expect(names).to include(server_domain.name, organization_domain.name)
    expect(names).not_to include(verified_domain.name)
  end

  it "filters by status=pending_dns" do
    get "/api/v1/manage/domains",
        params: { status: "pending_dns" },
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    names = json.dig("data", "domains").map { |domain_data| domain_data["name"] }

    expect(json["status"]).to eq("success")
    expect(names).to include(pending_dns_domain.name, other_org_domain.name)
    expect(names).not_to include(server_domain.name, organization_domain.name, verified_domain.name, failed_domain.name)
  end

  it "filters by status=verifying" do
    get "/api/v1/manage/domains",
        params: { status: "verifying" },
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "domains")).to eq([])
  end

  it "filters by status=verified" do
    get "/api/v1/manage/domains",
        params: { status: "verified" },
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["data"]["domains"].map { |domain_data| domain_data["name"] }).to eq([verified_domain.name])
  end

  it "filters by status=failed" do
    get "/api/v1/manage/domains",
        params: { status: "failed" },
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    names = json.dig("data", "domains").map { |domain_data| domain_data["name"] }
    expect(names).to include(failed_domain.name)
    expect(names).not_to include(verified_domain.name)
  end

  it "returns parameter-error for invalid status filter" do
    get "/api/v1/manage/domains",
        params: { status: "unknown" },
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end

  it "returns parameter-error for oversized per_page" do
    get "/api/v1/manage/domains",
        params: { per_page: 101 },
        headers: management_api_headers(management_api_key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("per_page must be less than or equal to 100")
  end
end
