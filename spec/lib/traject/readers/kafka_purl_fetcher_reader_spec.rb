# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Traject::KafkaPurlFetcherReader do
  subject(:reader) { described_class.new('', settings) }
  let(:consumer) { double }
  let(:settings) { { 'kafka.consumer' => consumer, 'purl.url' => 'https://example.com' } }

  describe '#each' do
    before do
      allow(consumer).to receive(:each_message).and_yield(double(key: 'x',
                                                                 value: {
                                                                   druid: 'x', true_targets: ['Searchworks']
                                                                 }.to_json))
                                               .and_yield(double(key: 'y',
                                                                 value: {
                                                                   druid: 'y', true_targets: ['Searchworks'], catkey: ''
                                                                 }.to_json))
                                               .and_yield(double(key: 'deleted',
                                                                 value: {
                                                                   druid: 'y', true_targets: ['Searchworks'], catkey: 'catkey'
                                                                 }.to_json))
                                               .and_yield(double(key: 'z',
                                                                 value: {
                                                                   druid: 'z', true_targets: ['SomethingElse']
                                                                 }.to_json))

      stub_request(:get, 'https://example.com/x.xml')
        .to_return(status: 200, body: '<publicObject />')
      stub_request(:get, 'https://example.com/x.json')
        .to_return(status: 200, body: '{}')
      stub_request(:get, 'https://example.com/y.xml')
        .to_return(status: 200, body: '<publicObject />')
      stub_request(:get, 'https://example.com/y.json')
        .to_return(status: 200, body: '{}')
    end

    it 'passes the purl url through' do
      expect(reader.each.find { |x| x.is_a? PurlRecord }.purl_url).to eq 'https://example.com'
    end

    it 'returns objects from the purl-fetcher api' do
      expect(reader.each.select { |x| x.is_a? PurlRecord }.map(&:druid)).to eq %w[x y]
    end

    it 'returns deletes for objects with a catkey' do
      expect(reader.each.reject { |x| x.is_a? PurlRecord }.map { |x| x[:id] }).to eq ['deleted']
    end
  end
end
