require 'spec_helper'
require 'utils'

RSpec.describe Traject::KafkaPurlFetcherReader do
  subject(:reader) { described_class.new('', settings) }
  let(:consumer) { double }
  let(:settings) { { 'kafka.consumer' => consumer } }

  describe '#each' do
    before do
      allow(consumer).to receive(:each_message).and_yield(double(key: 'x', value: { druid: 'x', true_targets: ['Searchworks'] }.to_json))
                                               .and_yield(double(key: 'y', value: { druid: 'y', true_targets: ['Searchworks'], catkey:  '' }.to_json))
                                               .and_yield(double(key: 'deleted', value: { druid: 'y', true_targets: ['Searchworks'], catkey:  'catkey' }.to_json))
                                               .and_yield(double(key: 'z', value: { druid: 'z', true_targets: ['SomethingElse'] }.to_json))


      allow(PublicXmlRecord).to receive(:fetch).and_return('<publicObject />')
    end

    it 'returns objects from the purl-fetcher api' do
      expect(reader.each.select { |x| x.is_a? PublicXmlRecord }.map(&:druid)).to eq ['x', 'y']
    end

    it 'returns deletes for objects with a catkey' do
      expect(reader.each.reject { |x| x.is_a? PublicXmlRecord }.map { |x| x[:id] }).to eq ['deleted']
    end
  end
end
