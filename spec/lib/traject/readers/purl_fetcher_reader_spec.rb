require 'spec_helper'

RSpec.describe Traject::PurlFetcherReader do
  subject(:reader) { described_class.new('', settings) }
  let(:settings) { {} }

  describe '#each' do
    before do
      if defined? JRUBY_VERSION
        expect(Manticore).to receive(:get).with(%r{/docs/changes}, query: hash_including(target: 'Searchworks')).and_return(double(body: body))
      else
        expect(HTTP).to receive(:get).with(%r{/docs/changes}, params: hash_including(target: 'Searchworks')).and_return(double(body: body))
      end
    end

    let(:body) {
      {
        changes: [
          { druid: 'x', true_targets: ['Searchworks'] },
          { druid: 'y', true_targets: ['Searchworks'] },
          { druid: 'z', true_targets: ['SomethingElse'] }
        ],
        pages: { }
      }.to_json
    }

    it 'returns objects from the purl-fetcher api' do
      expect(reader.each.map(&:druid)).to eq ['x', 'y']
    end
  end
end
