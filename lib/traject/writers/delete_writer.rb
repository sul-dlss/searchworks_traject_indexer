require 'traject/solr_json_writer'

class Traject::DeleteWriter < Traject::SolrJsonWriter

  ##
  # Custom overload of method to send batch deletes
  # Send the given batch of contexts. If something goes wrong, send
  # them one at a time.
  # @param [Array<Traject::Indexer::Context>] an array of contexts
  def send_batch(batch)
    return if batch.empty?
    json_package = JSON.generate(delete: batch.map { |c| c.output_hash.map{ |h| h[1] } }.flatten)
    begin
      resp = @http_client.post @solr_update_url, json_package, 'Content-type' => 'application/json'
    rescue StandardError => exception
    end

    if exception || resp.status != 200
      error_message = exception ?
        Traject::Util.exception_to_log_message(exception) :
        "Solr response: #{resp.status}: #{resp.body}"

      logger.error "Error in Solr batch delete. Will retry documents individually at performance penalty: #{error_message}"

      batch.each do |c|
        send_single(c)
      end
    end
  end

  ##
  # Custom overload for single deletes
  # Send a single context to Solr, logging an error if need be
  # @param [Traject::Indexer::Context] c The context whose document you want to send
  def send_single(c)
    json_package = JSON.generate(delete: c.output_hash['id'])
    begin
      resp = @http_client.post @solr_update_url, json_package, 'Content-type' => 'application/json'
      # Catch Timeouts and network errors as skipped records, but otherwise
      # allow unexpected errors to propagate up.
    rescue HTTPClient::TimeoutError, SocketError, Errno::ECONNREFUSED => exception
    end

    if exception || resp.status != 200
      if exception
        msg = Traject::Util.exception_to_log_message(exception)
      else
        msg = "Solr error response: #{resp.status}: #{resp.body}"
      end
      logger.error "Could not delete record #{c.source_record_id} at source file position #{c.position}: #{msg}"
      logger.debug(c.source_record.to_s)

      @skipped_record_incrementer.increment
      if @max_skipped and skipped_record_count > @max_skipped
        raise RuntimeError.new("#{self.class.name}: Exceeded maximum number of skipped records (#{@max_skipped}): aborting")
      end
    end
  end
end
