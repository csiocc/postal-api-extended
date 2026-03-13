# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ManagementAPI::Domains#update", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }
  let(:domain) { create(:domain, owner: server, name: "update-domain.example") }

  let(:admin_user) { create(:user, admin: true) }
  let(:other_organization) { create(:organization) }
  let(:other_server) { create(:server, organization: other_organization) }
  let(:foreign_domain) { create(:domain, owner: other_server, name: "foreign-domain.example") }

  before do
    organization.update!(owner: admin_user)
  end

  def json_headers_for(api_key)
    {
      "X-Server-API-Key" => api_key,
      "Content-Type" => "application/json"
    }
  end

  it "updates domain attributes in scope" do
    patch "/api/v1/manage/domains/#{domain.uuid}",
          params: { name: "updated-domain.example", use_for_any: true, outgoing: false }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)

    expect(json["status"]).to eq("success")
    expect(json.dig("data", "domain", "name")).to eq("updated-domain.example")
    expect(json.dig("data", "domain", "use_for_any")).to eq(true)
    expect(json.dig("data", "domain", "outgoing")).to eq(false)
  end

  it "rotates DKIM key when requested" do
    previous_key = domain.dkim_private_key

    patch "/api/v1/manage/domains/#{domain.uuid}",
          params: { rotate_dkim_key: true }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    domain.reload
    expect(domain.dkim_private_key).not_to eq(previous_key)
  end

  it "accepts numeric boolean values on update" do
    patch "/api/v1/manage/domains/#{domain.uuid}",
          params: { outgoing: 1, incoming: 0, use_for_any: 1 }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")

    domain.reload
    expect(domain.outgoing).to eq(true)
    expect(domain.incoming).to eq(false)
    expect(domain.use_for_any).to eq(true)
  end

  it "returns parameter-error for invalid verification methods" do
    patch "/api/v1/manage/domains/#{domain.uuid}",
          params: { verification_method: "Broken" }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end

  it "returns parameter-error for invalid boolean fields" do
    patch "/api/v1/manage/domains/#{domain.uuid}",
          params: { rotate_dkim_key: "maybe" }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end

  it "does not disclose foreign domains for non-admin owners" do
    organization.update!(owner: create(:user, admin: false))

    patch "/api/v1/manage/domains/#{foreign_domain.uuid}",
          params: { name: "blocked.example" }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("DomainNotFound")
  end

  it "does not disclose foreign domains for admin credentials either" do
    patch "/api/v1/manage/domains/#{foreign_domain.uuid}",
          params: { name: "blocked.example" }.to_json,
          headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("DomainNotFound")
  end
end
