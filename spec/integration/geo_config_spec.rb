# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'EarthWorks indexing' do
  subject(:result) { indexer.map_record(record) }

  let(:druid) { 'dc482zx1528' }
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/geo_config.rb')
    end
  end
  let(:record) { PurlRecord.new(druid, purl_url: 'https://purl.stanford.edu') }

  def stub_purl_request(druid, body)
    stub_request(:get, "https://purl.stanford.edu/#{druid}.xml").to_return(status: 200, body:)
  end

  before do
    stub_purl_request(druid, File.read(file_fixture("#{druid}.xml").to_s))
    stub_request(:get, "https://purl.stanford.edu/#{druid}.json").to_return(status: 404)
  end

  context 'when image, map, or book content' do
    it 'maps things to the right places' do
      expect(result).to include(
        'dc_identifier_s' => ['https://purl.stanford.edu/dc482zx1528'],
        'dc_title_s' => ['Jōshū Kusatsu Onsenzu'],
        'dc_rights_s' => ['Public'],
        'layer_geom_type_s' => ['Image'],
        'layer_slug_s' => ['stanford-dc482zx1528'],
        'hashed_id_ssi' => ['8e76f95ed3e70f047cd812b33b50ed3e']
      )
    end

    it 'contains references' do
      expect(JSON.parse(result['dct_references_s'].first)).to include(
        'http://schema.org/url' => 'https://purl.stanford.edu/dc482zx1528',
        'https://oembed.com' => 'https://purl.stanford.edu/embed.json?&hide_title=true&url=https://purl.stanford.edu/dc482zx1528'
      )
    end

    it 'contains an envelope' do
      expect(result['solr_geom']).to eq 'ENVELOPE(138.523426, 138.630362, 036.656354, 036.597519)'
    end

    it 'contains rights metadata' do
      expect(result['stanford_rights_metadata_s']).to include(/<rightsMetadata>/)
    end

    it 'contains creator metadata' do
      expect(result['dc_creator_sm']).to include('Kikyōya Genkichi', '桔梗屋源吉')
    end

    it 'contains subject metadata' do
      expect(result['dc_subject_sm']).to include('Hot springs')
    end

    it 'contains description with abstract and notes' do
      expect(result['dc_description_s'].first).to eq 'Publication date estimat' \
                                                     'e from dealer description. Shows views of tourist attractions. Includes ' \
                                                     'distance chart in inset. Hand-painted. G7964 .K92 E635 1868Z .J6 bound ' \
                                                     'with G7964 .K2368 E635 1912Z .I2. Gunma prefecture'
    end

    it 'contains date' do
      expect(result['solr_year_i']).to eq [1603]
    end

    it 'contains a reference to the source collection' do
      expect(result['dc_source_sm']).to include('stanford-bf420qj4978')
    end
  end

  context 'without dc:type' do
    let(:druid) { 'ny179kk3075' }

    it 'includes the layer_geom_type_s' do
      expect(result).to include 'layer_geom_type_s' => ['Image']
    end
  end

  context 'with world access and a download restriction' do
    let(:druid) { 'nn217br6628' }

    it 'has a public rights statement' do
      expect(result).to include 'dc_rights_s' => ['Public']
    end
  end

  context 'with rights information in the MODS' do
    let(:druid) { 'ny179kk3075' }

    it 'parses out the rights information into fields' do
      expect(result).to include(
        'stanford_license_s' => include(/This work is in the public domain/),
        'stanford_use_and_reproduction_s' => include(/Image from the Map Collections courtesy Stanford University/),
        'stanford_copyright_s' => include(/This work has been identified as being/)
      )
    end
  end

  context 'with geo content' do
    let(:druid) { 'vv853br8653' }

    it 'maps the metadata' do
      expect(result).to include(
        'dc_identifier_s' => ['https://purl.stanford.edu/vv853br8653'],
        'dc_title_s' => ['Abundance Estimates of the Pacific Salmon Conservation Assessment Database, 1978-2008'],
        'dct_provenance_s' => ['Stanford'],
        'layer_geom_type_s' => ['Polygon'],
        'layer_slug_s' => ['stanford-vv853br8653'],
        'layer_id_s' => ['druid:vv853br8653'],
        'dc_rights_s' => ['Public'],
        'dc_subject_sm' => ['Marine habitat conservation', 'Freshwater habitat conservation',
                            'Pacific salmon', 'Conservation', 'Watersheds', 'Environment', 'Oceans', 'Inland Waters'],
        'hashed_id_ssi' => ['2322030c6a14ad9ca0724974314364a6'],
        'geoblacklight_version' => ['1.0'],
        'layer_availability_score_f' => [1.0]
      )
    end

    it 'contains the correct solr_year_i' do
      expect(result).to include 'solr_year_i' => [1978]
    end

    it 'contains the correct format' do
      expect(result).to include 'dc_format_s' => ['Shapefile']
    end

    it 'contains the correct creators' do
      expect(result).to include 'dc_creator_sm' => ['Pinsky, Malin L.', 'Springmeyer, Dane B.', 'Goslin, Matthew N.',
                                                    'Augerot, Xanthippe']
    end

    it 'contains the correct description' do
      expect(result).to include 'dc_description_s' => include(a_string_starting_with('This dataset is a visualization of abundance estimates for six species of Pacific salmon (Oncorhynchus spp.): Chinook, Chum, Pink, Steelhead, Sockeye, and Coho in catchment areas of the Northern Pacific Ocean, including Canada, China, Japan, Russia, and the United States. Catchment polygons included in this layer range in dates from 1978 to 2008. Sources dating from 1950 to 2005, including published literature and agency reports were consulted in order to create these data. In addition to abundance estimates, the PCSA database includes information on distribution, diversity, run-timings, land cover/land-use, dams, hatcheries, data sources, drainages, and administrative categories and provides a consistent format for comparing watersheds across the range of wild Pacific salmon. The Conservation Science team at the Wild Salmon Center has created a geographic database, the Pacific Salmon Conservation Assessment (PSCA) that covers the whole range of wild Pacific Salmon. By providing estimations of salmon abundance and diversity, these data can provide opportunities to conduct range-wide analysis for conservation planning, prioritizing, and assessments.  The primary goal in developing the PSCA database is to guide proactive international salmon conservation.')) # rubocop:disable Layout/LineLength
    end

    it 'contains the correct dct_references_s' do
      expect(JSON.parse(result['dct_references_s'].first)).to include(
        'http://schema.org/url' => 'https://purl.stanford.edu/vv853br8653',
        'http://schema.org/downloadUrl' => 'https://stacks.stanford.edu/file/druid:vv853br8653/data.zip',
        'http://www.loc.gov/mods/v3' => 'https://purl.stanford.edu/vv853br8653.mods',
        'http://www.isotc211.org/schemas/2005/gmd/' => 'https://raw.githubusercontent.com/OpenGeoMetadata/edu.stanford.purl/master/vv/853/br/8653/iso19139.xml',
        'http://www.opengis.net/def/serviceType/ogc/wfs' => 'https://geowebservices.stanford.edu/geoserver/wfs',
        'http://www.opengis.net/def/serviceType/ogc/wms' => 'https://geowebservices.stanford.edu/geoserver/wms'
      )
    end

    it 'contains the translated ISO19115topicCategory' do
      expect(result).to include 'dc_subject_sm' => include('Environment', 'Oceans', 'Inland Waters')
    end

    it 'contains other topics' do
      expect(result).to include 'dc_subject_sm' => include('Marine habitat conservation', 'Freshwater habitat conservation')
    end

    it 'contains dct_temporal_sm' do
      expect(result).to include 'dct_temporal_sm' => %w[1978 2005]
    end

    it 'contains dct_issued_s' do
      expect(result).to include 'dct_issued_s' => ['2009']
    end

    it 'contains rights metadata' do
      expect(result['stanford_rights_metadata_s']).to include(/<rightsMetadata>/)
    end

    it 'contains dc_language_s' do
      pending 'is hard-coded to English in the XSLT'
      expect(result).to include 'dc_language_s' => ['English']
    end

    it 'contains layer_modified_dt' do
      expect(result).to include 'layer_modified_dt' => ['2018-04-09T23:03:04Z']
    end

    it 'contains dc_type_s' do
      expect(result).to include 'dc_type_s' => ['Dataset']
    end

    it 'contains dc_publisher_s' do
      expect(result).to include 'dc_publisher_s' => ['Stanford Digital Repository']
    end

    it 'contains dct_spatial_sm' do
      expect(result).to include 'dct_spatial_sm' => ['North Pacific Ocean']
    end

    it 'contains solr_geom' do
      expect(result).to include 'solr_geom' => 'ENVELOPE(-180.0, 180.0, 73.990866, 24.23126)'
    end

    context 'when in a collection' do
      let(:druid) { 'mc977kq8162' }

      it 'contains dc_source_sm' do
        expect(result).to include 'dc_source_sm' => ['stanford-bq589tv8583']
      end
    end
  end

  context 'when the item was deleted' do
    subject(:context) { indexer.process_record(record) }

    let(:record) { { id: "druid:#{druid}", delete: true } }

    it 'sets the id in the output to match the layer unique key in solr' do
      expect(context.output_hash['id']).to eq ['stanford-dc482zx1528']
    end
  end

  context 'when no envelope is present' do
    let(:druid) { 'bk264hq9320' }

    it 'skips record' do
      expect(result).to be_nil
    end
  end

  context 'with an abstract' do
    let(:druid) { 'bk359yt4418' }

    before do
      stub_purl_request(druid, File.read(file_fixture("#{druid}.xml").to_s))
    end

    it 'builds a description' do
      expect(result['dc_description_s']).to include('Oversize Digitized by Stanford University Libraries.')
    end
  end

  describe 'collection objects' do
    let(:druid) { 'bq589tv8583' }

    before do
      stub_purl_request(druid, File.read(file_fixture("#{druid}.xml").to_s))
    end

    it 'has expected fields' do
      expect(result).to include(
        'dc_identifier_s' => ['https://purl.stanford.edu/bq589tv8583'],
        'layer_geom_type_s' => ['Collection']
      )
    end

    it 'does not include a layer_id_s' do
      expect(result).not_to include 'layer_id_s'
    end
  end

  describe 'file objects (e.g. geodatabase)' do
    let(:druid) { 'pq479rm6462' }

    it 'has expected fields' do
      expect(result).to include 'dc_identifier_s' => ['https://purl.stanford.edu/pq479rm6462'],
                                'dc_format_s' => ['Geodatabase'],
                                'layer_geom_type_s' => ['Mixed']
    end

    it 'contains the linked oembed' do
      expect(JSON.parse(result['dct_references_s'].first)).to include 'https://oembed.com' => 'https://purl.stanford.edu/embed.json?&hide_title=true&url=https://purl.stanford.edu/pq479rm6462'
    end
  end

  describe 'geoJSON objects' do
    let(:druid) { 'jk681br3989' }

    it 'includes the WFS url in the references' do
      expect(JSON.parse(result['dct_references_s'].first)).to include 'http://www.opengis.net/def/serviceType/ogc/wfs' => 'https://geowebservices.stanford.edu/geoserver/wfs'
    end
  end

  describe 'coordinate envelopes' do
    let(:druid) { 'qy240vt8937' }

    it 'builds a solr_geom from coordinate parsing' do
      expect(result['solr_geom']).to eq 'ENVELOPE(-18.0, 51.0, 37.0, -35.0)'
    end

    it 'date' do
      expect(result['solr_year_i']).to eq [1880]
    end
  end

  describe 'linestrings' do
    let(:druid) { 'mc977kq8162' }

    before do
      stub_purl_request(druid, File.read(file_fixture("#{druid}.xml").to_s))
    end

    it 'builds a solr_geom from coordinate parsing' do
      expect(result['layer_geom_type_s']).to eq ['Line']
    end
  end

  describe 'SDR events' do
    before do
      allow(Settings.sdr_events).to receive(:enabled).and_return(true)
      allow(SdrEvents).to receive_messages(
        report_indexing_success: true,
        report_indexing_deleted: true,
        report_indexing_skipped: true,
        report_indexing_errored: true
      )
    end

    context 'when the item has no public XML' do
      before { allow(record).to receive(:public_xml).and_return(nil) }

      it 'creates an indexing skipped event with message' do
        expect(result).to be_nil
        expect(SdrEvents).to have_received(:report_indexing_skipped)
          .with(druid, message: 'Item is in processing or does not exist', target: 'Earthworks')
      end
    end

    context 'when the item has an unsupported content type' do
      before { allow(record).to receive(:dor_content_type).and_return('document') }

      it 'creates an indexing skipped event with message' do
        expect(result).to be_nil
        expect(SdrEvents).to have_received(:report_indexing_skipped)
          .with(druid, message: 'Item content type "document" is not supported', target: 'Earthworks')
      end
    end

    context 'when the item has no bounding box' do
      before do
        record_xml = Nokogiri::XML(File.read(file_fixture("#{druid}.xml").to_s))
        record_xml.xpath(
          '//rdf:RDF/rdf:Description/gml:boundedBy/gml:Envelope',
          'gml' => 'http://www.opengis.net/gml/3.2/',
          'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
        ).remove
        stub_purl_request(druid, record_xml.to_xml)
      end

      it 'creates an indexing skipped event with message' do
        expect(result).to be_nil
        expect(SdrEvents).to have_received(:report_indexing_skipped)
          .with(druid, message: 'No ENVELOPE available for item', target: 'Earthworks')
      end
    end

    context 'when indexing raised an error' do
      before do
        allow(Honeybadger).to receive(:notify)
        allow(indexer).to receive(:logger) # silence the error message
        allow(record).to receive(:rights_xml).and_raise('Error message')
      end

      it 'creates an indexing error event with message and context' do
        expect { result }.to raise_error('Error message')
        expect(SdrEvents).to have_received(:report_indexing_errored)
          .with(
            druid,
            target: 'Earthworks',
            message: 'Error message',
            context: a_hash_including(
              index_step: an_instance_of(String),
              record: an_instance_of(String)
            )
          )
      end
    end
  end
end
