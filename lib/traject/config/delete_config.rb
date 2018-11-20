$LOAD_PATH << File.expand_path('../..', __dir__)

require 'utils'

require 'traject'
require 'traject/readers/delete_reader'
require 'traject/writers/delete_writer'

settings do
  provide 'solr.url', ENV['SOLR_URL']
  provide 'solr.version', ENV['SOLR_VERSION']
  provide 'processing_thread_pool', ENV['NUM_THREADS']
  if ENV['KAFKA_TOPIC']
    require 'kafka'
    if ENV['SOURCE'] == 'sdr'
      require 'sdr_stuff'
      require 'traject/readers/kafka_purl_fetcher_reader'
      provide "reader_class_name", "Traject::KafkaPurlFetcherReader"
    else
      require 'traject/readers/marc_combining_reader'
      require 'traject/readers/kafka_marc_reader'
      provide "reader_class_name", "Traject::KafkaMarcReader"
      provide "marc4j_reader.permissive", true
    end
    kafka = Kafka.new(ENV.fetch('KAFKA', 'localhost:9092').split(','))
    consumer = kafka.consumer(group_id: ENV.fetch('KAFKA_CONSUMER_GROUP_ID', "traject_deletes_#{ENV['KAFKA_TOPIC']}"))
    consumer.subscribe(ENV['KAFKA_TOPIC'])
    provide 'kafka.consumer', consumer
  else
    provide "reader_class_name", "Traject::DeleteReader"
  end
  provide 'writer_class_name', 'Traject::DeleteWriter'
  provide 'solr_writer.commit_on_close', true
  if defined?(JRUBY_VERSION)
    require 'traject/manticore_http_client'
    provide 'solr_json_writer.http_client', Traject::ManticoreHttpClient.new
  else
    provide 'solr_json_writer.http_client', HTTPClient.new.tap { |x| x.receive_timeout = 600 }
  end
end

Utils.logger = logger

##
# Skip records that don't have a delete flag
each_record do |record, context|
  context.skip!('') unless record.is_a?(Hash) && record[:delete]
end

to_field 'id' do |record, accumulator|
  accumulator << record[:id].strip
end
