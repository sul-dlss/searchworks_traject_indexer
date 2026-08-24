# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SolrDocumentReader do
  subject(:reader) do
    described_class.new(
      solr_url: 'https://solr.example/solr/searchworks',
      fields: %w[id title],
      query: 'format:Book',
      page_size: 2,
      http_client:
    )
  end

  let(:http_client) { instance_double(HTTPClient) }

  it 'reads a limited, deterministic sample with cursor pagination' do
    allow(http_client).to receive(:get).and_return(
      response(body: { response: { docs: [{ 'id' => '1' }, { 'id' => '2' }] }, nextCursorMark: 'next' }),
      response(body: { response: { docs: [{ 'id' => '3' }] }, nextCursorMark: 'done' })
    )

    expect(reader.each(limit: 3).to_a).to eq([{ 'id' => '1' }, { 'id' => '2' }, { 'id' => '3' }])
    expect(http_client).to have_received(:get).with(
      'https://solr.example/solr/searchworks/select',
      hash_including('q' => 'format:Book', 'fl' => 'id,title', 'sort' => 'id asc', 'rows' => 2, 'cursorMark' => '*')
    )
    expect(http_client).to have_received(:get).with(
      'https://solr.example/solr/searchworks/select',
      hash_including('rows' => 1, 'cursorMark' => 'next')
    )
  end

  it 'raises a useful error when Solr rejects the request' do
    allow(http_client).to receive(:get).and_return(response(status: 500, body: { error: 'failed' }))

    expect { reader.each(limit: 1).to_a }.to raise_error(described_class::Error, /HTTP 500/)
  end

  def response(body:, status: 200)
    instance_double(HTTP::Message, status:, body: JSON.fast_generate(body))
  end
end
