# frozen_string_literal: true

RSpec.describe 'Folio config' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end
  let(:instance) { {} }
  let(:result) { indexer.map_record(marc_to_folio(record, instance:)) }
  let(:record) { records.first }
  let(:field) { 'db_az_subject' }
  subject(:value) { result[field] }

  describe 'db_az_subject' do
    context 'with a record with multiple 099 fields with values for all' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01541cai a2200349Ia 4500'
          r.append(MARC::ControlField.new('008', '040727c20049999nyuuu'))
          r.append(MARC::DataField.new('099', ' ', ' ', MARC::Subfield.new('a', 'AP')))
          r.append(MARC::DataField.new('099', ' ', ' ', MARC::Subfield.new('a', 'Q')))
        end
      end

      let(:instance) { { 'statisticalCodes' => [{ 'name' => 'Database' }] } }

      it { is_expected.to eq ['News', 'Science (General)'] }
    end

    context 'with a record with data in wrong subfield' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01541cai a2200349Ia 4500'
          r.append(MARC::ControlField.new('008', '040727c20049999nyuuu dss     0    2eng d'))
          r.append(MARC::DataField.new('099', ' ', ' ', MARC::Subfield.new('b', 'Q')))
        end
      end

      it { is_expected.to be_nil }
    end
  end

  context 'with a record that double assigned subject codes' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01541cai a2200349Ia 4500'
        r.append(MARC::ControlField.new('008', '030701c200u9999dcuuu dss 000 02eng d'))
        r.append(MARC::DataField.new('099', ' ', ' ', MARC::Subfield.new('a', 'JK')))
        r.append(MARC::DataField.new('099', ' ', ' ', MARC::Subfield.new('a', 'XM')))
      end
    end

    it { is_expected.to eq ['American History', 'Political Science', 'Government Information: United States'] }
  end

  context 'with a record that has no 099 gets uncategorized topic facet value' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01541cai a2200349Ia 4500'
        r.append(MARC::ControlField.new('008', '030701c200u9999dcuuu dss 000 02eng d'))
      end
    end

    it { is_expected.to eq ['Uncategorized'] }

    context 'with real-world data' do
      let(:records) { MARC::XMLReader.new(file_fixture(fixture_name).to_s).to_a }
      subject(:results) { records.map { |rec| indexer.map_record(marc_to_folio(rec)) }.to_a }
      let(:fixture_name) { 'databasesAZsubjectTests.xml' }

      it 'indexes the right data' do
        result = select_by_id('2diffsubs')[field]
        expect(result).to eq ['News', 'Science (General)']

        result = select_by_id('6859025')[field]
        expect(result).to eq ['American History', 'Political Science', 'Government Information: United States']

        result = select_by_id('singleTerm')[field]
        expect(result).to eq ['News']
      end
    end
  end
end
