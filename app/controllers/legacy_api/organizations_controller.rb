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

  end
end
