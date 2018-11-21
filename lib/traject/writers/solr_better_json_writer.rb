class Traject::SolrBetterJsonWriter < Traject::SolrJsonWriter
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

      batch.each do |c|
        send_single(c)
      end
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
    end
  end

  def generate_json(batch)
    arr = []

    batch.each do |c|
      if c.skip?
        arr << "delete: #{JSON.generate(id: c.output_hash['id'])}"
      else
        arr << "add: #{JSON.generate(doc: c.output_hash)}"
      end
    end

    '{' + arr.join(",\n") + '}'
  end
end
