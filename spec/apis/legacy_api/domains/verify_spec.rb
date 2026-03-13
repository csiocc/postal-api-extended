# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LegacyAPI::Domains#verify", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:credential) { create(:credential, server: server) }
  let(:domain) { create(:domain, owner: server, name: "verify-domain.example") }

  let(:admin_user) { create(:user, admin: true) }
  let(:other_organization) { create(:organization) }
  let(:other_server) { create(:server, organization: other_organization) }
  let(:foreign_domain) { create(:domain, owner: other_server, name: "foreign-verify-domain.example") }

  before do
    organization.update!(owner: admin_user)

    allow_any_instance_of(Domain).to receive(:check_dns) do |instance, _source|
      instance.update!(
        spf_status: "OK",
        dkim_status: "OK",
        mx_status: "OK",
        return_path_status: "OK",
        dns_checked_at: Time.now
      )
      true
    end
  end

  def json_headers_for(api_key)
    {
      "X-Server-API-Key" => api_key,
      "Content-Type" => "application/json"
    }
  end

  it "verifies DNS for domains in scope" do
    post "/api/v1/domains/#{domain.uuid}/verify",
         params: { force: true }.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("success")
    expect(json.dig("data", "domain", "uuid")).to eq(domain.uuid)
    expect(json.dig("data", "domain", "verification", "last_result")).to eq("passed")
  end

  it "returns parameter-error for invalid force values" do
    post "/api/v1/domains/#{domain.uuid}/verify",
         params: { force: "maybe" }.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("parameter-error")
  end

  it "does not disclose foreign domains for non-admin owners" do
    organization.update!(owner: create(:user, admin: false))

    post "/api/v1/domains/#{foreign_domain.uuid}/verify",
         params: { force: true }.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("DomainNotFound")
  end

  it "does not disclose foreign domains for admin credentials either" do
    post "/api/v1/domains/#{foreign_domain.uuid}/verify",
         params: { force: true }.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("DomainNotFound")
  end

  it "returns DomainVerificationFailed when verification raises" do
    allow(Rails.logger).to receive(:error)
    allow_any_instance_of(Domain).to receive(:check_dns).and_raise(StandardError, "resolver failed")

    post "/api/v1/domains/#{domain.uuid}/verify",
         params: { force: true }.to_json,
         headers: json_headers_for(credential.key)

    json = JSON.parse(response.body)
    expect(json["status"]).to eq("error")
    expect(json.dig("data", "code")).to eq("DomainVerificationFailed")
    expect(json.dig("data", "message")).to eq("Could not verify DNS records for this domain")
    expect(json.dig("data", "error")).to be_nil
    expect(Rails.logger).to have_received(:error).with(
      include("Legacy API domain verification failed"),
    )
  end
end
