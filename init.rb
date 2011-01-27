begin
  require 'oboe'
  %w{util inst/action_controller inst/active_record inst/xmlrpc inst/memcache}.each do |f|
    require File.join(File.dirname(__FILE__), 'lib', f)
  end
rescue Exception => e
end
