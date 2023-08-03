# frozen_string_literal: true

class FolioClient
  MAX_RESULTS_LIMIT = (2**31) - 1 # Folio max results
  DEFAULT_HEADERS = {
    accept: 'application/json, text/plain',
    content_type: 'application/json'
  }.freeze

  attr_reader :base_url

  def initialize(url: ENV.fetch('OKAPI_URL', ''), username: ENV.fetch('OKAPI_USER', nil), password: ENV.fetch('OKAPI_PASSWORD', nil), tenant: 'sul')
    uri = URI.parse(url)

    @base_url = url
    @username = username
    @password = password

    if uri.user
      @username ||= uri.user
      @password ||= uri.password
      @base_url = uri.dup.tap do |u|
        u.user = nil
        u.password = nil
      end.to_s
    end

    @tenant = tenant
  end

  def get(path, **kwargs)
    authenticated_request(path, method: :get, **kwargs)
  end

  def get_json(path, **kwargs)
    parse(get(path, **kwargs))
  end

  # Kwargs may include 'instanceHrid'
  def source_record(**kwargs)
    FolioRecord.new_from_source_record(
      get_json('/source-storage/source-records', params: kwargs).dig('sourceRecords', 0), self
    )
  end

  def pieces(instance_id:)
    get_json('/orders/pieces', params: { limit: MAX_RESULTS_LIMIT, query: "titles.instanceId==\"#{instance_id}\"" })
      .fetch('pieces')
  end

  def stream_source_records(updated_after:)
    get('/source-storage/stream/source-records',
        params: { limit: MAX_RESULTS_LIMIT, updatedAfter: updated_after })
  end

  def libraries
    get_json('/location-units/libraries', params: { limit: 2_147_483_647 }).fetch('loclibs', []).sort_by { |x| x['id'] }
  end

  def items_and_holdings(instance_id:)
    body = {
      instanceIds: [instance_id],
      skipSuppressedFromDiscoveryRecords: false
    }
    get_json('/inventory-hierarchy/items-and-holdings', method: :post, body: body.to_json)
  end

  def instance(instance_id:)
    get_json("/inventory/instances/#{instance_id}")
  end

  def statistical_codes
    @statistical_codes ||= get_json('/statistical-codes?limit=2000&query=cql.allRecords=1 sortby name').fetch('statisticalCodes')
  end

  private

  # @param [HTTP::Response] response
  # @raises [StandardError] if the response was not a 200
  # @return [Hash] the parsed JSON data structure
  def parse(response)
    raise response unless response.status.ok?
    return nil if response.body.empty?

    JSON.parse(response.body)
  end

  def session_token
    @session_token ||= begin
      response = request('/authn/login', json: { username: @username, password: @password }, method: :post)
      raise response.body unless response.status.created?

      response['x-okapi-token']
    end
  end

  def authenticated_request(path, headers: {}, **other)
    request(path, headers: headers.merge('x-okapi-token': session_token), **other)
  end

  def request(path, headers: {}, method: :get, **other)
    HTTP
      .headers(default_headers.merge(headers))
      .request(method, base_url + path, **other)
  end

  def default_headers
    DEFAULT_HEADERS.merge({ 'X-Okapi-Tenant': @tenant, 'User-Agent': 'FolioApiClient' })
  end
end
