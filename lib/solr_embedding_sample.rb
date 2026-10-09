# frozen_string_literal: true

# Builds canonical embedding jobs from documents already indexed in the main
# SearchWorks Solr collection and processes them synchronously.
class SolrEmbeddingSample
  DEFAULT_LIMIT = 100
  SOURCE_FIELD = 'context_source_ssi'
  DOCUMENT_FIELDS = [
    'id',
    SOURCE_FIELD,
    *EmbeddingInputBuilder::TITLE_FIELDS,
    *EmbeddingInputBuilder::SECTION_FIELDS.values.flatten
  ].uniq.freeze

  def initialize(reader:, processor:, batch_size: EmbeddingWorker::DEFAULT_BATCH_SIZE)
    @reader = reader
    @processor = processor
    @batch_size = Integer(batch_size)
    raise ArgumentError, 'batch_size must be positive' unless @batch_size.positive?
  end

  def run(limit: DEFAULT_LIMIT)
    processed_count = 0

    @reader.each(limit:).each_slice(@batch_size) do |documents|
      @processor.process(documents.map { |document| build_job(document) })
      processed_count += documents.length
    end

    processed_count
  end

  private

  def build_job(document)
    id = Array(document['id']).first
    source = Array(document[SOURCE_FIELD]).first
    raise ArgumentError, 'Source Solr document has no id' if id.to_s.empty?
    raise ArgumentError, "Source Solr document #{id} has no #{SOURCE_FIELD}" if source.to_s.empty?

    EmbeddingJob.new(id:, source:, document:).as_json.transform_keys(&:to_s)
  end
end
