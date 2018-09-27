require 'manticore'

class Traject::ManticoreHttpClient
  attr_accessor :receive_timeout

  def initialize
    @client = Manticore::Client.new
  end

  def post url, body, headers = {}
    response = @client.post(url, headers: headers, body: body, socket_timeout: 60)

    OpenStruct.new(body: response.body, status: response.code)
  end

  def get url, params
    response = @client.get(url, params: params, request_timeout: 60*10, socket_timeout: 60*10)

    OpenStruct.new(body: response.body, status: response.code)
  end
end
