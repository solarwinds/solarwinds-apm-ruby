begin
  require 'oboe'
  %w{oboe_fu_util inst/action_controller inst/rack inst/active_record inst/xmlrpc inst/memcache inst/memcached}.each do |f|
    require File.join(File.dirname(__FILE__), 'lib', f)
  end
  
  if defined?(Rails.configuration.middleware)
    Rails.configuration.middleware.insert 0, Oboe::Middleware
  end
rescue Exception => e
  $stderr.puts "[oboe_fu] unable to init oboe_fu"
end

