# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'EarthWorks Aardvark indexing' do
  subject(:result) { indexer.map_record(record) }

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

  context 'when a shapefile' do
    let(:druid) { 'vv853br8653' }

    it 'maps things to the right places' do
      expect(result).to include(
        'id' => ['https://purl.stanford.edu/vv853br8653'],
        'dct_identifier_sm' => ['https://purl.stanford.edu/vv853br8653'],
        'dct_title_s' => ['Abundance Estimates of the Pacific Salmon Conservation Assessment Database, 1978-2008'],
        'dct_accessRights_s' => ['Public'],
        'gbl_resourceType_sm' => ['Polygon'],
        'gbl_mdModified_dt' => ['2009'],
        'dct_issued_s' => ['2009'],
        'dc_format_s' => ['Shapefile'],
        'dct_language_sm' => ['eng']
      )
    end

    it 'contains description with abstract and notes' do
      expect(result['dct_description_sm'].first).to start_with 'This dataset is a visualization of abundance estimates ' \
                                                              'for six species of Pacific salmon (Oncorhynchus spp.): ' \
                                                              'Chinook, Chum, Pink, Steelhead, Sockeye, and Coho in catchment ' \
                                                              'areas of the Northern Pacific Ocean, including Canada, China, ' \
                                                              'Japan, Russia, and the United States.'
    end
  end

  context 'when image, map, or book content' do
    let(:druid) { 'dc482zx1528' }

    it 'maps things to the right places' do
      expect(result).to include(
        'id' => ['https://purl.stanford.edu/dc482zx1528'],
        'dct_identifier_sm' => ['https://purl.stanford.edu/dc482zx1528'],
        'dct_title_s' => ['Jōshū Kusatsu Onsenzu'],
        'dct_accessRights_s' => ['Public']
      )
    end

    it 'contains description with abstract and notes' do
      expect(result['dct_description_sm'].first).to start_with 'Publication date estimate from dealer description. ' \
                                                              'Shows views of tourist attractions. Includes distance ' \
                                                              'chart in inset. Hand-painted. G7964 .K92 E635 1868Z .J6 ' \
                                                              'bound with G7964 .K2368 E635 1912Z .I2. Gunma prefecture'
    end
  end
end
