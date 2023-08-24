# frozen_string_literal: true

RSpec.describe 'Call Numbers' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:fixture_name) { 'callNumberTests.jsonl' }
  let(:records) { MARC::JSONLReader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }

  subject(:results) { records.map { |rec| indexer.map_record(marc_to_folio_with_stubbed_holdings(rec)) }.to_a }
  subject(:result) { indexer.map_record(marc_to_folio_with_stubbed_holdings(record)) }

  describe 'lc_assigned_callnum_ssim' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '15069nam a2200409 a 4500'
        r.append(MARC::ControlField.new('008', '091123s2014    si a    sb    101 0 eng d'))
        r.append(MARC::DataField.new('050', ' ', '0',
                                     MARC::Subfield.new('a', 'F1356'),
                                     MARC::Subfield.new('b', '.M464 2005')))
        r.append(MARC::DataField.new('090', ' ', '0',
                                     MARC::Subfield.new('a', 'F090'),
                                     MARC::Subfield.new('b', '.Z1')))
      end
    end

    it 'extracts data from the 050ab field' do
      expect(result['lc_assigned_callnum_ssim']).to include 'F1356 .M464 2005'
    end

    it 'extracts data from the 090ab field' do
      expect(result['lc_assigned_callnum_ssim']).to include 'F090 .Z1'
    end
  end

  describe 'callnum_search' do
    let(:field) { 'callnum_search' }

    it 'has the correct data' do
      expect(select_by_id('690002')[field]).to eq(['159.32 .W211'])
      expect(select_by_id('2328381')[field]).to include('827.5 .S97TG')
      expect(select_by_id('1849258')[field]).to include('352.042 .C594 ED.2')
      expect(select_by_id('2214009')[field]).to eq(['370.1 .S655'])
      expect(select_by_id('1')[field]).to eq(['1 .N44'])
      expect(select_by_id('11')[field]).to eq(['1.123 .N44'])
      expect(select_by_id('2')[field]).to eq(['22 .N47'])
      expect(select_by_id('22')[field]).to eq(['22.456 .S655'])
      expect(select_by_id('3')[field]).to eq(['999 .F67'])
      expect(select_by_id('31')[field]).to eq(['999.85 .P84'])
    end

    it 'does not get forbidden call numbers' do
      bad_callnumbers = [
        'NO CALL NUMBER',
        'IN PROCESS',
        'INTERNET RESOURCE',
        'WITHDRAWN',
        'X*', # X call nums (including XX)
        '"Government Document"'
      ]
      all_callnumbers = results.map { |res| res[field] }.flatten
      expect(all_callnumbers).to include('159.32 .W211')
      expect(all_callnumbers).not_to include(*bad_callnumbers)
    end
  end
end
