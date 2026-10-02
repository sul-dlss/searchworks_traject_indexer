# frozen_string_literal: true

module Traject
  class SolrAndKafkaWriter
    def initialize(settings)
      @solr_writer = settings['composite.solr_writer'] || SolrBetterJsonWriter.new(settings)
      @embedding_writer = settings['composite.embedding_writer'] || KafkaEmbeddingJobWriter.new(settings)
    end

    def put(context)
      @solr_writer.put(context)
      @embedding_writer.put(context)
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
