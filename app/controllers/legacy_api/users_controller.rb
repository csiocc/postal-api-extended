# frozen_string_literal: true

module LegacyAPI
  class UsersController < BaseController
    CROSS_ORG_USER_MANAGEMENT_OPTION = 'allow_cross_organization_user_management'

    skip_before_action :authenticate_as_server
    before_action :authenticate_as_admin

    def index
      users = scoped_users.order(:first_name, :last_name).includes(:organization_users)
      render_success(
        users: users.map { |u| user_hash(u) },
        total: users.count
      )
    end

    def show
      user = find_user
      return unless user

      render_success(user: user_hash(user, include_details: true))
    end

    def create
      params = api_params

      user = User.new(
        email_address: params['email_address'],
        first_name: params['first_name'],
        last_name: params['last_name'],
        password: params['password'],
        password_confirmation: params['password_confirmation'],
        admin: params['admin'] || false,
        time_zone: params['time_zone'] || 'UTC'
      )

      if params['organization_ids'].present?
        organization_ids = authorized_organization_ids(params['organization_ids'])
        return unless organization_ids

        user.organization_ids = organization_ids
      end

      if user.save
        render_success(
          user: user_hash(user, include_details: true),
          message: "User #{user.name} created successfully"
        )
      else
        render_parameter_error(user.errors.full_messages.join(', '))
      end
    end

    def update
      user = find_user
      return unless user

      params = api_params

      if user.uuid == @current_admin_user.uuid && params['admin'] == false
        render_error('CannotModifySelf',
                     message: 'Cannot remove your own admin status')
        return
      end

      update_attributes = {
        email_address: params['email_address'],
        first_name: params['first_name'],
        last_name: params['last_name'],
        admin: params['admin'],
        time_zone: params['time_zone']
      }.compact
      user.assign_attributes(update_attributes)

      if params['password'].present?
        user.password = params['password']
        user.password_confirmation = params['password_confirmation']
      end

      if params.key?('organization_ids')
        organization_ids = authorized_organization_ids(params['organization_ids'])
        return unless organization_ids

        user.organization_ids = organization_ids
      end

      if user.save
        render_success(
          user: user_hash(user, include_details: true),
          message: "User #{user.name} updated successfully"
        )
      else
        render_parameter_error(user.errors.full_messages.join(', '))
      end
    end

    def destroy
      user = find_user
      return unless user

      if user.uuid == @current_admin_user.uuid
        render_error('CannotModifySelf',
                     message: 'Cannot delete your own user account')
        return
      end

      user.destroy!
      render_success(message: "User #{user.name} has been deleted")
    end

    private

    def authenticate_as_admin
      authenticate_as_server
      return if performed?

      owner = @current_credential&.server&.organization&.owner

      if owner&.admin?
        @current_admin_user = owner
      else
        render_error('AccessDenied', message: 'User management requires admin privileges')
      end
    end

    def find_user
      user = scoped_users.find_by(uuid: params[:uuid])
      unless user
        render_error('UserNotFound',
                     message: 'The specified user could not be found',
                     uuid: params[:uuid])
        return nil
      end
      user
    end

    def scoped_users
      return User.all if allow_cross_organization_user_management?

      organization = @current_credential.server.organization
      User
        .left_outer_joins(:organization_users)
        .where('organization_users.organization_id = :organization_id OR users.id = :owner_id',
               organization_id: organization.id,
               owner_id: organization.owner_id)
        .distinct
    end

    def authorized_organization_ids(raw_organization_ids)
      organization_ids = normalize_organization_ids(raw_organization_ids)
      return nil unless organization_ids

      return organization_ids if allow_cross_organization_user_management?

      allowed_org_id = @current_credential.server.organization_id
      unauthorized_ids = organization_ids - [allowed_org_id]
      return organization_ids if unauthorized_ids.empty?

      render_error('AccessDenied',
                   message: 'organization_ids contains organizations outside your scope',
                   organization_ids: unauthorized_ids)
      nil
    end

    def normalize_organization_ids(raw_organization_ids)
      unless raw_organization_ids.is_a?(Array)
        render_parameter_error('organization_ids must be an array of organization IDs')
        return nil
      end

      invalid_ids = raw_organization_ids.reject { |id| id.to_s.match?(/\A\d+\z/) }
      if invalid_ids.any?
        render_parameter_error('organization_ids must contain only integer IDs')
        return nil
      end

      raw_organization_ids.map(&:to_i).uniq
    end

    def allow_cross_organization_user_management?
      @current_credential&.options&.[](CROSS_ORG_USER_MANAGEMENT_OPTION) || false
    end

    def user_hash(user, include_details: false)
      hash = {
        uuid: user.uuid,
        email_address: user.email_address,
        first_name: user.first_name,
        last_name: user.last_name,
        name: user.name,
        admin: user.admin,
        time_zone: user.time_zone,
        created_at: user.created_at.iso8601,
        updated_at: user.updated_at.iso8601
      }

      if include_details
        hash[:organizations] = user.organizations.map do |org|
          {
            uuid: org.uuid,
            name: org.name,
            permalink: org.permalink
          }
        end
        hash[:email_verified_at] = user.email_verified_at&.iso8601
        hash[:oidc] = user.oidc?
      end

      hash
    end
  end
end
