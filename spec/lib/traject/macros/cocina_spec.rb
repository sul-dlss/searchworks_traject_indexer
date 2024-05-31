# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/traject/macros/cocina'

RSpec.describe Traject::Macros::Cocina do
  include Traject::Macros::Cocina

  subject(:result) { macro.call(record, []) }

  let(:druid) { 'vv853br8653' }
  let(:body) { File.read(file_fixture("#{druid}.json")) }
  let(:record) { PurlRecord.new(druid) }

  before do
    stub_request(:get, "https://purl.stanford.edu/#{druid}.xml").to_return(status: 404)
    stub_request(:get, "https://purl.stanford.edu/#{druid}.json").to_return(status: 200, body:)
  end

  describe 'cocina_descriptive' do
    context 'with a single field' do
      let(:macro) { cocina_descriptive(:note) }

      it 'returns the items in the field' do
        expect(result).to eq record.cocina_description.note
      end
    end

    context 'with nested fields' do
      let(:macro) { cocina_descriptive(:event, :date) }

      it 'returns the nested items as a flattened array' do
        expect(result).to eq record.cocina_description.event.flat_map(&:date)
      end
    end
  end
end
