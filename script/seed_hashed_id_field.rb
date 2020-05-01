require 'httpclient'
require 'digest/md5'
require 'json'

client = HTTPClient.new
id_field = ENV['ID_FIELD'] || :id

ARGF.each_line do |id|
  id.strip!

  doc = {
   id_field => id.to_s,
   hashed_id_ssi: Digest::MD5.hexdigest(id)
 }

  client.post ENV['SOLR_URL'], [doc].to_json, 'Content-Type' => 'application/json'
  puts resp.body unless resp.status == 200
end
