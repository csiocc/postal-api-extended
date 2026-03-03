# frozen_string_literal: true

module LegacyAPI
  class ServersController < BaseController
    GLOBAL_ADMIN_OPTION = "global_admin"

    skip_before_action :authenticate_as_server
    before_action :authenticate_as_admin

    def index
    end

    def show
    end

    def create
    end

    def update
    end

    def destroy
    end

    private

    def authenticate_as_global_admin
      authenticate_as_server
      return if performed?

      unless global_admin?
        render_error("AccessDenied", message: "Organization management requires global admin privileges")
        return
      end

      @current_admin_user = @current_credential&.server&.organization&.owner
    end

    def global_admin?
      @current_credential&.options&.[](GLOBAL_ADMIN_OPTION) == true
    end

    def find_organization
    end

    def server_hash(server, include_details: false)
      server_hash = {
        uuid: server.uuid,
        name: server.name,
        permalink: server.permalink,
        mode: server.mode,
        status: server.status,
        created_at: server.created_at.iso8601,
        updated_at: server.updated_at.iso8601
      }

      if include_details
        server_hash[:organization] = {
          uuid: server.organization.uuid,
          name: server.organization.name,
          permalink: server.organization.permalink
        }
        server_hash[:suspended] = server.suspended?
        server_hash[:actual_suspension_reason] = server.actual_suspension_reason
      end

      server_hash
    end
  end
end
