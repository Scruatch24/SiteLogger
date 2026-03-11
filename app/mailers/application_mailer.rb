class ApplicationMailer < ActionMailer::Base
  default from: "TalkInvoice <#{ENV["MAILER_FROM_ADDRESS"]}>"
  layout "mailer"
end
