RSpec.describe 'Bibonly_xml config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end
  let(:records) { MARC::XMLReader.new(file_fixture(fixture_name).to_s).to_a }
  let(:fixture_name) { 'marcbib_xml.xml' }
  let(:record) { records.first }
  let(:pristine_xml) do
    <<-XML
      <record><leader>01952cas  2200457Ia 4500</leader><controlfield tag="001">aBibOnly</controlfield><controlfield tag="008">780930m19391944nyu           000 0 eng d</controlfield><datafield tag="245" ind1=" " ind2=" "><subfield code="a">title</subfield></datafield><datafield tag="856" ind1=" " ind2=" "><subfield code="a">all of the cats</subfield></datafield></record>
    XML
  end

  describe 'marcbib_xml' do
    it do
      expect(result['marcbib_xml'][0]).to eq pristine_xml.strip
      expect(result['marcbib_xml'][0]).not_to include '999'
      expect(result['marcbib_xml'][0]).not_to include 'GREEN'
      expect(result['marcbib_xml'][0]).not_to include '852'
      expect(result['marcbib_xml'][0]).not_to include '853'
      expect(result['marcbib_xml'][0]).not_to include '854'
      expect(result['marcbib_xml'][0]).not_to include '855'
      expect(result['marcbib_xml'][0]).not_to include 'stuff'
      expect(result['marcbib_xml'][0]).not_to include '863'
      expect(result['marcbib_xml'][0]).not_to include '864'
      expect(result['marcbib_xml'][0]).not_to include '865'
      expect(result['marcbib_xml'][0]).not_to include '866'
      expect(result['marcbib_xml'][0]).not_to include '867'
      expect(result['marcbib_xml'][0]).not_to include '868'

      expect(result['marcbib_xml'][0]).to include '856'
      expect(result['marcbib_xml'][0]).to include 'all of the cats'
    end
  end
end
