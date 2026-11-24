# frozen_string_literal: true

module Traject
  class SolrAndKafkaWriter
    def initialize(settings)
      @embedding_writer = settings['composite.embedding_writer'] || KafkaEmbeddingJobWriter.new(settings)
      @solr_writer = settings['composite.solr_writer'] || SolrBetterJsonWriter.new(settings)
      @solr_writer.after_success = lambda do |contexts|
        contexts.each { |context| @embedding_writer.put(context) }
      end
    end

    def put(context)
      @solr_writer.put(context)
    end

    def write_skipped_records?
      true
    end

    def skipped_record_count
      @solr_writer.skipped_record_count
    end

    def close
      @solr_writer.close
    ensure
      @embedding_writer.close
    end
  end
end
