begin
  require 'oboe'
  %w{oboe_fu_util inst/action_controller inst/rack inst/active_record inst/memcache inst/memcached}.each do |f|
    require File.join(File.dirname(__FILE__), 'lib', f)
  end
rescue Exception => e
  require 'pp'
  pp e
  $stderr.puts "[oboe_fu] unable to init oboe_fu"
end

