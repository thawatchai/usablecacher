require 'rubygems'
require 'sinatra'
require 'rack/test'
require 'rspec'
#require 'factory_girl'

set :environment, :test

require File.join(File.dirname(__FILE__), '..', 'asset_invalidator')

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end

# Add an app method for RSpec
def app
  Sinatra::Application
end
