# frozen_string_literal: true

module ManagementAPI
  class UsersController < BaseController
    before_action :authenticate_as_admin

    def index
      users = scoped_users.order(:first_name, :last_name).includes(:organization_users)
      users = paginate_scope(users)
      return if performed?

      render_success(
        users: users.map { |u| user_hash(u) },
        total: users.total_count,
        pagination: pagination_data(users)
      )
    end

    def show
      user = find_user
      return unless user

      render_success(user: user_hash(user, include_details: true))
    end

    def create
      params = api_params
      user_attributes = {
        email_address: params['email_address'],
        first_name: params['first_name'],
        last_name: params['last_name'],
        password: params['password'],
        password_confirmation: params['password_confirmation'],
        time_zone: params['time_zone'] || 'UTC'
      }

      if params.key?('admin')
        admin_value = normalize_boolean_param(params['admin'], 'admin')
        return if admin_value == :invalid

        user_attributes[:admin] = admin_value
      end

      user = User.new(user_attributes)

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
      admin_value = nil

      if params.key?('admin')
        admin_value = normalize_boolean_param(params['admin'], 'admin')
        return if admin_value == :invalid
      end

      if user.uuid == @current_api_user.uuid && admin_value == false
        render_error('CannotModifySelf',
                     message: 'Cannot remove your own admin status')
        return
      end

      update_attributes = {
        email_address: params['email_address'],
        first_name: params['first_name'],
        last_name: params['last_name'],
        admin: admin_value,
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

      if user.uuid == @current_api_user.uuid
        render_error('CannotModifySelf',
                     message: 'Cannot delete your own user account')
        return
      end

      user.destroy!
      render_success(message: "User #{user.name} has been deleted")
    end

    private

    def authenticate_as_admin
      return if current_api_user&.admin?

      render_error('AccessDenied', message: 'User management requires admin privileges')
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
      return User.all if current_api_user.admin?

      organizations = scoped_organizations_for_current_api_user
      User
        .left_outer_joins(:organization_users)
        .where(
          'organization_users.organization_id IN (:organization_ids) OR users.id IN (:owner_ids)',
          organization_ids: organizations.select(:id),
          owner_ids: organizations.select(:owner_id)
        )
        .distinct
    end

    def authorized_organization_ids(raw_organization_ids)
      organization_ids = normalize_organization_ids(raw_organization_ids)
      return nil unless organization_ids

      return organization_ids if current_api_user.admin?

      allowed_ids = scoped_organizations_for_current_api_user.where(id: organization_ids).pluck(:id)
      unauthorized_ids = organization_ids - allowed_ids
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

    def normalize_boolean_param(raw_value, field_name)
      return true if raw_value == true
      return false if raw_value == false

      if raw_value.is_a?(String)
        normalized = raw_value.strip.downcase
        return true if %w[true 1].include?(normalized)
        return false if %w[false 0].include?(normalized)
      elsif raw_value.is_a?(Numeric)
        return true if raw_value == 1
        return false if raw_value == 0
      end

      render_parameter_error("#{field_name} must be a boolean")
      :invalid
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
