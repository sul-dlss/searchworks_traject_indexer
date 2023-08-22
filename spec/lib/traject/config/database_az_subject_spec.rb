# frozen_string_literal: true

RSpec.describe 'Sirsi config' do
  subject(:result) { indexer.map_record(stub_record_from_marc(record)) }
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end
  let(:record) { records.first }
  let(:field) { 'db_az_subject' }

  describe 'db_az_subject' do
    subject(:result) { indexer.map_record(stub_record_from_marc(record)) }

    context 'with a record with multiple 099 fields with values for all' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01541cai a2200349Ia 4500'
          r.append(MARC::ControlField.new('008', '040727c20049999nyuuu'))
          r.append(MARC::DataField.new('099', ' ', ' ', MARC::Subfield.new('a', 'AP')))
          r.append(MARC::DataField.new('099', ' ', ' ', MARC::Subfield.new('a', 'Q')))
          r.append(MARC::DataField.new('999', ' ', ' ',
                                       MARC::Subfield.new('a', 'INTERNET RESOURCE'),
                                       MARC::Subfield.new('w', 'ALPHANUM'),
                                       MARC::Subfield.new('i', '1'),
                                       MARC::Subfield.new('l', 'INTERNET'),
                                       MARC::Subfield.new('m', 'SUL'),
                                       MARC::Subfield.new('t', 'DATABASE')))
        end
      end

      it 'maps the right data' do
        expect(result[field]).to eq ['News', 'Science (General)']
      end
    end

    context 'with a record with data in wrong subfield' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01541cai a2200349Ia 4500'
          r.append(MARC::ControlField.new('008', '040727c20049999nyuuu dss     0    2eng d'))
          r.append(MARC::DataField.new('099', ' ', ' ', MARC::Subfield.new('b', 'Q')))
          r.append(MARC::DataField.new('999', ' ', ' ',
                                       MARC::Subfield.new('a', 'INTERNET RESOURCE'),
                                       MARC::Subfield.new('w', 'ALPHANUM'),
                                       MARC::Subfield.new('i', '1'),
                                       MARC::Subfield.new('l', 'INTERNET'),
                                       MARC::Subfield.new('m', 'SUL'),
                                       MARC::Subfield.new('t', 'DATABASE')))
        end
      end

      it 'ignores the data' do
        expect(result[field]).to be_nil
      end
    end
  end

  context 'with a record that double assigned subject codes' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01541cai a2200349Ia 4500'
        r.append(MARC::ControlField.new('008', '030701c200u9999dcuuu dss 000 02eng d'))
        r.append(MARC::DataField.new('099', ' ', ' ', MARC::Subfield.new('a', 'JK')))
        r.append(MARC::DataField.new('099', ' ', ' ', MARC::Subfield.new('a', 'XM')))
        r.append(MARC::DataField.new('999', ' ', ' ',
                                     MARC::Subfield.new('a', 'INTERNET RESOURCE'),
                                     MARC::Subfield.new('w', 'ASIS'),
                                     MARC::Subfield.new('i', '6859025-2001'),
                                     MARC::Subfield.new('l', 'INTERNET'),
                                     MARC::Subfield.new('m', 'SUL'),
                                     MARC::Subfield.new('t', 'DATABASE')))
      end
    end

    it 'gets both their values' do
      expect(result[field]).to eq ['American History', 'Political Science', 'Government Information: United States']
    end
  end

  context 'with a record that has no 099 gets uncategorized topic facet value' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01541cai a2200349Ia 4500'
        r.append(MARC::ControlField.new('008', '030701c200u9999dcuuu dss 000 02eng d'))
        r.append(MARC::DataField.new('999', ' ', ' ',
                                     MARC::Subfield.new('a', 'INTERNET RESOURCE'),
                                     MARC::Subfield.new('w', 'ALPHANUM'),
                                     MARC::Subfield.new('i', '1'),
                                     MARC::Subfield.new('l', 'INTERNET'),
                                     MARC::Subfield.new('m', 'SUL'),
                                     MARC::Subfield.new('t', 'DATABASE')))
      end
    end

    it 'gets both their values' do
      expect(result[field]).to eq ['Uncategorized']
    end

    context 'with real-world data' do
      let(:records) { MARC::XMLReader.new(file_fixture(fixture_name).to_s).to_a }
      subject(:results) { records.map { |rec| indexer.map_record(stub_record_from_marc(rec)) }.to_a }
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
