begin
  require 'oboe'
  %w{oboe_fu_util inst/action_controller inst/active_record inst/xmlrpc inst/memcache}.each do |f|
    require File.join(File.dirname(__FILE__), 'lib', f)
  end
rescue Exception => e
    $stderr.puts "[oboe_fu] unable to init oboe_fu"
end
