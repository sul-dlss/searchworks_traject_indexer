require 'http'

class Traject::HttpRbHttpClient
  def initialize; end

  def post url, body, headers = {}
    HTTP.headers(headers).post(url, body: body)
  end

  def get url, params
    HTTP.timeout(read: 60*10).get(url, params: params)
  end

  def receive_timeout; end
end
