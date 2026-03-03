# frozen_string_literal: true

module LegacyAPI
  class OrganizationsController < BaseController
    GLOBAL_ADMIN_OPTION = "global_admin"

    skip_before_action :authenticate_as_server
    before_action :authenticate_as_global_admin

    def index
      organizations = Organization.present.order(:name).includes(:owner) # only Orgs with deleted_at: nil
      
      render_success( organizations: organizations.map { |organization| organization_hash(organization) }, total: organizations.count)
    end

    def show
      organization = find_organization
      return unless organization

      render_success(organization: organization_hash(organization, include_details: true))
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
      organization = Organization.present.find_by(uuid: params[:uuid])
      unless organization
        render_error("OrganizationNotFound", message: "The requested organization could not be found", uuid: params[:uuid])
        return nil
      end
      organization
    end

    def organization_hash(organization, include_details: false)
      org = {
        uuid: organization.uuid,
        name: organization.name,
        permalink: organization.permalink,
        time_zone: organization.time_zone,
        status: organization.status,
        created_at: organization.created_at.iso8601,
        updated_at: organization.updated_at.iso8601
      }

      if include_details
        org[:owner] = {
          uuid: organization.owner.uuid,
          email_address: organization.owner.email_address,
          name: organization.owner.name
        }
      end
      org
    end

  end
end
