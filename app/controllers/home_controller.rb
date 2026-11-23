class HomeController < ApplicationController
  skip_after_action :store_browsing_location, only: :index

  def index
    redirect_to shell_landing_path if ace_signed_in?
  end

  def faq = render :faq
  def contact = render :contact
end
