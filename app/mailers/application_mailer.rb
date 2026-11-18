class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV["MAIL_FROM"].presence || "AthleteAce <accounts@mail.athleteace.win>" }
  layout "mailer"
end
