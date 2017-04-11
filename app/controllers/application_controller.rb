class ApplicationController < ActionController::Base
  protect_from_forgery

  include GDS::SSO::ControllerMethods
  
  def default_url_options(options={})
    options.merge :protocol => "https"
  end
  
end
