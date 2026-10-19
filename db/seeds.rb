# Local demo account for trying out sign-in and guest-profile takeover in development.
if Rails.env.development?
  User.find_or_create_by!(email_address: "ben@pushit.test") do |user|
    user.password = "pushit-demo-pass"
  end
end
