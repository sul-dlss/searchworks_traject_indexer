# frozen_string_literal: true

require 'folio_client'

RSpec.describe FolioClient do
  subject(:client) { described_class.new(url:) }
  let(:url) { 'https://example.com' }

  before do
    stub_request(:post, 'https://example.com/authn/login')
      .to_return(headers: { 'x-okapi-token': 'tokentokentoken' })
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
    subject(:request) { client.get_json('/blah') }

    context 'when the status is ok' do
      before do
        stub_request(:get, 'https://example.com/blah')
          .to_return(body: '{"hello": "world"}')
      end

      it { is_expected.to eq('hello' => 'world') }
    end

    context 'when the status is not ok' do
      before do
        stub_request(:get, 'https://example.com/blah')
          .with(headers: { 'x-okapi-token': 'tokentokentoken', 'X-Okapi-Tenant': 'sul' })
          .to_return(body: 'Verboten!', status: 401)
      end

      it 'raises an error' do
        expect { request }.to raise_error 'Verboten!'
      end
    end

    context 'when the response is empty' do
      before do
        stub_request(:get, 'https://example.com/blah')
          .to_return(body: '')
      end

      it { is_expected.to be_nil }
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
