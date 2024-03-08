# frozen_string_literal: true

require 'spec_helper'

describe 'EarthWorks Aardvark indexing' do
  subject(:result) { indexer.map_record(record) }

  let(:druid) { 'dc482zx1528' }
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/geo_aardvark_config.rb')
    end
  end
  let(:record) { PublicCocinaRecord.new(druid, purl_url: 'https://purl.stanford.edu') }
  let(:body) { File.new(file_fixture("#{druid}.json")) }

  before do
    stub_request(:get, "https://purl.stanford.edu/#{druid}.json").to_return(status: 200, body:)
  end

  context 'when image, map, or book content' do
    it 'maps things to the right places' do
      expect(result).to include(
        'dct_identifier_sm' => ['https://purl.stanford.edu/dc482zx1528'],
        'dct_title_s' => ['Jōshū Kusatsu Onsenzu']
      )
    end

    it 'contains description with abstract and notes' do
      expect(result['dct_description_s'].first).to eq 'Publication date estimat' \
                                                      'e from dealer description. Shows views of tourist attractions. Includes ' \
                                                      'distance chart in inset. Hand-painted. G7964 .K92 E635 1868Z .J6 bound ' \
                                                      'with G7964 .K2368 E635 1912Z .I2. Gunma prefecture'
    end
  end
end
