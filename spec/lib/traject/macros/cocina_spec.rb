# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/traject/macros/cocina'

RSpec.describe Traject::Macros::Cocina do
  include Traject::Macros::Cocina

  let(:accumulator) { [] }
  let(:context) { Traject::Indexer::Context.new(source_record: record) }
  let(:output_hash) { {} }
  let(:druid) { 'fk339wc1276' }
  let(:body) { File.read(file_fixture("#{druid}.json")) }
  let(:record) { PurlRecord.new(druid) }
  let(:settings) do
    {
      'purl.url' => 'https://purl.stanford.edu',
      'stacks.url' => 'https://stacks.stanford.edu'
    }
  end

  before do
    stub_request(:get, "https://purl.stanford.edu/#{druid}.xml").to_return(status: 404)
    stub_request(:get, "https://purl.stanford.edu/#{druid}.json").to_return(status: 200, body:)
    allow(context).to receive(:output_hash).and_return(output_hash)
    macro.call(record, accumulator, context)
  end

  describe 'cocina_descriptive' do
    context 'with a single field' do
      let(:macro) { cocina_descriptive(:note) }

      it 'returns the items in the field' do
        expect(accumulator).to eq record.cocina_description.note
      end
    end

    context 'with nested fields' do
      let(:macro) { cocina_descriptive(:event, :date) }

      it 'returns the nested items as a flattened array' do
        expect(accumulator).to eq record.cocina_description.event.flat_map(&:date)
      end
    end
  end

  describe 'stacks_file_url' do
    let(:macro) { stacks_file_url }

    context 'with file objects' do
      let(:accumulator) { record.cocina_structural.contains[0].structural.contains }

      it 'returns the URLs for the files' do
        expect(accumulator).to eq [
          'https://stacks.stanford.edu/file/druid:fk339wc1276/Stanford_Temperature_Model_4km.geojson'
        ]
      end
    end

    context 'with no files' do
      it 'returns an empty array' do
        expect(accumulator).to eq []
      end
    end
  end

  describe 'select_files' do
    context 'with a filename string' do
      let(:macro) { select_files('preview.jpg') }

      it 'returns the files with the matching filename' do
        expect(accumulator.map(&:filename)).to eq ['preview.jpg']
      end
    end

    context 'with a filename regex' do
      let(:macro) { select_files(/\.xml$/) }

      it 'returns the files with filenames matching the regex' do
        expect(accumulator.map(&:filename)).to eq [
          'Stanford_Temperature_Model_4km.geojson.xml',
          'Stanford_Temperature_Model_4km-iso19139.xml',
          'Stanford_Temperature_Model_4km-iso19110.xml',
          'Stanford_Temperature_Model_4km-fgdc.xml'
        ]
      end
    end

    context 'with a filtered list of files' do
      let(:accumulator) { record.cocina_structural.contains[2].structural.contains }
      let(:macro) { select_files(/-iso/) }

      it 'operates on the files in the list' do
        expect(accumulator.map(&:filename)).to eq [
          'Stanford_Temperature_Model_4km-iso19139.xml',
          'Stanford_Temperature_Model_4km-iso19110.xml'
        ]
      end
    end

    context 'when there are no matches' do
      let(:macro) { select_files('missing.jpg') }

      it 'returns an empty array' do
        expect(accumulator).to eq []
      end
    end
  end

  describe 'find_file' do
    context 'with a filename string' do
      let(:macro) { find_file('preview.jpg') }

      it 'returns the file with the matching filename' do
        expect(accumulator.first.filename).to eq 'preview.jpg'
      end
    end

    context 'with a filename regex' do
      let(:macro) { find_file(/\.xml$/) }

      it 'returns the first file with a filename matching the regex' do
        expect(accumulator.first.filename).to eq 'Stanford_Temperature_Model_4km.geojson.xml'
      end
    end

    context 'when the file is not found' do
      let(:macro) { find_file('missing.jpg') }

      it 'returns an empty array' do
        expect(accumulator).to eq []
      end
    end
  end

  describe 'extract_unique_years_sorted' do
    let(:macro) { extract_unique_years_sorted }

    context 'with an array of dates' do
      let(:accumulator) { %w[2020 2020-2021 2021 2019 2019-2020] }

      it 'returns the unique years sorted' do
        expect(accumulator).to eq [2019, 2020, 2021]
      end
    end

    context 'with an array of dates and other strings' do
      let(:accumulator) { ['2020', '2020-2021', '2021', '2019', '2019-2020', 'not a date'] }

      it 'returns the unique years sorted' do
        expect(accumulator).to eq [2019, 2020, 2021]
      end
    end

    context 'with an empty array' do
      it 'returns an empty array' do
        expect(accumulator).to eq []
      end
    end
  end
end
