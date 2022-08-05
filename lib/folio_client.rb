require 'http'
require_relative 'folio_record'

class FolioClient
  DEFAULT_HEADERS = {
    accept: 'application/json, text/plain',
    content_type: 'application/json'
  }.freeze

  attr_reader :base_url

  def initialize(url:, username: nil, password: nil, tenant: 'sul')
    uri = URI.parse(url)

    @base_url = url
    @username = username
    @password = password

    if uri.user
      @username ||= uri.user
      @password ||= uri.password
      @base_url = uri.dup.tap { |u| u.user = nil; u.password = nil }.to_s
    end

    @tenant = tenant
  end

  def get(path, **kwargs)
    authenticated_request(path, method: :get, **kwargs)
  end

  def get_json(path, **kwargs)
    parse(get(path, **kwargs))
  end

  def source_record(**kwargs)
    FolioRecord.new(get_json("/source-storage/source-records", params: kwargs).dig('sourceRecords', 0), self)
  end

  def parse(response)
    return nil if response.body.empty?

    JSON.parse(response.body)
  end

  def call_number_types
    @call_number_types ||= get_json('/call-number-types', params: { limit: 2147483647 }).dig('callNumberTypes').each_with_object({}) do |type, hash|
      hash[type['id']] = type
    end
  end

  def session_token
    @session_token ||= begin
      response = request('/authn/login', json: { username: @username, password: @password }, method: :post)
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
