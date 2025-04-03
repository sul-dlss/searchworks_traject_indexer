# frozen_string_literal: true

require 'debouncer'

class Traject::SolrBetterJsonWriter < Traject::SolrJsonWriter
  module IndexerPatch
    def log_skip(context)
      if writer_class == Traject::SolrBetterJsonWriter
        writer.put(context)
      else
        logger.debug "Skipped record #{context.record_inspect}: #{context.skipmessage}"
      end
    end
  end

  def initialize(*args)
    super

    @debouncer = Debouncer.new(@settings['solr_better_json_writer.debounce_timeout'] || 60, &method(:drain_queue))
    @retry_count = 0
  end

  # Add a single context to the queue, ready to be sent to solr
  def put(context)
    @thread_pool.raise_collected_exception!

    @batched_queue << context

    @debouncer.group(:put).call
    @debouncer.group(:put).flush if @batched_queue.size >= @batch_size
  end

  def drain_queue
    contexts = Traject::Util.drain_queue(@batched_queue)
    @thread_pool.maybe_in_thread_pool(contexts) { |batch_arg| send_batch(batch_arg) }
  end

  # Send the given batch of contexts. If something goes wrong, send
  # them one at a time.
  # @param [Array<Traject::Indexer::Context>] an array of contexts
  def send_batch(contexts)
    batch = Batch.new(contexts)
    return if batch.empty?

    begin
      resp = @http_client.post @solr_update_url, batch.generate_json, 'Content-type' => 'application/json'
    rescue StandardError => e
    end

    if e || resp.status != 200
      error_message = if e
                        Traject::Util.exception_to_log_message(e)
                      else
                        "Solr response: #{resp.status}: #{resp.body}"
                      end

      logger.error "Error in Solr batch add. Will retry documents individually at performance penalty: #{error_message}"

      @retry_count += 1

      batch.each do |context|
        sleep rand(0..max_sleep_seconds)
        if send_single(context)
          @retry_count = [0, @retry_count - 0.1].min
        else
          @retry_count += 0.1
        end
      end
    else
      @retry_count = 0
      SdrEvents.report_indexing_batch_success(batch, target: @settings['purl_fetcher.target'])
    end
  end

  # Send a single context to Solr, logging an error if need be
  # @param [Traject::Indexer::Context] c The context whose document you want to send
  def send_single(context)
    batch = Batch.new([context])

    begin
      resp = @http_client.post @solr_update_url, batch.generate_json, 'Content-type' => 'application/json'
      # Catch Timeouts and network errors as skipped records, but otherwise
      # allow unexpected errors to propagate up.
    rescue *skippable_exceptions => e
      # no body, local variable exception set above will be used below
    end

    if e || resp.status != 200
      msg = if e
              Traject::Util.exception_to_log_message(e)
            else
              "Solr error response: #{resp.status}: #{resp.body}"
            end
      logger.error "Could not add record #{context.record_inspect}: #{msg}"
      logger.debug("\t" + e.backtrace.join("\n\t")) if e
      logger.debug(context.source_record.to_s) if context.source_record

      @skipped_record_incrementer.increment
      if @max_skipped and skipped_record_count > @max_skipped
        raise MaxSkippedRecordsExceeded,
              "#{self.class.name}: Exceeded maximum number of skipped records (#{@max_skipped}): aborting"
      end

      SdrEvents.report_indexing_batch_errored(batch, target: @settings['purl_fetcher.target'], exception: msg)
      return false
    else
      SdrEvents.report_indexing_batch_success(batch, target: @settings['purl_fetcher.target'])
    end

    true
  end

  def max_sleep_seconds
    Float(2**@retry_count)
  end

  # Collection of Traject contexts to be sent to solr
  class Batch
    def initialize(contexts)
      @contexts = contexts
    end

    def empty?
      @contexts.empty?
    end

    def each(&)
      @contexts.each(&)
    end

    # Array of [action, druid, data] triples, where action is :add or :delete
    # and data is either the doc id or the full doc hash. Druid is empty for
    # non-SDR content.
    def actions
      @actions ||= @contexts.map do |context|
        record = context.source_record
        druid = record&.druid if record.respond_to?(:druid)

        if context.skip?
          id = Array(context.output_hash['id']).first
          [:delete, druid, id] if id
        else
          [:add, druid, context.output_hash]
        end
      end.compact
    end

    # Make a JSON string for sending to solr /update API
    def generate_json
      actions.map do |action, _druid, data|
        case action
        when :delete
          "\"delete\":#{JSON.generate(data)}"
        when :add
          "\"add\":#{JSON.generate(doc: data)}"
        end
      end.join(",\n").prepend('{').concat('}')
    end
  end
end
