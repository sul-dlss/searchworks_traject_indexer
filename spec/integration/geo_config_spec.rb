require 'spec_helper'

describe 'EarthWorks indexing' do
  let(:druid) { 'dc482zx1528' }
  subject(:result) { indexer.map_record(PublicXmlRecord.new(druid, purl_url: 'https://purl.stanford.edu')) }

  def stub_purl_request(druid, body)
    without_partial_double_verification do
      if defined?(JRUBY_VERSION)
        allow(Manticore).to receive(:get).with("https://purl.stanford.edu/#{druid}.xml").and_return(double(code: 200, body: body))
      else
        allow(HTTP).to receive(:get).with("https://purl.stanford.edu/#{druid}.xml").and_return(double(body: body, status: double(ok?: true)))
      end
    end
  end

  def stub_mods_request(druid, body)
    without_partial_double_verification do
      if defined?(JRUBY_VERSION)
        allow(Manticore).to receive(:get).with("https://purl.stanford.edu/#{druid}.mods").and_return(double(code: 200, body: body))
      else
        allow(HTTP).to receive(:get).with("https://purl.stanford.edu/#{druid}.mods").and_return(double(body: body, status: double(ok?: true)))
      end
    end
  end

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/geo_config.rb')
    end
  end

  context 'when image, map, or book content' do
    before do
      stub_purl_request(druid, File.read(file_fixture("#{druid}.xml").to_s))
    end
    it 'maps things to the right places' do
      expect(result).to include 'dc_identifier_s' => ['http://purl.stanford.edu/dc482zx1528'],
                                'dc_title_s' => ['Jōshū Kusatsu Onsenzu'],
                                'dc_rights_s' => ['Public'],
                                'layer_geom_type_s' => ['Image'],
                                'layer_slug_s' => ['stanford-dc482zx1528'],
                                'hashed_id_ssi' => ['8e76f95ed3e70f047cd812b33b50ed3e']
    end
    it 'contains references' do
      expect(JSON.parse(result['dct_references_s'].first)).to include 'http://schema.org/url' => 'https://purl.stanford.edu/dc482zx1528',
                                                                'https://oembed.com' => 'https://purl.stanford.edu/embed.json?&hide_title=true&url=https://purl.stanford.edu/dc482zx1528'
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
      expect(result['dc_description_s'].first).to eq 'Publication date estimat'\
      'e from dealer description. Shows views of tourist attractions. Includes'\
      ' distance chart in inset. Hand-painted. G7964 .K92 E635 1868Z .J6 bound'\
      ' with G7964 .K2368 E635 1912Z .I2. Gunma prefecture'
    end

    it 'contains date' do
      expect(result['solr_year_i']).to eq [1603]
    end
  end
  context 'image map book content without dc:type' do
    let(:druid) { 'ny179kk3075' }
    before do
      stub_purl_request(druid, File.read(file_fixture("#{druid}.xml").to_s))
    end
    it 'includes the layer_geom_type_s' do
      expect(result).to include 'layer_geom_type_s' => ['Image']
    end

  end
  context 'for geo content' do
    let(:druid) { 'vv853br8653' }
    before do
      stub_purl_request(druid, File.read(file_fixture("#{druid}.xml").to_s))
    end
    it 'maps the metadata' do
      expect(result).to include 'dc_identifier_s' => ['http://purl.stanford.edu/vv853br8653'],
                                'dc_title_s' => ['Abundance Estimates of the Pacific Salmon Conservation Assessment Database, 1978-2008'],
                                'dc_rights_s' => ['Public'],
                                'dct_provenance_s' => ['Stanford'],
                                'layer_geom_type_s' => ['Polygon'],
                                'layer_slug_s' => ['stanford-vv853br8653'],
                                'dc_rights_s' => ['Public'],
                                'dc_subject_sm' => ['Marine habitat conservation', 'Freshwater habitat conservation', 'Pacific salmon', 'Conservation', 'Watersheds', 'Environment', 'Oceans', 'Inland Waters'],
                                'hashed_id_ssi' => ['2322030c6a14ad9ca0724974314364a6']
    end
    it 'contains the correct solr_year_i' do
      pending('yet to be implemented')
      expect(result).to include 'solr_year_i' => [1978]
    end
    it 'contains the correct format' do
      pending('yet to be implemented')
      expect(result).to include 'dc_format_s' => ['Shapefile']
    end
    it 'contains the correct creators' do
      pending('yet to be implemented')
      expect(result).to include 'dc_creator_sm' => ['Pinsky, Malin L.','Springmeyer, Dane B.','Goslin, Matthew N.','Augerot, Xanthippe']
    end
    it 'contains the correct description' do
      pending('yet to be implemented')
      expect(result).to include 'dc_description_s' => ['This dataset is a visualization of abundance estimates for six species of Pacific salmon (Oncorhynchus spp.): Chinook, Chum, Pink, Steelhead, Sockeye, and Coho in catchment areas of the Northern Pacific Ocean, including Canada, China, Japan, Russia, and the United States. Catchment polygons included in this layer range in dates from 1978 to 2008. Sources dating from 1950 to 2005, including published literature and agency reports were consulted in order to create these data. In addition to abundance estimates, the PCSA database includes information on distribution, diversity, run-timings, land cover/land-use, dams, hatcheries, data sources, drainages, and administrative categories and provides a consistent format for comparing watersheds across the range of wild Pacific salmon.The Conservation Science team at the Wild Salmon Center has created a geographic database, the Pacific Salmon Conservation Assessment (PSCA) that covers the whole range of wild Pacific Salmon. By providing estimations of salmon abundance and diversity, these data can provide opportunities to conduct range-wide analysis for conservation planning, prioritizing, and assessments.  The primary goal in developing the PSCA database is to guide proactive international salmon conservation.']
    end
    it 'contains the correct dct_references_s' do
      expect(JSON.parse(result['dct_references_s'].first)).to include 'http://schema.org/url' => 'https://purl.stanford.edu/vv853br8653',
                                                                'http://schema.org/downloadUrl' => 'https://stacks.stanford.edu/file/druid:vv853br8653/data.zip',
                                                                'http://www.loc.gov/mods/v3' => 'https://purl.stanford.edu/vv853br8653.mods',
                                                                'http://www.opengis.net/def/serviceType/ogc/wfs' => 'https://geowebservices.stanford.edu/geoserver/wfs',
                                                                'http://www.opengis.net/def/serviceType/ogc/wms'=>'https://geowebservices.stanford.edu/geoserver/wms'

    end
    it 'contains the linked ISO19139' do
      pending('pending until we figure out where / how to migrate our OpenGeoMetadata pushing')
      expect(JSON.parse(result['dct_references_s'].first)).to include 'http://www.isotc211.org/schemas/2005/gmd/' => 'https://raw.githubusercontent.com/OpenGeoMetadata/edu.stanford.purl/master/vv/853/br/8653/iso19139.xml'
    end
  end
  context 'when no envelope is present' do
    let(:druid) { 'bk264hq9320' }
    before do
      stub_purl_request(druid, File.read(file_fixture("#{druid}.xml").to_s))
    end
    it 'skips record' do
      expect(result).to be_nil
    end
  end

  context 'with an abstract' do
    let(:druid) { 'bk359yt4418' }
    before do
      stub_purl_request(druid, File.read(file_fixture("#{druid}.xml").to_s))
      stub_mods_request(druid, File.read(file_fixture("#{druid}.xml").to_s))
    end

    it 'builds a description' do
      expect(result['dc_description_s']).to include('Oversize Digitized by Stanford University Libraries.')
    end
  end

  context 'coordinate envelopes are supported' do
    let(:druid) { 'qy240vt8937' }
    before do
      stub_purl_request(druid, File.read(file_fixture("#{druid}.xml").to_s))
      stub_mods_request(druid, File.read(file_fixture("#{druid}.xml").to_s))
    end

    it 'builds a solr_geom from coordinate parsing' do
      expect(result['solr_geom']).to eq 'ENVELOPE(-18.0, 51.0, 37.0, -35.0)'
    end

    it 'date' do
      expect(result['solr_year_i']).to eq [1880]
    end
  end
end
