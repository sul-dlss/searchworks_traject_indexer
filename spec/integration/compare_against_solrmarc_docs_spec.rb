# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'comparing against a well-known location full of documents' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  MARC::JSONLReader.new(File.expand_path('input.jsonl', file_fixture_path)).each do |input_marc|
    context "with #{input_marc['001'].value}" do
      subject(:result) { indexer.map_record(marc_to_folio_with_stubbed_holdings(input_marc)).transform_values { |v| v.sort } }
      let(:input_id) { input_marc['001'].value.delete_prefix('a') }

      let(:expected_doc) do
        result = nil
        File.foreach(File.expand_path('output.jsonl', file_fixture_path)) do |line|
          result = JSON.parse(line)
          break if result['id'].first == input_id
        end
        result
      end

      it 'maps the same general output' do
        # Stub the year so pub_year_tisim test doesn't fail every January
        allow_any_instance_of(Time).to receive(:year).and_return(2019)
        expect(result).to include expected_doc
      end
    end
  end
end
