# frozen_string_literal: true

require 'folio_client'

RSpec.describe FolioClient do
  subject(:client) { described_class.new(url:) }
  let(:url) { 'https://example.com' }

  before do
    stub_request(:post, 'https://example.com/authn/login')
      .to_return(headers: { 'x-okapi-token': 'tokentokentoken' }, status: 201)
  end

  describe '#get' do
    before do
      stub_request(:get, 'https://example.com/blah')
        .with(headers: { 'x-okapi-token': 'tokentokentoken', 'X-Okapi-Tenant': 'sul' })
        .to_return(body: 'Hi!')
    end

    it 'sends a get request with okapi auth headers' do
      expect(client.get('/blah').body.to_s).to eq('Hi!')
    end

    context 'with a method' do
      before do
        stub_request(:post, 'https://example.com/blah')
          .with(headers: { 'x-okapi-token': 'tokentokentoken', 'X-Okapi-Tenant': 'sul' })
          .to_return(body: 'Hi!')
      end

      it 'overrides the request type' do
        expect(client.get('/blah', method: :post).body.to_s).to eq('Hi!')
      end
    end
  end

  describe '#get_json' do
    before do
      stub_request(:get, 'https://example.com/blah')
        .to_return(body:)
    end

    let(:body) { '{"hello": "world"}' }

    it 'parses json responses into ruby objects' do
      expect(client.get_json('/blah')).to eq('hello' => 'world')
    end

    describe 'when the response is empty' do
      let(:body) { '' }

      it 'returns nil' do
        expect(client.get_json('/blah')).to be_nil
      end
    end
  end

  describe '#source_record' do
    before do
      stub_request(:get, 'https://example.com/source-storage/source-records?instanceHrid=a123')
        .with(headers: { 'x-okapi-token': 'tokentokentoken', 'X-Okapi-Tenant': 'sul' })
        .to_return(body:)
    end

    let(:body) do
      {
        sourceRecords: [
          {
            externalIdsHolder: {
              instanceId: 'uuid'
            }
          }
        ]
      }.to_json
    end

    it 'returns a FolioRecord' do
      expect(client.source_record(instanceHrid: 'a123')).to have_attributes(instance_id: 'uuid')
    end
  end
end
