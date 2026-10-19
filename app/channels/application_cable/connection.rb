module ApplicationCable
  # Game tables are public by invite code and streams are signed, so guests connect too.
  class Connection < ActionCable::Connection::Base
  end
end
