# frozen_string_literal: true

RSpec.describe 'Browse nearby' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:record) { MARC::Record.new }
  let(:folio_record) { marc_to_folio(record) }
  let(:field) { 'browse_nearby_struct' }

  subject(:result) { indexer.map_record(folio_record)[field]&.map { |x| JSON.parse(x) } }
  let(:items_and_holdings) { { 'items' => [], 'holdings' => [] } }

  context 'eresources with browse call numbers' do
    before do
      allow(folio_record).to receive(:items_and_holdings).and_return(items_and_holdings)
      allow(folio_record).to receive(:pieces).and_return([])
    end

    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '15069nam a2200409 a 4500'
        r.append(MARC::ControlField.new('008', '091123s2014    si a    sb    101 0 eng d'))
        r.append(MARC::DataField.new('050', ' ', '0',
                                     MARC::Subfield.new('a', 'F1356'),
                                     MARC::Subfield.new('b', '.M464 2005')))
        r.append(MARC::DataField.new('856', ' ', '0', MARC::Subfield.new('u', 'http://example.com')))
      end
    end

    let(:items_and_holdings) do
      { 'items' => [],
        'holdings' =>
         [{ 'holdingsType' => { 'name' => 'Electronic' },
            'location' =>
          { 'permanentLocation' =>
            { 'code' => 'SUL-ELECTRONIC' },
            'effectiveLocation' =>
            { 'code' => 'SUL-ELECTRONIC', 'library' => { 'code' => 'SUL' } } },
            'suppressFromDiscovery' => false,
            'id' => '81a56270-e8dd-5759-8083-5cc96cdf0045',
            'holdingsStatements' => [],
            'holdingsStatementsForIndexes' => [],
            'holdingsStatementsForSupplements' => [] }] }
    end

    it 'extracts data from the 050ab field' do
      expect(result).to include(hash_including('lopped_callnumber' => 'F1356 .M464 2005'))
    end
  end

  context 'when the item does not have a sortable call number (e.g. OTHER type)' do
    before do
      allow(folio_record).to receive(:index_items).and_return(index_items)
    end

    let(:index_items) do
      [build(:other_holding)]
    end

    it { is_expected.to be_blank }

    context 'when the MARC record has a 050 field' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '15069nam a2200409 a 4500'
          r.append(MARC::ControlField.new('008', '091123s2014    si a    sb    101 0 eng d'))
          r.append(MARC::DataField.new('050', ' ', '0',
                                       MARC::Subfield.new('a', 'F1356'),
                                       MARC::Subfield.new('b', '.M464 2005')))
          r.append(MARC::DataField.new('856', ' ', '0', MARC::Subfield.new('u', 'http://example.com')))
        end
      end

      it { is_expected.to be_blank }
    end
  end

  context 'with some Dewey call numbers of a multi-volume monograph' do
    before do
      allow(folio_record).to receive(:index_items).and_return(index_items)
    end

    let(:index_items) do
      [
        build(:dewey_holding, barcode: 'Dewey1', call_number: '888.4 .J788', enumeration: 'V.5'),
        build(:dewey_holding, barcode: 'Dewey2', call_number: '888.4 .J788', enumeration: 'V.6')
      ]
    end

    it { is_expected.to include(hash_including('lopped_callnumber' => '888.4 .J788', 'callnumber' => '888.4 .J788 V.5')) }
  end

  context 'with some LC call numbers of a series' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cas  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 0 eng d'))
      end
    end
    let(:index_items) do
      [
        build(:lc_holding, barcode: 'lc1', call_number: 'QE538.8 .N36', enumeration: '1975-1977'),
        build(:lc_holding, barcode: 'lc2', call_number: 'QE538.8 .N36', enumeration: '1978-1980')
      ]
    end

    before do
      allow(folio_record).to receive(:index_items).and_return(index_items)
    end

    it { is_expected.to include(hash_including('lopped_callnumber' => 'QE538.8 .N36', 'callnumber' => 'QE538.8 .N36 1978-1980')) }
  end

  context 'with some CalDoc call numbers of a series' do
    before do
      allow(folio_record).to receive(:index_items).and_return(index_items)
    end

    let(:index_items) do
      [
        build(:caldoc_holding, barcode: 'CalDoc1', call_number: 'CALIF C728 .F6 1973', enumeration: 'V.1'),
        build(:caldoc_holding, barcode: 'CalDoc1', call_number: 'CALIF C728 .F6 1973', enumeration: 'V.2')
      ]
    end

    it { is_expected.to include(hash_including('lopped_callnumber' => 'CALIF C728 .F6 1973', 'callnumber' => 'CALIF C728 .F6 1973 V.1')) }
  end

  context 'with a mix of Sudocs' do
    before do
      allow(folio_record).to receive(:index_items).and_return(index_items)
    end

    let(:index_items) do
      [
        build(:sudoc_holding, barcode: 'Sudoc1', call_number: 'Y 4.SCI 2:107-46/V.1'),
        build(:sudoc_holding, barcode: 'Sudoc2', call_number: 'Y 1.1/8:118-400/PT.1 PT.1'),
        build(:sudoc_holding, barcode: 'Sudoc3', call_number: 'Y 1.1/8:118-400/PT.2 PT.2'),
        build(:sudoc_holding, barcode: 'Sudoc4', call_number: 'Y 4.W 36:WMCP 108-11'),
        build(:sudoc_holding, barcode: 'Sudoc5', call_number: 'A 13.92:B 63/5/LAND/V.1-2/2003'),
        build(:sudoc_holding, barcode: 'Sudoc6', call_number: 'I 53.11/4-2:42117-E 1-TM-100/2005'),
        build(:sudoc_holding, barcode: 'Sudoc7', call_number: 'I 49.44/2:N 81 P')
      ]
    end

    it {
      is_expected.to include(hash_including('lopped_callnumber' => 'Y 4.SCI 2:107-46'),
                             hash_including('lopped_callnumber' => 'Y 1.1/8:118-400'),
                             hash_including('lopped_callnumber' => 'Y 4.W 36:WMCP 108-11'),
                             hash_including('lopped_callnumber' => 'A 13.92:B 63'),
                             hash_including('lopped_callnumber' => 'I 53.11/4-2:42117-E 1-TM-100'),
                             hash_including('lopped_callnumber' => 'I 49.44/2:N 81'))
    }
  end

  context 'with UN document call numbers' do
    before do
      allow(folio_record).to receive(:index_items).and_return(index_items)
    end

    let(:index_items) do
      [
        build(:undoc_holding, barcode: 'Undoc1', call_number: 'ECE/EAD/PAU/2003/1'),
        build(:undoc_holding, barcode: 'Undoc1', call_number: 'ICAO DOC 9941 AN/478'),
        build(:undoc_holding, barcode: 'Undoc1', call_number: 'ST/ESA/PAD/SER.E/75')
      ]
    end

    it {
      is_expected.to include(hash_including('lopped_callnumber' => 'ECE/EAD/PAU/2003/1'),
                             hash_including('lopped_callnumber' => 'ICAO DOC 9941 AN/478'),
                             hash_including('lopped_callnumber' => 'ST/ESA/PAD/SER.E/75'))
    }
  end

  context 'with a mix of items' do
    before do
      allow(folio_record).to receive(:index_items).and_return(index_items)
    end

    let(:index_items) do
      [
        build(:lc_holding, barcode: 'LCbarcode', call_number: 'QE538.8 .N36 1975-1977'),
        build(:dewey_holding, barcode: 'Dewey1', call_number: '888.4 .J788', enumeration: 'V.5'),
        build(:dewey_holding, barcode: 'Dewey2', call_number: '888.4 .J788', enumeration: 'V.6'),
        build(:sudoc_holding, barcode: 'Sudoc1', call_number: 'Y 4.G 74/7-11:110"'),
        build(:sudoc_holding, barcode: 'Sudoc2', call_number: 'Y 4.G 74/7-11:1101'),
        build(:undoc_holding, barcode: 'Undoc1', call_number: 'ECE/EAD/PAU/2003/3'),
        build(:undoc_holding, barcode: 'Undoc2', call_number: 'ICAO DOC 9941 AN/478')
      ]
    end

    it { is_expected.to include(hash_including('lopped_callnumber' => 'QE538.8 .N36 1975-1977'), hash_including('lopped_callnumber' => '888.4 .J788')) }
  end

  context 'with a bound-with holding with a common call number' do
    before do
      allow(folio_record).to receive(:index_items).and_return(index_items)
    end

    let(:holding) do
      {
        'boundWith' => {
          'instance' => {
            'hrid' => 'a5488000',
            'title' => 'The gases of swamp rice soils ...'
          },
          'holding' => {},
          'item' => {
            'id' => 'f947bd93-a1eb-5613-8745-1063f948c461',
            'volume' => nil,
            'callNumber' => { 'callNumber' => '630.654 .I39M' },
            'chronology' => nil,
            'enumeration' => 'V.5:NO.1'
          }
        }
      }
    end

    let(:index_items) do
      [
        build(:dewey_holding, bound_with: true, call_number: '630.654 .I39M', enumeration: 'V.5:NO.1', holding: holding.merge('callNumber' => '630.654 .I39M V.5:NO.5')),
        build(:dewey_holding, bound_with: true, call_number: '630.654 .I39M', enumeration: 'V.5:NO.1', holding: holding.merge('callNumber' => '630.654 .I39M V.5:NO.6'))
      ]
    end

    it { is_expected.to include(hash_including('lopped_callnumber' => '630.654 .I39M', 'callnumber' => '630.654 .I39M V.5:NO.5')) }
  end

  context 'with a bound-with holding with a distinct call number' do
    before do
      allow(folio_record).to receive(:index_items).and_return(index_items)
    end

    let(:holding) do
      {
        'boundWith' => {
          'instance' => {
            'hrid' => 'a5488000',
            'title' => 'The gases of swamp rice soils ...'
          },
          'holding' => {},
          'item' => {
            'id' => 'f947bd93-a1eb-5613-8745-1063f948c461',
            'volume' => nil,
            'callNumber' => { 'callNumber' => '630.654 .I39M' },
            'chronology' => nil,
            'enumeration' => 'V.5:NO.1'
          }
        }
      }
    end

    let(:index_items) do
      [
        build(:dewey_holding, bound_with: true, call_number: 'AB1234', enumeration: 'V.5:NO.1', holding: holding.merge('callNumber' => 'QA987 V.5:NO.5'))
      ]
    end

    it { is_expected.to include(hash_including('lopped_callnumber' => 'QA987 V.5:NO.5')) }
  end

  context 'with a LANE e-resource' do
    before do
      allow(folio_record).to receive(:items_and_holdings).and_return(items_and_holdings)
      allow(folio_record).to receive(:pieces).and_return([])
    end

    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '15069nam a2200409 a 4500'
        r.append(MARC::ControlField.new('008', '091123s2014    si a    sb    101 0 eng d'))
        r.append(MARC::DataField.new('050', ' ', '0',
                                     MARC::Subfield.new('a', 'F1356'),
                                     MARC::Subfield.new('b', '.M464 2005')))
        r.append(MARC::DataField.new('856', ' ', '0', MARC::Subfield.new('u', 'http://example.com')))
      end
    end

    let(:items_and_holdings) do
      { 'items' => [],
        'holdings' =>
         [
           { 'id' => '4a3a0693-f2a5-4d79-8603-5659ed121ae2',
             'notes' => [],
             'location' =>
             { 'effectiveLocation' =>
               { 'code' => 'LANE-STACKS',
                 'name' => 'Lane Stacks',
                 'campusName' => 'Lane',
                 'libraryName' => 'Lane',
                 'institutionName' => 'Stanford University',
                 'details' => {
                   'holdingsTypeName' => 'Electronic'
                 } },
               'permanentLocation' => {},
               'temporaryLocation' => {} },
             'formerIds' => [],
             'callNumber' => 'Karger',
             'holdingsType' => {},
             'electronicAccess' => [],
             'receivingHistory' => { 'entries' => [] },
             'statisticalCodes' => [],
             'holdingsStatements' => [],
             'suppressFromDiscovery' => false,
             'holdingsStatementsForIndexes' => [],
             'holdingsStatementsForSupplements' => [] }
         ] }
    end

    it { is_expected.to include(hash_including('lopped_callnumber' => 'F1356 .M464 2005')) }
  end
end
