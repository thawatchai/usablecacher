require File.dirname(File.expand_path(__FILE__)) + '/asset_invalidator'
require 'resque/server'

run Rack::URLMap.new \
  "/"       => Sinatra::Application,
  "/resque" => Resque::Server.new
  
# NOTE: We can run this with unicorn: unicorn config.ru
