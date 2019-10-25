require 'spec_helper'

describe 'EarthWorks indexing' do
  let(:druid) { 'dc482zx1528' }
  subject(:result) { indexer.map_record(PublicXmlRecord.new(druid)) }

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
                                'layer_geom_type_s' => ['Image']
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
  end
  context 'for geo content' do
    let(:druid) { 'vv853br8653' }
    before do
      stub_purl_request(druid, File.read(file_fixture("#{druid}.xml").to_s))
    end
    it 'skips record' do
      expect(result).to be_nil
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
  end
end
