# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Domains#index", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }

  let(:admin_user) { create(:user, admin: true) }
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

  before do
    organization.update!(owner: admin_user)
  end

  it "returns only domains from the credential organization for admin credentials" do
    get "/api/v1/manage/domains", headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    names = json.dig("data", "domains").map { |domain_data| domain_data["name"] }

    expect(json["status"]).to eq("success")
    expect(names).to include(server_domain.name, organization_domain.name)
    expect(names).not_to include(other_org_domain.name)
  end

  it "returns only scoped domains for non-admin owners" do
    organization.update!(owner: create(:user, admin: false))

    get "/api/v1/manage/domains", headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    names = json.dig("data", "domains").map { |domain_data| domain_data["name"] }

    expect(json["status"]).to eq("success")
    expect(names).to include(server_domain.name, organization_domain.name)
    expect(names).not_to include(other_org_domain.name)
  end

  it "does not include domains from assigned organizations outside the credential organization" do
    non_admin_user = create(:user, admin: false)
    organization.update!(owner: non_admin_user)
    OrganizationUser.create!(organization: other_organization, user: non_admin_user, admin: false, all_servers: true)

    get "/api/v1/manage/domains", headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    names = json.dig("data", "domains").map { |domain_data| domain_data["name"] }

    expect(json["status"]).to eq("success")
    expect(names).not_to include(other_org_domain.name)
  end

  it "filters by scope=organization" do
    get "/api/v1/manage/domains",
        params: { scope: "organization" },
        headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    names = json.dig("data", "domains").map { |domain_data| domain_data["name"] }

    expect(json["status"]).to eq("success")
    expect(names).to eq([organization_domain.name])
  end

  it "returns parameter-error for invalid scope filters" do
    get "/api/v1/manage/domains",
        params: { scope: "team" },
        headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
    expect(json.dig("data", "message")).to eq("scope must be one of: server, organization")
  end

  it "filters by server_id within scope" do
    get "/api/v1/manage/domains",
        params: { server_id: server.id },
        headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    names = json.dig("data", "domains").map { |domain_data| domain_data["name"] }

    expect(json["status"]).to eq("success")
    expect(names).to include(server_domain.name, verified_domain.name, failed_domain.name)
    expect(names).not_to include(organization_domain.name)
  end

  it "returns access denied for out-of-scope server_id filter for non-admin owners" do
    organization.update!(owner: create(:user, admin: false))

    get "/api/v1/manage/domains",
        params: { server_id: other_server.id },
        headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("AccessDenied")
  end

  it "filters by organization_id within scope" do
    get "/api/v1/manage/domains",
        params: { organization_id: organization.id },
        headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    names = json.dig("data", "domains").map { |domain_data| domain_data["name"] }

    expect(json["status"]).to eq("success")
    expect(names).to eq([organization_domain.name])
  end

  it "filters by status=pending" do
    get "/api/v1/manage/domains",
        params: { status: "pending" },
        headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    names = json.dig("data", "domains").map { |domain_data| domain_data["name"] }

    expect(json["status"]).to eq("success")
    expect(names).to include(server_domain.name, organization_domain.name)
    expect(names).not_to include(verified_domain.name)
  end

  it "filters by status=pending_dns" do
    get "/api/v1/manage/domains",
        params: { status: "pending_dns" },
        headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    names = json.dig("data", "domains").map { |domain_data| domain_data["name"] }

    expect(json["status"]).to eq("success")
    expect(names).to contain_exactly(pending_dns_domain.name)
  end

  it "filters by status=verifying" do
    get "/api/v1/manage/domains",
        params: { status: "verifying" },
        headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "domains")).to eq([])
  end

  it "filters by status=verified" do
    get "/api/v1/manage/domains",
        params: { status: "verified" },
        headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    names = json.dig("data", "domains").map { |domain_data| domain_data["name"] }

    expect(json["status"]).to eq("success")
    expect(names).to eq([verified_domain.name])
  end

  it "filters by status=failed" do
    get "/api/v1/manage/domains",
        params: { status: "failed" },
        headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    names = json.dig("data", "domains").map { |domain_data| domain_data["name"] }

    expect(json["status"]).to eq("success")
    expect(names).to include(failed_domain.name)
    expect(names).not_to include(verified_domain.name)
  end

  it "returns parameter-error for invalid status filter" do
    get "/api/v1/manage/domains",
        params: { status: "unknown" },
        headers: { "X-Server-API-Key" => credential.key }

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end
end
