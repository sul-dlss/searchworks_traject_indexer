# frozen_string_literal: true

require 'slop'

module StreamingIndexer
  class Application
    def self.run(argv = ARGV)
      options = parse(argv)
      settings = parse_settings(options[:setting])
      settings['streaming.source'] ||= options[:source]
      new(config_path: options[:config], settings:).run
    end

    def self.parse(argv)
      Slop.parse(argv) do |options|
        options.string '-c', '--config', 'Traject mapping configuration', required: true
        options.string '--source', 'folio or sdr', required: true
        options.array '-s', '--setting', 'setting in key=value form', default: []
        options.on '--help' do
          puts options
          exit
        end
      end
    end

    def self.parse_settings(values)
      values.to_h do |value|
        key, setting = value.split('=', 2)
        raise ArgumentError, "Invalid setting #{value.inspect}; expected key=value" if setting.nil?

        [key, setting]
      end
    end

    def initialize(config_path:, settings:)
      @config_path = config_path
      @settings = settings.transform_keys(&:to_s)
    end

    def run
      validate_source_settings!
      mapper = IrMapper.new(config_path:, settings:)
      @settings = mapper.indexer.settings.to_h.merge(settings)
      validate_solr_settings!
      Utils.logger = mapper.indexer.logger
      kafka = Kafka.new(kafka_hosts, logger: Utils.logger)
      consumer = build_consumer(kafka)
      retry_policy = RetryPolicy.new(
        max_attempts: settings.fetch('streaming.max_attempts', 3),
        base_interval: settings.fetch('streaming.retry_base_interval', 1),
        metrics:
      )
      runner = Runner.new(
        reader: reader_class.new(nil, settings.merge('kafka.consumer' => consumer)),
        consumer:,
        mapper:,
        sink: SolrSink.new(settings, retry_policy:, metrics:),
        quarantine: QuarantineWriter.new(
          kafka:,
          topic: settings['streaming.quarantine_topic'],
          retry_policy:
        ),
        metrics:
      )

      with_signal_handlers(runner) { runner.run }
    end

    private

    attr_reader :config_path, :settings

    def validate_source_settings!
      required = %w[kafka.topic kafka.consumer_group_id streaming.quarantine_topic]
      missing = required.select { |key| settings[key].to_s.empty? }
      raise ArgumentError, "Missing required settings: #{missing.join(', ')}" if missing.any?

      raise ArgumentError, 'streaming.source must be folio or sdr' unless %w[folio sdr].include?(source)
    end

    def validate_solr_settings!
      return if settings['solr.url'].present? || settings['solr.update_url'].present?

      raise ArgumentError, 'Missing required setting: solr.url or solr.update_url'
    end

    def source
      settings['streaming.source'].to_s
    end

    def kafka_hosts
      settings['kafka.hosts'] || Settings.kafka.hosts
    end

    def build_consumer(kafka)
      kafka.consumer(
        group_id: settings['kafka.consumer_group_id'],
        fetcher_max_queue_size: Integer(settings.fetch('streaming.kafka.fetcher_max_queue_size', 25)),
        offset_commit_interval: 0
      ).tap do |consumer|
        consumer.subscribe(settings['kafka.topic'])
      end
    end

    def reader_class
      source == 'folio' ? Traject::KafkaFolioReader : Traject::KafkaPurlFetcherReader
    end

    def metrics
      @metrics ||= Metrics::Statsd.new(prefix: settings.fetch('streaming.metrics_prefix', 'streaming_indexer'))
    end

    def with_signal_handlers(runner)
      previous = %w[INT TERM].to_h do |signal|
        [signal, Signal.trap(signal) { runner.stop }]
      end
      yield
    ensure
      previous&.each { |signal, handler| Signal.trap(signal, handler) }
    end
  end
end
