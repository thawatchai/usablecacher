# Load optional environment file first before everything else.
env_file = File.expand_path('../env.rb', __FILE__)
require env_file if File.exists?(env_file)

require File.dirname(File.expand_path(__FILE__)) + '/app'
require 'resque/server'

run Rack::URLMap.new \
  "/"       => Sinatra::Application,
  "/resque" => Resque::Server.new

# NOTE: We can run this with unicorn: unicorn config.ru
