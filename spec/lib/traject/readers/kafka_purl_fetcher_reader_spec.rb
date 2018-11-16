require 'spec_helper'

RSpec.describe Traject::KafkaPurlFetcherReader do
  subject(:reader) { described_class.new('', settings) }
  let(:consumer) { double }
  let(:settings) { { 'kafka.consumer' => consumer } }

  describe '#each' do
    before do
      allow(consumer).to receive(:each_message).and_yield(double(key: 'x', value: { druid: 'x', true_targets: ['Searchworks'] }.to_json))
                                               .and_yield(double(key: 'y', value: { druid: 'y', true_targets: ['Searchworks'] }.to_json))
                                               .and_yield(double(key: 'z', value: { druid: 'z', true_targets: ['SomethingElse'] }.to_json))


      allow(PublicXmlRecord).to receive(:fetch).and_return('<publicObject />')
    end

    it 'returns objects from the purl-fetcher api' do
      expect(reader.each.map(&:druid)).to eq ['x', 'y']
    end
  end
end
