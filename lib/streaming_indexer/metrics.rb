# frozen_string_literal: true

require 'kafka/statsd'

module StreamingIndexer
  module Metrics
    class Null
      def received(event:); end
      def processed(operation:); end
      def skipped(event:); end
      def failed(stage:); end
      def retry(stage:); end
      def quarantined(stage:); end
      def batch(size:); end
      def processing_time(milliseconds:); end
    end

    class Statsd < Null
      def initialize(client: Kafka::Statsd.statsd, prefix: 'streaming_indexer')
        super()
        @client = client
        @prefix = prefix
      end

      def received(event:)
        increment("records.received.#{event.source}")
      end

      def processed(operation:)
        increment("records.processed.#{operation.event.source}")
        increment("solr.#{operation.action}s.#{operation.event.source}")
      end

      def skipped(event:)
        increment("records.skipped.#{event.source}")
      end

      def failed(stage:)
        increment("failures.#{stage}")
      end

      def retry(stage:)
        increment("retries.#{stage}")
      end

      def quarantined(stage:)
        increment("quarantined.#{stage}")
      end

      def batch(size:)
        @client.count("#{@prefix}.batch.records", size)
      end

      def processing_time(milliseconds:)
        @client.timing("#{@prefix}.processing.latency", milliseconds)
      end

      private

      def increment(metric)
        @client.increment("#{@prefix}.#{metric}")
      end
    end
  end
end
