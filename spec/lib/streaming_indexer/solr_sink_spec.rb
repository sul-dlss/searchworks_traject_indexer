# frozen_string_literal: true

require 'spec_helper'

class StreamingSolrStubHttpClient
  attr_reader :requests

  def initialize(responses)
    @responses = responses
    @requests = []
  end

  def post(url, body, headers)
    @requests << [url, body, headers]
    response = @responses.shift
    raise response if response.is_a?(Exception)

    response
  end
end

RSpec.describe StreamingIndexer::SolrSink do
  subject(:sink) do
    described_class.new(
      {
        'solr.update_url' => 'http://example.com/solr/update',
        'streaming.solr.http_client' => http_client,
        'streaming.solr.batch_size' => 100
      },
      retry_policy:
    )
  end

  let(:retry_policy) do
    StreamingIndexer::RetryPolicy.new(max_attempts: 3, base_interval: 0, sleeper: Kernel, random: Random)
  end
  let(:success) { double(status: 200, body: '') }
  let(:event) { SourceEvent.new(source: :folio, message: double) }
  let(:add) { StreamingIndexer::Operation.add(id: '1', document: { 'id' => '1' }, event:) }
  let(:delete) { StreamingIndexer::Operation.delete(id: '2', event:) }
  let(:http_client) { StreamingSolrStubHttpClient.new([success]) }

  it 'sends adds and deletes in one ordered Solr request' do
    result = sink.write([add, delete])

    expect(result.succeeded).to eq [add, delete]
    expect(result.failed).to be_empty
    expect(http_client.requests.first[1]).to eq("{\"add\":{\"doc\":{\"id\":\"1\"}},\n\"delete\":\"2\"}")
  end

  it 'retries a failed batch and succeeds' do
    failed = double(status: 503, body: 'unavailable')
    http_client = StreamingSolrStubHttpClient.new([failed, success])
    sink = described_class.new(
      { 'solr.update_url' => 'http://example.com/solr/update', 'streaming.solr.http_client' => http_client },
      retry_policy:
    )

    expect(sink.write([add]).succeeded).to eq [add]
    expect(http_client.requests.length).to eq 2
  end

  it 'makes only three attempts for one permanently failing record' do
    failed = double(status: 400, body: 'bad document')
    http_client = StreamingSolrStubHttpClient.new([failed, failed, failed])
    sink = described_class.new(
      { 'solr.update_url' => 'http://example.com/solr/update', 'streaming.solr.http_client' => http_client },
      retry_policy:
    )

    result = sink.write([add])

    expect(result.failed.map(&:id)).to eq ['1']
    expect(http_client.requests.length).to eq 3
  end

  it 'isolates permanently failing records after a batch fails' do
    failed = double(status: 400, body: 'bad document')
    # Three batch failures, then the first record succeeds and the second fails three times.
    http_client = StreamingSolrStubHttpClient.new([failed, failed, failed, success, failed, failed, failed])
    sink = described_class.new(
      { 'solr.update_url' => 'http://example.com/solr/update', 'streaming.solr.http_client' => http_client },
      retry_policy:
    )

    result = sink.write([add, delete])

    expect(result.succeeded).to eq [add]
    expect(result.failed.map(&:id)).to eq ['2']
    expect(result.failed.first).to have_attributes(stage: :solr, attempts: 3)
  end
end
