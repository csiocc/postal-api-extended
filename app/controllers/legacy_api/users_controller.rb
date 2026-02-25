# frozen_string_literal: true

module LegacyAPI
  class UsersController < BaseController
    skip_before_action :authenticate_as_server
    before_action :authenticate_as_admin

    def index
      users = User.order(:first_name, :last_name).includes(:organization_users)
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
        user.organization_ids = params['organization_ids']
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
      
      if params['organization_ids']
        user.organization_ids = params['organization_ids']
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
      user = User.find_by(uuid: params[:uuid])
      unless user
        render_error('UserNotFound', 
          message: 'The specified user could not be found',
          uuid: params[:uuid])
        return nil
      end
      user
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
