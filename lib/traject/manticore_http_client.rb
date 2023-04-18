# frozen_string_literal: true

require 'manticore'
require 'retriable'

class Traject::ManticoreHttpClient
  attr_accessor :receive_timeout

  def initialize
    @client = Manticore::Client.new
  end

  def post(url, body, headers = {})
    response = Retriable.retriable on: [SocketError, Errno::ECONNREFUSED, StandardError], multiplier: 10 do
      @client.post(url, headers:, body:, request_timeout: 60 * 10, socket_timeout: 60 * 10).tap do |resp|
        raise "Solr error response: #{resp.code}: #{resp.body}" if resp.code != 200
      end
    end

    OpenStruct.new(body: response.body, status: response.code)
  end

  def get(url, params)
    # Fire and forget
    @client.background.get(url, params:, request_timeout: 60 * 10, socket_timeout: 60 * 10).call

    OpenStruct.new(body: '{}', status: 200)
  end
end
