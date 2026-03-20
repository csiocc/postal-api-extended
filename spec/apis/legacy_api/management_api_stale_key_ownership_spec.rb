# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Management API stale key ownership", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:management_api_key) { create(:management_api_key, user: admin_user) }

  let!(:organization) { create(:organization, owner: admin_user) }
  let!(:server) { create(:server, organization: organization) }
  let!(:target_user) { create(:user, first_name: "Target") }
  let!(:credential) { create(:credential, server: server) }
  let!(:domain) { create(:domain, owner: server, name: "stale-key-owner.example") }

  before do
    target_user.organizations << organization
  end

  def api_headers(raw_key)
    { "X-Management-API-Key" => raw_key }
  end

  def api_json_headers(raw_key)
    api_headers(raw_key).merge("Content-Type" => "application/json")
  end

  endpoint_definitions = [
    {
      name: "GET /api/v1/manage/users",
      request: lambda do |ctx, raw_key|
        ctx.get "/api/v1/manage/users", headers: ctx.api_headers(raw_key)
      end
    },
    {
      name: "POST /api/v1/manage/users",
      request: lambda do |ctx, raw_key|
        ctx.post "/api/v1/manage/users",
                 params: {
                   email_address: "new-user@example.com",
                   first_name: "New",
                   last_name: "User",
                   password: "password-123",
                   password_confirmation: "password-123"
                 }.to_json,
                 headers: ctx.api_json_headers(raw_key)
      end
    },
    {
      name: "GET /api/v1/manage/users/:uuid",
      request: lambda do |ctx, raw_key|
        ctx.get "/api/v1/manage/users/#{ctx.target_user.uuid}", headers: ctx.api_headers(raw_key)
      end
    },
    {
      name: "PATCH /api/v1/manage/users/:uuid",
      request: lambda do |ctx, raw_key|
        ctx.patch "/api/v1/manage/users/#{ctx.target_user.uuid}",
                  params: { first_name: "Updated" }.to_json,
                  headers: ctx.api_json_headers(raw_key)
      end
    },
    {
      name: "DELETE /api/v1/manage/users/:uuid",
      request: lambda do |ctx, raw_key|
        ctx.delete "/api/v1/manage/users/#{ctx.target_user.uuid}", headers: ctx.api_headers(raw_key)
      end
    },
    {
      name: "GET /api/v1/manage/organizations",
      request: lambda do |ctx, raw_key|
        ctx.get "/api/v1/manage/organizations", headers: ctx.api_headers(raw_key)
      end
    },
    {
      name: "POST /api/v1/manage/organizations",
      request: lambda do |ctx, raw_key|
        ctx.post "/api/v1/manage/organizations",
                 params: {
                   name: "New Org",
                   permalink: "new-org"
                 }.to_json,
                 headers: ctx.api_json_headers(raw_key)
      end
    },
    {
      name: "GET /api/v1/manage/organizations/:uuid",
      request: lambda do |ctx, raw_key|
        ctx.get "/api/v1/manage/organizations/#{ctx.organization.uuid}", headers: ctx.api_headers(raw_key)
      end
    },
    {
      name: "PATCH /api/v1/manage/organizations/:uuid",
      request: lambda do |ctx, raw_key|
        ctx.patch "/api/v1/manage/organizations/#{ctx.organization.uuid}",
                  params: { name: "Updated Org" }.to_json,
                  headers: ctx.api_json_headers(raw_key)
      end
    },
    {
      name: "DELETE /api/v1/manage/organizations/:uuid",
      request: lambda do |ctx, raw_key|
        ctx.delete "/api/v1/manage/organizations/#{ctx.organization.uuid}", headers: ctx.api_headers(raw_key)
      end
    },
    {
      name: "GET /api/v1/manage/servers",
      request: lambda do |ctx, raw_key|
        ctx.get "/api/v1/manage/servers", headers: ctx.api_headers(raw_key)
      end
    },
    {
      name: "POST /api/v1/manage/servers",
      request: lambda do |ctx, raw_key|
        ctx.post "/api/v1/manage/servers",
                 params: {
                   name: "New Server",
                   permalink: "new-server",
                   mode: "Live",
                   organization_id: ctx.organization.id
                 }.to_json,
                 headers: ctx.api_json_headers(raw_key)
      end
    },
    {
      name: "GET /api/v1/manage/servers/:uuid",
      request: lambda do |ctx, raw_key|
        ctx.get "/api/v1/manage/servers/#{ctx.server.uuid}", headers: ctx.api_headers(raw_key)
      end
    },
    {
      name: "PATCH /api/v1/manage/servers/:uuid",
      request: lambda do |ctx, raw_key|
        ctx.patch "/api/v1/manage/servers/#{ctx.server.uuid}",
                  params: { name: "Updated Server" }.to_json,
                  headers: ctx.api_json_headers(raw_key)
      end
    },
    {
      name: "DELETE /api/v1/manage/servers/:uuid",
      request: lambda do |ctx, raw_key|
        ctx.delete "/api/v1/manage/servers/#{ctx.server.uuid}", headers: ctx.api_headers(raw_key)
      end
    },
    {
      name: "GET /api/v1/manage/credentials",
      request: lambda do |ctx, raw_key|
        ctx.get "/api/v1/manage/credentials", headers: ctx.api_headers(raw_key)
      end
    },
    {
      name: "POST /api/v1/manage/credentials",
      request: lambda do |ctx, raw_key|
        ctx.post "/api/v1/manage/credentials",
                 params: {
                   name: "New Credential",
                   type: "API",
                   server_id: ctx.server.id
                 }.to_json,
                 headers: ctx.api_json_headers(raw_key)
      end
    },
    {
      name: "GET /api/v1/manage/credentials/:uuid",
      request: lambda do |ctx, raw_key|
        ctx.get "/api/v1/manage/credentials/#{ctx.credential.uuid}", headers: ctx.api_headers(raw_key)
      end
    },
    {
      name: "PATCH /api/v1/manage/credentials/:uuid",
      request: lambda do |ctx, raw_key|
        ctx.patch "/api/v1/manage/credentials/#{ctx.credential.uuid}",
                  params: { name: "Updated Credential" }.to_json,
                  headers: ctx.api_json_headers(raw_key)
      end
    },
    {
      name: "DELETE /api/v1/manage/credentials/:uuid",
      request: lambda do |ctx, raw_key|
        ctx.delete "/api/v1/manage/credentials/#{ctx.credential.uuid}", headers: ctx.api_headers(raw_key)
      end
    },
    {
      name: "GET /api/v1/manage/domains",
      request: lambda do |ctx, raw_key|
        ctx.get "/api/v1/manage/domains", headers: ctx.api_headers(raw_key)
      end
    },
    {
      name: "POST /api/v1/manage/domains",
      request: lambda do |ctx, raw_key|
        ctx.post "/api/v1/manage/domains",
                 params: {
                   name: "new-domain.example",
                   server_id: ctx.server.id
                 }.to_json,
                 headers: ctx.api_json_headers(raw_key)
      end
    },
    {
      name: "GET /api/v1/manage/domains/:uuid",
      request: lambda do |ctx, raw_key|
        ctx.get "/api/v1/manage/domains/#{ctx.domain.uuid}", headers: ctx.api_headers(raw_key)
      end
    },
    {
      name: "PATCH /api/v1/manage/domains/:uuid",
      request: lambda do |ctx, raw_key|
        ctx.patch "/api/v1/manage/domains/#{ctx.domain.uuid}",
                  params: { outgoing: false }.to_json,
                  headers: ctx.api_json_headers(raw_key)
      end
    },
    {
      name: "DELETE /api/v1/manage/domains/:uuid",
      request: lambda do |ctx, raw_key|
        ctx.delete "/api/v1/manage/domains/#{ctx.domain.uuid}", headers: ctx.api_headers(raw_key)
      end
    },
    {
      name: "POST /api/v1/manage/domains/:uuid/verify",
      request: lambda do |ctx, raw_key|
        ctx.post "/api/v1/manage/domains/#{ctx.domain.uuid}/verify",
                 params: { force: true }.to_json,
                 headers: ctx.api_json_headers(raw_key)
      end
    }
  ].freeze

  endpoint_definitions.each do |definition|
    context definition[:name] do
      it "rejects deleted key owners" do
        raw_key = management_api_key.key
        admin_user.destroy!

        definition[:request].call(self, raw_key)

        json = JSON.parse(response.body)
        expect(json["status"]).to eq("error")
        expect(json.dig("data", "code")).to eq("InvalidManagementAPIKey")
      end

      it "rejects demoted key owners" do
        raw_key = management_api_key.key
        admin_user.update!(admin: false)

        definition[:request].call(self, raw_key)

        json = JSON.parse(response.body)
        expect(json["status"]).to eq("error")
        expect(json.dig("data", "code")).to eq("ManagementAPIKeyRevoked")
      end
    end
  end
end
