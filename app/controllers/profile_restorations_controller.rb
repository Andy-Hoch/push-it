# The browser lost its cookie but still has the guest profile in localStorage.
class ProfileRestorationsController < ApplicationController
  rate_limit to: 20, within: 1.minute, only: :create

  def create
    if current_profile.nil? && !authenticated?
      profile = Profile.restore(token: params[:token], snapshot: params.fetch(:snapshot, {}).to_unsafe_h)
      remember_guest(profile)
      Current.profile = profile
    end

    render json: current_profile&.snapshot || {}
  end
end
