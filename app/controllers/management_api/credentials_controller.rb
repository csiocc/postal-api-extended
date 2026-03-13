# frozen_string_literal: true

module ManagementAPI
  class CredentialsController < BaseController
    skip_before_action :authenticate_as_server
    before_action :authenticate_as_user

    def index
      server = resolve_server_for_index_filter
      return if performed?

      credentials = scoped_credentials.order(:name).includes(server: :organization)
      credentials = credentials.where(server_id: server.id) if server
      render_success(
        credentials: credentials.map { |credential| credential_hash(credential) },
        total: credentials.count
      )
    end

    def show
      credential = find_credential
      return unless credential

      render_success(credential: credential_hash(credential, include_details: true))
    end

    def create
      server = resolve_server_for_write
      return unless server

      attributes = create_attributes
      return if performed?

      credential = server.credentials.build(attributes)

      if credential.save
        render_success(
          credential: credential_hash(credential, include_details: true),
          message: "Credential #{credential.name} created successfully"
        )
      else
        render_parameter_error(credential.errors.full_messages.join(", "))
      end
    end

    def update
      credential = find_credential
      return unless credential

      attributes = update_attributes
      return if performed?

      credential.assign_attributes(attributes)

      if credential.save
        render_success(
          credential: credential_hash(credential, include_details: true),
          message: "Credential #{credential.name} updated successfully"
        )
      else
        render_parameter_error(credential.errors.full_messages.join(", "))
      end
    end

    def destroy
      credential = find_credential
      return unless credential

      name = credential.name
      credential.destroy!
      render_success(message: "Credential #{name} has been deleted")
    end

    private

    def authenticate_as_user
      authenticate_as_server
      return if performed?

      return if current_api_user

      render_error("AccessDenied", message: "Credential management requires a valid user context")
    end

    def find_credential
      credential = scoped_credentials.find_by(uuid: params[:uuid])
      return credential if credential

      render_error("CredentialNotFound",
                   message: "The requested credential could not be found",
                   uuid: params[:uuid])
      nil
    end

    def scoped_credentials
      Credential.where(server_id: scoped_servers.select(:id))
    end

    def scoped_servers
      scoped_servers_for_current_credential
    end

    def resolve_server_for_write
      server_id = api_params["server_id"]
      return current_server if server_id.blank?

      unless server_id.to_s.match?(/\A\d+\z/)
        render_parameter_error("server_id must be an integer")
        return nil
      end

      server = Server.present.find_by(id: server_id.to_i)
      unless server
        render_error("ServerNotFound",
                     message: "The requested server could not be found",
                     server_id: server_id.to_i)
        return nil
      end

      if scoped_servers.where(id: server.id).exists?
        server
      else
        render_error("AccessDenied",
                     message: "server_id is outside your scope",
                     server_id: server.id)
        nil
      end
    end

    def resolve_server_for_index_filter
      server_id = params[:server_id]
      return nil if server_id.blank?

      unless server_id.to_s.match?(/\A\d+\z/)
        render_parameter_error("server_id must be an integer")
        return nil
      end

      server = Server.present.find_by(id: server_id.to_i)
      unless server
        render_error("ServerNotFound",
                     message: "The requested server could not be found",
                     server_id: server_id.to_i)
        return nil
      end

      if scoped_servers.where(id: server.id).exists?
        server
      else
        render_error("AccessDenied",
                     message: "server_id is outside your scope",
                     server_id: server.id)
        nil
      end
    end

    def create_attributes
      params = api_params
      hold_value = normalized_optional_boolean(params, "hold")
      return {} if hold_value == :invalid

      attributes = {
        type: params["type"].presence || "SMTP",
        name: params["name"],
        key: params["key"]
      }
      attributes[:hold] = hold_value unless hold_value == :not_provided
      attributes
    end

    def update_attributes
      params = api_params
      hold_value = normalized_optional_boolean(params, "hold")
      return {} if hold_value == :invalid

      attributes = {
        name: params["name"],
        key: params["key"]
      }.compact
      attributes[:hold] = hold_value unless hold_value == :not_provided
      attributes
    end

    def normalized_optional_boolean(params, field_name)
      return :not_provided unless params.key?(field_name)

      normalize_boolean_param(params[field_name], field_name)
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

    def current_server
      current_api_server
    end

    def current_organization
      current_api_organization
    end

    def credential_hash(credential, include_details: false)
      hash = {
        uuid: credential.uuid,
        name: credential.name,
        key: credential.key,
        type: credential.type,
        hold: credential.hold,
        last_used_at: credential.last_used_at&.iso8601,
        created_at: credential.created_at.iso8601,
        updated_at: credential.updated_at.iso8601
      }

      if include_details
        hash[:server] = {
          uuid: credential.server.uuid,
          name: credential.server.name,
          permalink: credential.server.permalink,
          organization: {
            uuid: credential.server.organization.uuid,
            name: credential.server.organization.name,
            permalink: credential.server.organization.permalink
          }
        }
        hash[:options] = credential.options || {}
      end

      hash
    end
  end
end
