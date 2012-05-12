require "sinatra"
require "resque"
require File.dirname(File.expand_path(__FILE__)) + "/s3_file_cache_store_task"

configure :production do
  set :s3_host,             ENV["S3_HOST_ALIAS"]
  set :cache_dir,           ENV["CACHE_DIR"]
  set :redis_url,           ENV["REDISTOGO_URL"]
  set :cache_avatar_domain, ENV["CACHE_AVATAR_DOMAIN"] || "avatars"
  set :username,            ENV["CACHE_INVALIDATION_USERNAME"]
  set :password,            ENV["CACHE_INVALIDATION_PASSWORD"]
end

configure :development do
  set :s3_host,   "ahph9thi.gotoknow.org"
  set :cache_dir, File.dirname(File.expand_path(__FILE__)) + "/cache"
end

configure :test do
  set :s3_host,   "foo.bar.com"
  set :cache_dir, File.dirname(File.expand_path(__FILE__)) + "/spec/fixtures"
  Resque.inline = true
end

configure :development, :test do
  set :redis_url,           "localhost:6379"
  set :cache_avatar_domain, nil
  set :username,            "username"
  set :password,            "password"
end

configure do
  uri = URI.parse(settings.redis_url)
  Resque.redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
end

helpers do
  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials &&
      @auth.credentials == [settings.username, settings.password]
  end
end

get "/avatars/:klass/:id_part1/:id_part2/:id_part3/:filename" do |klass, id_part1, id_part2, id_part3, filename|
  domain = settings.cache_avatar_domain ? "#{settings.cache_avatar_domain}/" : nil
  path = "avatars/#{klass}/#{id_part1}/#{id_part2}/#{id_part3}/#{filename}"
  cache_path = "#{settings.cache_dir}/#{domain}#{path}"

  if File.exists?(cache_path)
    send_file cache_path
  else
    server_path = "http://#{settings.s3_host}/#{path}?#{request.query_string}"
    Resque.enqueue(S3FileCacheStoreTask, server_path, cache_path)
    redirect server_path
  end
end

get "/invalidate/avatars/:klass/:id_part1/:id_part2/:id_part3/:filename" do |klass, id_part1, id_part2, id_part3, filename|
  protected!
  domain = settings.cache_avatar_domain ? "#{settings.cache_avatar_domain}/" : nil
  path = "avatars/#{klass}/#{id_part1}/#{id_part2}/#{id_part3}/#{filename}"
  cache_path = "#{settings.cache_dir}/#{domain}#{path}"

  if File.exists?(cache_path)
    begin
      File.delete(cache_path)
      "Invalidation successful for: #{path}"
    rescue Exception => e
      status 422
      "Unable to invalidate the cache for: #{path}\nError message: #{e.message}"
    end
  else
    "No cache found for: #{path}"
  end
end

