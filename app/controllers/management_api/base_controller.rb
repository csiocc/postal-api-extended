# frozen_string_literal: true

module ManagementAPI
  class BaseController < ActionController::Base

    skip_before_action :set_browser_id
    skip_before_action :verify_authenticity_token

    rescue_from ActionDispatch::Http::Parameters::ParseError, with: :handle_json_parse_error

    before_action :start_timer
    before_action :authenticate_with_management_api_key

    private

    def api_params
      if request.headers["content-type"] =~ /\Aapplication\/json/
        return params.to_unsafe_hash
      end

      if params["params"].present?
        return JSON.parse(params["params"])
      end

      {}
    end

    def start_timer
      @start_time = Time.now.to_f
    end

    def authenticate_with_management_api_key
      key = request.headers["X-Management-API-Key"]
      if key.blank?
        render_error "AccessDenied",
                     message: "Must be authenticated for management API access."
        return
      end

      management_api_key = ManagementAPIKey.authenticate(key)
      if management_api_key.nil?
        render_error "InvalidManagementAPIKey",
                     message: "The API token provided in X-Management-API-Key was not valid."
        return
      end

      if management_api_key.revoked?
        render_error "ManagementAPIKeyRevoked",
                     message: "The management API key has been revoked."
        return
      end

      if management_api_key.user.nil? || !management_api_key.user.admin?
        render_error "AccessDenied",
                     message: "Management API keys require an active admin user."
        return
      end

      management_api_key.use
      @current_management_api_key = management_api_key
      @current_api_user = management_api_key.user
    end

    def render_success(data)
      render json: { status: "success",
                     time: (Time.now.to_f - @start_time).round(3),
                     flags: {},
                     data: data }
    end

    def render_error(code, data = {})
      render json: { status: "error",
                     time: (Time.now.to_f - @start_time).round(3),
                     flags: {},
                     data: data.merge(code: code) }
    end

    def render_parameter_error(message)
      render json: { status: "parameter-error",
                     time: (Time.now.to_f - @start_time).round(3),
                     flags: {},
                     data: { message: message } }
    end

    def handle_json_parse_error
      render_parameter_error "Request body must contain valid JSON."
    end

    def current_management_api_key
      @current_management_api_key
    end

    def current_api_user
      @current_api_user
    end

    def scoped_organizations_for_current_api_user
      return Organization.present.none unless current_api_user
      return Organization.present if current_api_user.admin?

      Organization
        .present
        .left_outer_joins(:organization_users)
        .where(
          "organizations.owner_id = :user_id OR (organization_users.user_type = 'User' AND organization_users.user_id = :user_id)",
          user_id: current_api_user.id
        )
        .distinct
    end
  end
end
