# frozen_string_literal: true

module StreamingIndexer
  # Coordinates one synchronous batch at a time. Kafka offsets are marked only
  # after every event in the batch has either reached Solr or been durably
  # written to quarantine. ruby-kafka commits the marked offsets after this
  # processing callback returns.
  class Runner
    def initialize(reader:, consumer:, mapper:, sink:, quarantine:, metrics: nil, notifier: Honeybadger) # rubocop:disable Metrics/ParameterLists
      @reader = reader
      @consumer = consumer
      @mapper = mapper
      @sink = sink
      @quarantine = quarantine
      @metrics = metrics || Metrics::Null.new
      @notifier = notifier
    end

    def run
      reader.each_batch(automatically_mark_as_processed: false) do |events|
        process_and_checkpoint(events) unless events.empty?
      end
    ensure
      close
    end

    def stop
      consumer.stop
    end

    private

    attr_reader :reader, :consumer, :mapper, :sink, :quarantine, :metrics, :notifier

    def process_and_checkpoint(events)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      metrics.batch(size: events.length)
      operations, failures = map(events)
      result = sink.write(operations)
      failures.concat(result.failed)

      quarantine.write(failures)
      report_failures(failures)
      result.succeeded.each { |operation| metrics.processed(operation:) }

      consumer.mark_message_as_processed(events.last.message)
    ensure
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      metrics.processing_time(milliseconds: elapsed * 1000)
    end

    def map(events)
      operations = []
      failures = []

      events.each do |event|
        metrics.received(event:)
        if event.failed?
          failures << failure_for(event, :source, event.error)
        elsif event.skip?
          metrics.skipped(event:)
        else
          operation = mapper.map(event)
          operations << operation if operation
        end
      rescue StandardError => e
        failures << failure_for(event, :mapping, e)
      end

      [operations, failures]
    end

    def failure_for(event, stage, error)
      Failure.new(event:, stage:, error:, id: event.id, attempts: 1)
    end

    def report_failures(failures)
      failures.each do |failure|
        metrics.failed(stage: failure.stage)
        metrics.quarantined(stage: failure.stage)
        notifier.notify(failure.error, context: honeybadger_context(failure))
      rescue StandardError => e
        Utils.logger.error("Unable to report quarantined record to Honeybadger: #{e.class}: #{e.message}")
      end
    end

    def honeybadger_context(failure)
      {
        document_id: failure.id,
        source: failure.event.source,
        source_topic: failure.event.topic,
        source_partition: failure.event.partition,
        source_offset: failure.event.offset,
        stage: failure.stage,
        attempts: failure.attempts,
        response_status: failure.error.respond_to?(:status) ? failure.error.status : nil,
        response_body: failure.error.respond_to?(:body) ? failure.error.body.to_s.slice(0, 4000) : nil
      }
    end

    def close
      sink.close
    ensure
      quarantine.close
    end
  end
end
