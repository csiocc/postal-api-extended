# frozen_string_literal: true

module LegacyAPI
  class ServersController < BaseController
    GLOBAL_ADMIN_OPTION = "global_admin"

    skip_before_action :authenticate_as_server
    before_action :authenticate_as_admin

    def index
      servers = scoped_servers.order(:name).includes(:organization)
      render_success(
        servers: servers.map { |server| server_hash(server) },
        total: servers.count
      )
    end

    def show
      server = find_server
      return unless server

      render_success(server: server_hash(server, include_details: true))
    end

    def create
      organization = resolve_organization_for_write
      return unless organization

      server = organization.servers.build(create_attributes)

      if server.save
        render_success(
          server: server_hash(server, include_details: true),
          message: "Server #{server.name} created successfully"
        )
      else
        render_parameter_error(server.errors.full_messages.join(", "))
      end
    end

    def update
      server = find_server
      return unless server

      server.assign_attributes(update_attributes)

      if server.save
        render_success(
          server: server_hash(server, include_details: true),
          message: "Server #{server.name} updated successfully"
        )
      else
        render_parameter_error(server.errors.full_messages.join(", "))
      end
    end

    def destroy
      server = find_server
      return unless server

      name = server.name
      server.soft_destroy
      render_success(message: "Server #{name} has been deleted")
    end

    private

    def authenticate_as_admin
      authenticate_as_server
      return if performed?

      owner = @current_credential&.server&.organization&.owner

      if owner&.admin?
        @current_admin_user = owner
      else
        render_error("AccessDenied", message: "Server management requires admin privileges")
      end
    end

    def find_server
      server = scoped_servers.find_by(uuid: params[:uuid])
      return server if server

      render_error("ServerNotFound",
                   message: "The requested server could not be found",
                   uuid: params[:uuid])
      nil
    end

    def scoped_servers
      return Server.present if global_admin?

      Server.present.where(organization_id: current_organization.id)
    end

    def resolve_organization_for_write
      organization_id = api_params["organization_id"]
      return current_organization if organization_id.blank?

      unless organization_id.to_s.match?(/\A\d+\z/)
        render_parameter_error("organization_id must be an integer")
        return nil
      end

      organization = Organization.present.find_by(id: organization_id.to_i)
      unless organization
        render_error("OrganizationNotFound",
                     message: "The requested organization could not be found",
                     organization_id: organization_id.to_i)
        return nil
      end

      if global_admin? || organization.id == current_organization.id
        organization
      else
        render_error("AccessDenied",
                     message: "organization_id is outside your scope",
                     organization_id: organization.id)
        nil
      end
    end

    def create_attributes
      params = api_params
      {
        name: params["name"],
        permalink: params["permalink"],
        mode: params["mode"]
      }
    end

    def update_attributes
      params = api_params
      {
        name: params["name"],
        permalink: params["permalink"],
        mode: params["mode"]
      }.compact
    end

    def current_organization
      @current_organization ||= @current_credential.server.organization
    end

    def global_admin?
      @current_credential&.options&.[](GLOBAL_ADMIN_OPTION) == true
    end

    def server_hash(server, include_details: false)
      hash = {
        uuid: server.uuid,
        name: server.name,
        permalink: server.permalink,
        mode: server.mode,
        status: server.status,
        created_at: server.created_at.iso8601,
        updated_at: server.updated_at.iso8601
      }

      if include_details
        hash[:organization] = {
          uuid: server.organization.uuid,
          name: server.organization.name,
          permalink: server.organization.permalink
        }
        hash[:suspended] = server.suspended?
        hash[:actual_suspension_reason] = server.actual_suspension_reason
      end

      hash
    end
  end
end
