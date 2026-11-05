# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PurlRecord do
  subject(:record) { described_class.new(druid) }

  context 'with an object without public_xml or public_cocina' do
    let(:druid) { 'missing' }

    before do
      stub_request(:get, "https://purl.stanford.edu/#{druid}.xml").to_return(status: 404)
      stub_request(:get, "https://purl.stanford.edu/#{druid}.json").to_return(status: 404)
    end

    describe '#searchworks_id' do
      it 'returns the druid' do
        expect(record.searchworks_id).to eq druid
      end
    end

    describe '#label' do
      it 'returns nil' do
        expect(record.label).to be_nil
      end
    end
  end

  context 'when PURL has a transient network failure' do
    let(:druid) { 'bc123df4567' }

    before do
      stub_request(:get, "https://purl.stanford.edu/#{druid}.json")
        .to_raise(Errno::ECONNRESET).then
        .to_return(status: 200, body: { externalIdentifier: "druid:#{druid}" }.to_json)
      stub_request(:get, "https://purl.stanford.edu/#{druid}.meta_json")
        .to_timeout.then
        .to_return(status: 200, body: { searchworks: true, earthworks: false }.to_json)
    end

    it 'retries fetching the public cocina' do
      expect(record.public_cocina?).to be true
      expect(a_request(:get, "https://purl.stanford.edu/#{druid}.json")).to have_been_made.twice
    end

    it 'retries fetching the public meta json' do
      expect(record.released_to_searchworks?).to be true
      expect(a_request(:get, "https://purl.stanford.edu/#{druid}.meta_json")).to have_been_made.twice
    end
  end

  context 'when PURL persistently fails' do
    let(:druid) { 'bc123df4567' }

    before do
      stub_request(:get, "https://purl.stanford.edu/#{druid}.json").to_raise(Errno::ECONNRESET)
    end

    it 'raises after exhausting retries' do
      expect { record.public_cocina }.to raise_error(Errno::ECONNRESET)
      expect(a_request(:get, "https://purl.stanford.edu/#{druid}.json")).to have_been_made.times(5)
    end
  end
end
