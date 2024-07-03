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
end
