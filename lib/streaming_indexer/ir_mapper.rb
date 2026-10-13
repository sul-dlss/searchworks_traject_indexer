# frozen_string_literal: true

module StreamingIndexer
  # Loads the existing Traject configuration and uses it only as a mapping from
  # a source record to the intermediate representation (IR). It never creates
  # or invokes the configured Traject writer.
  class IrMapper
    attr_reader :indexer

    def initialize(config_path: nil, settings: {}, indexer: nil)
      @indexer = indexer || build_indexer(config_path, settings)
    end

    def map(event)
      return delete_operation(event) if event.delete?

      # The SDR reader emits a skip when an event's true_targets do not include
      # the configured purl_fetcher.target; it should not produce a Solr update.
      return if event.skip?

      context = Traject::Indexer::Context.new(
        source_record: event.record,
        settings: indexer.settings,
        source_record_id_proc: indexer.source_record_id_proc,
        logger: indexer.logger
      )
      indexer.map_to_context!(context)

      # Some mapping rules intentionally skip a record before the id field is
      # produced. The legacy writer treats those records as no-ops. A skipped
      # context with an id, however, represents a delete.
      return if context.skip? && Array(context.output_hash['id']).all? { |candidate| candidate.to_s.strip.empty? }

      id = extract_id(context.output_hash['id'])
      return Operation.delete(id:, event:) if context.skip?

      document = context.output_hash.dup
      document['id'] = id
      Operation.add(id:, document:, event:)
    end

    private

    def build_indexer(config_path, settings)
      raise ArgumentError, 'config_path is required' if config_path.to_s.empty?

      mapper_settings = settings.to_h.transform_keys(&:to_s).except(
        'kafka.topic', 'kafka.consumer', 'kafka.client', 'writer_class_name'
      )
      # Prevent the mapping configs from reporting the same terminal error that
      # the streaming runner will report with Kafka position information.
      mapper_settings['mapping_rescue'] = lambda do |_context, error|
        raise error
      end
      mapper_settings['reader_class_name'] ||= 'Traject::FolioJsonReader' if File.basename(config_path) == 'folio_config.rb'

      Traject::Indexer.new(mapper_settings).tap do |configured_indexer|
        configured_indexer.load_config_file(config_path)
      end
    end

    def delete_operation(event)
      Operation.delete(id: extract_id(event.id), event:)
    end

    def extract_id(value)
      values = Array(value).filter_map do |candidate|
        normalized = candidate.to_s.strip
        normalized unless normalized.empty?
      end

      raise InvalidRecord, 'record must contain exactly one non-empty id' unless values.one?

      values.first
    end
  end
end
