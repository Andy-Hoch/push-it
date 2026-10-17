# Local demo account for trying out sign-in and guest-profile takeover in development.
if Rails.env.development?
  User.find_or_create_by!(email_address: "ben@flip7.test") do |user|
    user.password = "flip7-demo-pass"
  end
end
