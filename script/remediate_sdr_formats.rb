# frozen_string_literal: true

require 'json'
require 'http'

def generate_json(data)
  data.map do |doc|
    "\"add\":#{JSON.generate(doc: doc)}"
  end.join(",\n").prepend('{').concat('}')
end

def format_hsim(format_main_ssim)
  accumulator = []

  Array(format_main_ssim).each do |format|
    case format
    when 'Archived website'
      accumulator << 'Website'
      accumulator << 'Website|Archived website'
    when 'Music recording'
      accumulator << 'Sound recording'
    when 'Video'
      accumulator << 'Video/Film'
    else
      accumulator << format
    end
  end

  accumulator.uniq
end

solr_base_url = ENV.fetch('SOLR_URL', nil)
limit = ENV.fetch('LIMIT', 100).to_i

raise 'Missing SOLR_URL environment variable' unless solr_base_url

response = HTTP.get("#{solr_base_url}/export", params: { fl: 'id', sort: 'id asc', q: 'id:[a* TO z*]' })

data = JSON.parse(response.body.to_s)
docs = data['response']['docs']
docs = docs.first(limit) if limit >= 0

docs.each_slice(20) do |batch|
  response = HTTP.get("#{solr_base_url}/get", params: { ids: batch.map { |x| x['id'] }.join(','), fl: 'id,format_main_ssim,format_hsim' })
  data = JSON.parse(response.body.to_s)
  updates = data['response']['docs'].map do |doc|
    next if doc['format_hsim']

    {
      id: doc['id'],
      format_hsim: { add: format_hsim(doc['format_main_ssim']) }
    }
  end

  HTTP.post("#{solr_base_url}/update", body: generate_json(updates.compact), headers: { 'Content-Type' => 'application/json' })
  puts batch.first['id']
end
