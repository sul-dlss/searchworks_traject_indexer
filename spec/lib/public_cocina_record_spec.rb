# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PublicCocinaRecord do
  let(:druid) { 'bb021mm7809' }
  let(:purl_url) { 'https://purl.stanford.edu' }
  let(:public_cocina_record) { described_class.new(druid, purl_url:) }
  let(:body) { File.new(file_fixture("#{druid}.json")) }

  before do
    stub_request(:get, "https://purl.stanford.edu/#{druid}.json").to_return(status: 200, body:)
  end

  describe '#public_cocina?' do
    it 'returns true' do
      expect(public_cocina_record.public_cocina?).to be true
    end
  end

  describe '#public_cocina' do
    it 'returns a response body' do
      expect(public_cocina_record.public_cocina).not_to be nil
    end
  end

  describe '#public_cocina_doc' do
    it 'returns a JSON hash' do
      expect(public_cocina_record.public_cocina_doc).to be_a(Hash)
    end
  end
end
