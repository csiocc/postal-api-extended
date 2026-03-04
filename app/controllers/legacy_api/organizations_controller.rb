# frozen_string_literal: true

module LegacyAPI
  class OrganizationsController < BaseController
    skip_before_action :authenticate_as_server
    before_action :authenticate_as_user
    before_action :admin_required_for_organization_write, only: [:create, :destroy]

    def index
      organizations = scoped_organizations.order(:name).includes(:owner) # only Orgs with deleted_at: nil
      
      render_success( organizations: organizations.map { |organization| organization_hash(organization) }, total: organizations.count)
    end

    def show
      organization = find_organization
      return unless organization

      render_success(organization: organization_hash(organization, include_details: true))
    end

    def create
      params = api_params
      owner = resolve_owner(params)
      return unless owner

      organization = Organization.new(
        name: params["name"],
        permalink: params["permalink"],
        time_zone: params["time_zone"] || "UTC",
        owner: owner
      )

      if organization.save
        render_success(
          organization: organization_hash(organization, include_details: true),
          message: "Organization #{organization.name} created successfully"
        )
      else
        render_parameter_error(organization.errors.full_messages.join(", "))
      end
    end

    def update
      organization = find_organization
      return unless organization

      params = api_params
      update_attributes = {
        name: params["name"],
        permalink: params["permalink"],
        time_zone: params["time_zone"]
      }.compact
      organization.assign_attributes(update_attributes)

      if organization.save
        render_success(
          organization: organization_hash(organization, include_details: true),
          message: "Organization #{organization.name} updated successfully"
        )
      else
        render_parameter_error(organization.errors.full_messages.join(", "))
      end
    end

    def destroy
      organization = find_organization
      return unless organization

      name = organization.name
      organization.soft_destroy
      render_success(message: "Organization #{name} has been deleted")
    end

    private

    def authenticate_as_user
      authenticate_as_server
      return if performed?

      return if current_api_user

      render_error("AccessDenied", message: "Organization management requires a valid user context")
    end

    def admin_required_for_organization_write
      return if current_api_user&.admin?

      render_error("AccessDenied", message: "Organization write operations require admin privileges")
    end

    def find_organization
      organization = scoped_organizations.find_by(uuid: params[:uuid])
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

    def resolve_owner(params)
      owner_uuid = params["owner_uuid"].to_s.strip
      return current_api_user if owner_uuid.empty?

      owner = User.find_by(uuid: owner_uuid)
      unless owner
        render_error("UserNotFound", message: "The specified owner could not be found", owner_uuid: owner_uuid)
        return nil
      end

      owner
    end

    def scoped_organizations
      scoped_organizations_for_current_api_user
    end

  end
end
