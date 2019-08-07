require 'spec_helper'

describe 'EarthWorks indexing' do
  subject(:result) { indexer.map_record(PublicXmlRecord.new('dc482zx1528')) }

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
      stub_purl_request('dc482zx1528', File.read(file_fixture('dc482zx1528.xml').to_s))
    end
    it 'maps things to the right places' do
      expect(result).to include 'dc_identifier_s' => ['http://purl.stanford.edu/dc482zx1528'],
                                'dc_title_s' => ['Jōshū Kusatsu Onsenzu'],
                                'dc_rights_s' => ['Public'],
                                'layer_geom_type_s' => ['Image']
    end
  end
end
