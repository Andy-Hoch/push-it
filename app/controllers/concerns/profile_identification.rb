# Who is playing: the signed-in user's profile, or a guest profile remembered by a
# signed cookie (and mirrored to localStorage by the identity Stimulus controller).
module ProfileIdentification
  extend ActiveSupport::Concern

  included do
    before_action :resume_profile
    helper_method :current_profile
  end

  private
    def current_profile
      Current.profile
    end

    def resume_profile
      resume_session
      Current.profile = Current.user ? Current.user.profile : guest_from_cookie
    end

    def guest_from_cookie
      token = cookies.signed[:profile_token]
      Profile.guests.find_by(guest_token: token) if token
    end

    def ensure_profile(name = nil)
      name = name.to_s.squish.first(24).presence
      Current.profile ||= Current.user ? create_account_profile(name) : create_guest_profile(name)
      Current.profile.update!(name: name) if name && name != Current.profile.name
      Current.profile
    end

    def create_account_profile(name)
      Current.user.create_profile!(name: name || Current.user.email_address.split("@").first.first(24))
    end

    def create_guest_profile(name)
      Profile.create!(name: name || Profile.guest_name).tap { |profile| remember_guest(profile) }
    end

    def remember_guest(profile)
      cookies.signed.permanent[:profile_token] = { value: profile.guest_token, httponly: true, same_site: :lax }
    end

    def claim_guest_profile_for(user)
      if (guest = guest_from_cookie)
        guest.claim_for(user)
        cookies.delete(:profile_token)
      end
      Current.profile = user.reload.profile
    end
end
