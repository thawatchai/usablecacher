require "sinatra"

configure do
  set :cache_dir, ENV["CACHE_DIR"]
end

get "/invalidate/avatars/:klass/:id_part1/:id_part2/:id_part3/:filename" do |klass, id_part1, id_part2, id_part3, filename|
  path = "avatars/#{klass}/#{id_part1}/#{id_part2}/#{id_part3}/#{filename}"
  cache_path = "#{settings.cache_dir}/#{path}"
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
