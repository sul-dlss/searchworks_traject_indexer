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

  context 'does something' do
    before do
      stub_purl_request(druid, File.read(file_fixture("#{druid}.xml").to_s))
    end
    it 'maps things to the right places' do
      expect(result).to include 'dc_identifier_s' => ['http://purl.stanford.edu/dc482zx1528'],
                                'dc_title_s' => ['Jōshū Kusatsu Onsenzu'],
                                'dc_rights_s' => ['Public'],
                                'layer_geom_type_s' => ['Image']
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
end
