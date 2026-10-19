class ApplicationMailer < ActionMailer::Base
  default from: ENV["MAILER_FROM_ADDRESS"].presence || "from@example.com"
  layout "mailer"
end
