# Who is playing: the guest profile whose token comes as `Authorization: Bearer <token>`.
module Api::ProfileAuthentication
  extend ActiveSupport::Concern

  included do
    include ActionController::HttpAuthentication::Token::ControllerMethods

    before_action :require_profile
    helper_method :current_profile
  end

  class_methods do
    def allow_anonymous_access(**options)
      skip_before_action :require_profile, **options
    end
  end

  private
    def current_profile
      Current.profile
    end

    def require_profile
      Current.profile = authenticate_with_http_token { |token| Profile.guests.find_by(guest_token: token) }
      render_error :unauthorized, status: :unauthorized unless Current.profile
    end
end
