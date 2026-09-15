# frozen_string_literal: true

require 'json'

# Reads a deterministic, bounded stream of documents from a Solr collection.
class SolrDocumentReader
  DEFAULT_PAGE_SIZE = 100

  class Error < StandardError; end

  def initialize(solr_url:, fields:, query: '*:*', page_size: DEFAULT_PAGE_SIZE, http_client: nil)
    raise ArgumentError, 'Source Solr URL is required' if solr_url.to_s.empty?
    raise ArgumentError, 'Solr fields are required' if fields.empty?

    @url = "#{solr_url.to_s.sub(%r{/+\z}, '')}/select"
    @fields = fields
    @query = query
    @page_size = Integer(page_size)
    raise ArgumentError, 'page_size must be positive' unless @page_size.positive?

    @http_client = http_client || HTTPClient.new.tap do |client|
      client.connect_timeout = 60
      client.receive_timeout = 60
      client.send_timeout = 60
    end
  end

  def each(limit: nil, &block)
    return enum_for(__method__, limit:) unless block_given?

    limit = Integer(limit) if limit
    raise ArgumentError, 'limit must be positive' if limit && !limit.positive?

    cursor_mark = '*'
    emitted = 0

    loop do
      rows = limit ? [@page_size, limit - emitted].min : @page_size
      documents, next_cursor_mark = fetch_page(cursor_mark:, rows:)
      documents.each(&block)
      emitted += documents.length

      break if documents.empty? || next_cursor_mark == cursor_mark || (limit && emitted >= limit)

      cursor_mark = next_cursor_mark
    end

    emitted
  end

  private

  def fetch_page(cursor_mark:, rows:)
    response = @http_client.get(
      @url,
      {
        'q' => @query,
        'fl' => @fields.join(','),
        'sort' => 'id asc',
        'rows' => rows,
        'cursorMark' => cursor_mark,
        'wt' => 'json'
      }
    )
    validate_response(response)

    body = JSON.parse(response.body.to_s)
    [body.fetch('response').fetch('docs'), body.fetch('nextCursorMark')]
  rescue Error
    raise
  rescue StandardError => e
    raise Error, "Source Solr request failed: #{e.class}: #{e.message}"
  end

  def validate_response(response)
    return if response.status.to_i.between?(200, 299)

    raise Error, "Source Solr returned HTTP #{response.status}: #{response.body.to_s.slice(0, 500)}"
  end
end
