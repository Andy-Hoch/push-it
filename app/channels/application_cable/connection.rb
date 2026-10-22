module ApplicationCable
  # Game tables are public by invite code and streams are signed, so guests connect too.
  # Native apps identify with their guest token (`Authorization: Bearer <token>`).
  class Connection < ActionCable::Connection::Base
    identified_by :profile

    def connect
      self.profile = find_profile_by_token
    end

    private
      def find_profile_by_token
        if (token = request.authorization.to_s[/\ABearer (.+)\z/, 1])
          Profile.guests.find_by(guest_token: token) || reject_unauthorized_connection
        end
      end
  end
end
