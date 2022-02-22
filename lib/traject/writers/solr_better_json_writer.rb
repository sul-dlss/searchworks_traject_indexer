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

    @debouncer = Debouncer.new(@settings["solr_better_json_writer.debounce_timeout"] || 60, &method(:drain_queue))
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
    batch = Traject::Util.drain_queue(@batched_queue)
    @thread_pool.maybe_in_thread_pool(batch) { |batch_arg| send_batch(batch_arg) }
  end

  # Send the given batch of contexts. If something goes wrong, send
  # them one at a time.
  # @param [Array<Traject::Indexer::Context>] an array of contexts
  def send_batch(batch)
    return if batch.empty?
    json_package = generate_json(batch)
    begin
      resp = @http_client.post @solr_update_url, json_package, "Content-type" => "application/json"
    rescue StandardError => exception
    end

    if exception || resp.status != 200
      error_message = exception ?
        Traject::Util.exception_to_log_message(exception) :
        "Solr response: #{resp.status}: #{resp.body}"

      logger.error "Error in Solr batch add. Will retry documents individually at performance penalty: #{error_message}"

      @retry_count += 1

      batch.each do |c|
        sleep rand(0..max_sleep_seconds)
        if send_single(c)
          @retry_count = [0, @retry_count - 0.1].min
        else
          @retry_count += 0.1
        end
      end
    else
      @retry_count = 0
    end
  end

  # Send a single context to Solr, logging an error if need be
  # @param [Traject::Indexer::Context] c The context whose document you want to send
  def send_single(c)
    json_package = generate_json([c])
    begin
      resp = @http_client.post @solr_update_url, json_package, "Content-type" => "application/json"
      # Catch Timeouts and network errors as skipped records, but otherwise
      # allow unexpected errors to propagate up.
    rescue *skippable_exceptions => exception
      # no body, local variable exception set above will be used below
    end

    if exception || resp.status != 200
      if exception
        msg = Traject::Util.exception_to_log_message(exception)
      else
        msg = "Solr error response: #{resp.status}: #{resp.body}"
      end
      logger.error "Could not add record #{c.record_inspect}: #{msg}"
      logger.debug("\t" + exception.backtrace.join("\n\t")) if exception
      logger.debug(c.source_record.to_s) if c.source_record

      @skipped_record_incrementer.increment
      if @max_skipped and skipped_record_count > @max_skipped
        raise MaxSkippedRecordsExceeded.new("#{self.class.name}: Exceeded maximum number of skipped records (#{@max_skipped}): aborting")
      end

      return false
    end

    return true
  end

  def max_sleep_seconds
    Float(2 ** @retry_count)
  end

  def generate_json(batch)
    arr = []

    batch.each do |c|
      if c.skip?
        id = Array(c.output_hash['id']).first
        arr << "delete: #{JSON.generate(id)}" if id
      else
        arr << "add: #{JSON.generate(doc: c.output_hash)}"
      end
    end

    '{' + arr.join(",\n") + '}'
  end
end
