require 'spec_helper'

RSpec.describe Traject::PurlFetcherReader do
  subject(:reader) { described_class.new('', settings) }
  let(:settings) { {} }

  describe '#each' do
    before do
      if defined? JRUBY_VERSION
        expect(Manticore).to receive(:get).with(%r{/docs/changes}, query: anything).and_return(double(body: body))
        expect(Manticore).to receive(:get).with(%r{/docs/deletes}, query: anything).and_return(double(body: '{ "deletes": [], "pages": {} }'))
      else
        expect(HTTP).to receive(:get).with(%r{/docs/changes}, params: anything).and_return(double(body: body))
        expect(HTTP).to receive(:get).with(%r{/docs/deletes}, params: anything).and_return(double(body: '{ "deletes": [], "pages": {} }'))
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
      expect(reader.each.map { |x| x['druid'] }).to eq ['x', 'y', 'z']
    end
  end
end
