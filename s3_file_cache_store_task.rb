require "net/http"
require "uri"

class S3FileCacheStoreTask
  @queue = :z010_cache

  def self.perform(server_path, cache_path)
    uri = URI.parse(server_path)
    response = Net::HTTP.get_response(uri)
    if response.code == "200"
      dirname  = File.dirname(cache_path)
      FileUtils.mkpath(dirname) # or use mkdir_p
      File.open(cache_path, 'w') { |f| f.write(response.body) }
    end
  end
end
