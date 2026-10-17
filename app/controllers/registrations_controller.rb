class RegistrationsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: t("sessions.rate_limited") }

  def new
    @user = User.new
  end

  def create
    @user = User.new(params.expect(user: %i[ email_address password password_confirmation ]))

    if @user.save
      start_new_session_for @user
      claim_guest_profile_for @user
      redirect_to after_authentication_url, notice: t("registrations.created")
    else
      render :new, status: :unprocessable_entity
    end
  end
end
