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

  context 'when the item does not have a sortable call number (e.g. SUDOC type)' do
    before do
      allow(folio_record).to receive(:index_items).and_return(index_items)
    end

    let(:index_items) do
      [build(:sudoc_holding, call_number: 'I 19.76:98-600-B')]
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
        build(:sudoc_holding, barcode: 'Sudoc2', call_number: 'Y 4.G 74/7-11:1101')
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
