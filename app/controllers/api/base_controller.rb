# JSON for the native apps. They play as guests and send their profile's guest token
# as bearer token; errors come back as { error:, message: } with a German message.
class Api::BaseController < ActionController::API
  include Api::ProfileAuthentication

  rescue_from Gameplay::IllegalMove do |error|
    render_error error.reason, error.message, status: :unprocessable_content
  end

  rescue_from ActiveRecord::RecordInvalid do |error|
    render_error :invalid, error.record.errors.full_messages.to_sentence, status: :unprocessable_content
  end

  rescue_from ActiveRecord::RecordNotFound do
    render_error :not_found, status: :not_found
  end

  rescue_from ActionController::ParameterMissing, ActionDispatch::Http::Parameters::ParseError do |error|
    render_error :bad_request, error.message, status: :bad_request
  end

  private
    def render_error(code, message = I18n.t("api.errors.#{code}"), status:)
      render json: { error: code, message: message }, status: status
    end
end
