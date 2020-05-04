require 'sequel'
require 'json'
require 'httpclient'

db = Sequel.connect(ENV['hathitrust_lookup_db'])
client = HTTPClient.new

data = db.from('stdnums').join(:overlap, oclc: :value).join('hathifiles', htid: Sequel[:stdnums][:htid]).where(type: 'oclc').where(Sequel.~(local_id: 0)).order(:local_id).select_all(:hathifiles).select_append(:local_id)

data.paged_each.slice_when { |before, after| before[:local_id] != after[:local_id] }.each do |rows|
  hathitrust_info = rows.map { |x| x.slice(:htid, :ht_bib_key, :content_provider_code, :access, :rights, :description, :oclc_num) }.uniq { |x| x[:htid] }
  puts rows.first[:local_id]

  doc = {
    id: rows.first[:local_id].to_s,
    hathitrust_info_struct: {
      set: Array(hathitrust_info).map { |x| JSON.generate(x) }
    },
    ht_access_sim: {
      set: rows.map { |x| x[:access] }.uniq + rows.map { |x| [x[:access], x[:rights]].join(':') }.uniq
    },
    ht_bib_key_ssim: {
      set: rows.map { |x| x[:ht_bib_key] }.uniq
    },
    ht_htid_ssim: {
      set: rows.length > 1 ? nil : rows.first[:htid]
    }
  }

  resp = client.post ENV['SOLR_URL'], [doc].to_json, 'Content-Type' => 'application/json'
  puts resp.body unless resp.status == 200
end
