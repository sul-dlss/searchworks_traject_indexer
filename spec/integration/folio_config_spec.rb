# frozen_string_literal: true

require 'spec_helper'

require 'folio_client'
require 'folio_record'

RSpec.describe 'FOLIO indexing' do
  subject(:result) { indexer.map_record(folio_record) }

  let(:indexer) do
    Traject::Indexer.new('okapi.url' => 'https://example.com').tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:folio_record) do
    FolioRecord.new_from_source_record(source_record_json, client)
  end

  let(:source_record_json) do
    JSON.parse(File.read(file_fixture('a14185492.json')))
  end

  let(:client) { instance_double(FolioClient) }
  let(:items_and_holdings) { {} }

  before do
    allow(folio_record).to receive(:items_and_holdings).and_return(items_and_holdings)
    allow(folio_record).to receive(:courses).and_return([])
  end

  it 'maps the record with sirsi fields' do
    expect(result).to include 'title_display' => [start_with('Fantasia sopra motivi')]
  end

  it 'overwrites sirsi-specific fields' do
    expect(result).to include 'context_source_ssi' => ['folio'],
                              'collection' => %w[sirsi folio]
  end

  it 'includes folio-specific fields' do
    expect(result).to include 'uuid_ssi' => ['b2fe7336-33d1-5553-86cb-a15af14c7348'],
                              'folio_json_struct' => [start_with('{')],
                              'holdings_json_struct' => [start_with('{')]
  end

  context 'when the record is suppressed' do
    let(:folio_record) do
      FolioRecord.new({ 'instance' => { 'hrid' => 'blah', 'suppressFromDiscovery' => true } })
    end

    it 'is skipped' do
      expect(result).to be_nil
    end
  end

  describe 'cataloged dates' do
    context 'missing date' do
      before do
        folio_record.instance['catalogedDate'] = nil
      end

      it 'is not indexed' do
        expect(result).not_to include 'date_cataloged'
      end
    end

    context 'bad date from MARC' do
      before do
        folio_record.instance['catalogedDate'] = '19uu-uu-uu'
      end

      it 'is not indexed' do
        expect(result).not_to include 'date_cataloged'
      end
    end

    context 'normal date' do
      before do
        folio_record.instance['catalogedDate'] = '2007-05-11'
      end

      it 'is an ISO8601 timestamp in UTC' do
        expect(result['date_cataloged']).to eq ['2007-05-11T00:00:00Z']
      end
    end
  end

  describe 'electronic resources' do
    let(:source_record_json) do
      JSON.parse(File.read(file_fixture('a12451243.json')))
    end

    let(:items_and_holdings) do
      { 'items' => [],
        'holdings' =>
         [{ 'location' =>
          { 'permanentLocation' =>
            { 'code' => 'SUL-ELECTRONIC' },
            'effectiveLocation' =>
            { 'code' => 'SUL-ELECTRONIC' } },
            'suppressFromDiscovery' => false,
            'id' => '81a56270-e8dd-5759-8083-5cc96cdf0045',
            'holdingsStatements' => [],
            'holdingsStatementsForIndexes' => [],
            'holdingsStatementsForSupplements' => [] }] }
    end

    before do
      folio_record.instance['hrid'] = 'a12451243'
      allow(client).to receive(:pieces).and_return([])
    end

    it {
      expect(result['item_display']).to eq(
        ['a12451243-0000 -|- SUL -|- INTERNET -|-  -|- ONLINE -|-  -|- ' \
         'lc pr  3562.000000 l0.385000 002014 -|- ' \
         'en~a8~~wutx}zzzzzz~ez}wruzzz~zzxzyv~~~~~~~~~~~~~~~ -|-  -|-  -|-  -|- LC']
      )
    }

    it { expect(result['access_facet']).to eq ['Online'] }
    it { expect(result['shelfkey']).to eq ['lc pr  3562.000000 l0.385000 002014'] }
    it { expect(result['building_facet']).to be_nil }

    context 'when the holding library is Law' do
      let(:items_and_holdings) do
        { 'items' => [],
          'holdings' =>
           [{ 'location' =>
            { 'permanentLocation' =>
              { 'code' => 'LAW-ELECTRONIC' },
              'effectiveLocation' =>
              { 'code' => 'LAW-ELECTRONIC' } },
              'suppressFromDiscovery' => false,
              'id' => '81a56270-e8dd-5759-8083-5cc96cdf0045',
              'holdingsStatements' => [],
              'holdingsStatementsForIndexes' => [],
              'holdingsStatementsForSupplements' => [] }] }
      end

      it { expect(result['building_facet']).to eq ['Law (Crown)'] }
    end

    context 'when the holding does not include an electronic location' do
      let(:items) do
        [{ 'id' => '8258dd9f-e0a7-5f82-ba97-e9197fc990eb',
           'crez' => [],
           'hrid' => 'ai1755834_1_1',
           'notes' => [],
           'status' => 'Available',
           'barcode' => '36105043687818',
           '_version' => 1,
           'location' =>
           { 'effectiveLocation' =>
             { 'id' => '0edeef57-074a-4f07-aee2-9f09d55e65c3',
               'code' => 'LAW-BASEMENT',
               'name' => 'Law Basement',
               'campus' =>
               { 'id' => '7003123d-ef65-45f6-b469-d2b9839e1bb3',
                 'code' => 'LAW',
                 'name' => 'Law School' },
               'details' => nil,
               'library' =>
               { 'id' => '7e4c05e3-1ce6-427d-b9ce-03464245cd78',
                 'code' => 'LAW',
                 'name' => 'Robert Crown Law' },
               'institution' =>
               { 'id' => '8d433cdd-4e8f-4dc1-aa24-8a4ddb7dc929',
                 'code' => 'SU',
                 'name' => 'Stanford University' } },
             'permanentLocation' =>
             { 'id' => '0edeef57-074a-4f07-aee2-9f09d55e65c3',
               'code' => 'LAW-BASEMENT',
               'name' => 'Law Basement',
               'campus' =>
               { 'id' => '7003123d-ef65-45f6-b469-d2b9839e1bb3',
                 'code' => 'LAW',
                 'name' => 'Law School' },
               'details' => nil,
               'library' =>
               { 'id' => '7e4c05e3-1ce6-427d-b9ce-03464245cd78',
                 'code' => 'LAW',
                 'name' => 'Robert Crown Law' },
               'institution' =>
               { 'id' => '8d433cdd-4e8f-4dc1-aa24-8a4ddb7dc929',
                 'code' => 'SU',
                 'name' => 'Stanford University' } },
             'temporaryLocation' => nil } }]
      end

      let(:holdings) do
        [{ 'location' =>
          { 'permanentLocation' =>
            { 'code' => 'LAW-BASEMENT' },
            'effectiveLocation' =>
            { 'code' => 'LAW-BASEMENT' } },
           'suppressFromDiscovery' => false,
           'id' => '81a56270-e8dd-5759-8083-5cc96cdf0045',
           'holdingsStatements' => [],
           'holdingsStatementsForIndexes' => [],
           'holdingsStatementsForSupplements' => [] }]
      end

      let(:items_and_holdings) do
        { 'items' => items,
          'holdings' => holdings }
      end

      it { expect(result['item_display'].find { |h| h.match?(/INTERNET/) }).to be_nil }
    end
  end

  describe 'mhld_display' do
    subject(:mhld_display) { result.fetch('mhld_display') }
    let(:holding) do
      { 'id' => '4a3a0693-f2a5-4d79-8603-5659ed121ae2',
        'notes' => [],
        'location' =>
        { 'effectiveLocation' =>
          { 'code' => 'EAR-STACKS',
            'name' => 'Earth Sciences Stacks',
            'campusName' => 'Stanford Libraries',
            'libraryName' => 'Branner Earth Sciences',
            'institutionName' => 'Stanford University' },
          'permanentLocation' =>
          { 'code' => 'EAR-STACKS',
            'name' => 'Earth Sciences Stacks',
            'campusName' => 'Stanford Libraries',
            'libraryName' => 'Branner Earth Sciences',
            'institutionName' => 'Stanford University' },
          'temporaryLocation' => {} },
        'formerIds' => [],
        'callNumber' => {},
        'holdingsType' => { 'id' => '03c9c400-b9e3-4a07-ac0e-05ab470233ed', 'name' => 'Monograph', 'source' => 'folio' },
        'electronicAccess' => [],
        'receivingHistory' => { 'entries' => [] },
        'statisticalCodes' => [],
        'holdingsStatements' => holdings_statements,
        'suppressFromDiscovery' => false,
        'holdingsStatementsForIndexes' => index_statements,
        'holdingsStatementsForSupplements' => supplement_statements }
    end
    let(:holdings) { [holding] }
    let(:items) { [] }

    let(:items_and_holdings) do
      { 'instanceId' => 'cc3d8728-a6b9-45c4-ad0c-432873c3ae47',
        'source' => 'MARC',
        'modeOfIssuance' => 'serial',
        'natureOfContent' => [],
        'holdings' => holdings,
        'items' => items }
    end
    let(:index_statements) { [] }
    let(:supplement_statements) { [] }

    before do
      allow(client).to receive(:pieces).with(instance_id: 'b2fe7336-33d1-5553-86cb-a15af14c7348')
                                       .and_return(
                                         [{ 'id' => '6df463df-f3e3-4eb5-86b0-5b496938132b',
                                            'comment' => 'TEST Receiving history',
                                            'format' => 'Physical',
                                            'itemId' => 'd38d9c48-63fa-4215-9bf6-945fed220e74',
                                            'poLineId' => '99dc412a-6ee3-4560-abca-0fa53c174c85',
                                            'titleId' => '7fa131ef-7443-4a21-b970-ce2b4669004a',
                                            'holdingId' => 'bcbe255f-731f-43e6-86a9-c2546434e8b1',
                                            'displayOnHolding' => true,
                                            'enumeration' => 'v.243:no.9',
                                            'chronology' => 'SEP 2023',
                                            'copyNumber' => '1',
                                            'receivingStatus' => 'Received',
                                            'supplement' => false,
                                            'receiptDate' => '2023-03-22T00:00:00.000+00:00',
                                            'receivedDate' => '2023-03-22T13:57:04.492+00:00' },
                                          { 'id' => '0f4d596c-ec1b-42c5-9bcc-e3d61e225924',
                                            'caption' => 'v.',
                                            'comment' => 'TEST Receiving history',
                                            'format' => 'Physical',
                                            'itemId' => '8f6446bf-a0f3-4b73-92ad-e9466bb4448e',
                                            'poLineId' => '99dc412a-6ee3-4560-abca-0fa53c174c85',
                                            'titleId' => '7fa131ef-7443-4a21-b970-ce2b4669004a',
                                            'holdingId' => 'bcbe255f-731f-43e6-86a9-c2546434e8b1',
                                            'displayOnHolding' => true,
                                            'enumeration' => 'v.243:no.10',
                                            'chronology' => 'OCT 2023',
                                            'copyNumber' => '1',
                                            'receivingStatus' => 'Received',
                                            'supplement' => false,
                                            'receiptDate' => '2023-03-22T00:00:00.000+00:00',
                                            'receivedDate' => '2023-03-22T13:58:34.083+00:00' }]
                                       )
    end

    context 'with multiple holdings with a single note and a single statement' do
      let(:item1) do
        { 'id' => '8f6446bf-a0f3-4b73-92ad-e9466bb4448e',
          'tags' => { 'tagList' => [] },
          'notes' => [],
          'status' => 'In process',
          'location' =>
          { 'location' =>
            { 'code' => 'EAR-STACKS',
              'name' => 'Earth Sciences Stacks',
              'campusName' => 'Stanford Libraries',
              'libraryName' => 'Branner Earth Sciences',
              'institutionName' => 'Stanford University' },
            'permanentLocation' => {},
            'temporaryLocation' => {} },
          'formerIds' => [],
          'callNumber' => { 'typeId' => '95467209-6d7b-468b-94df-0f5d7ad2747d', 'typeName' => 'Library of Congress classification', 'callNumber' => 'G1 .N27' },
          'chronology' => 'OCT 2023',
          'enumeration' => 'v.243:no.10',
          'yearCaption' => [],
          'materialType' => 'periodical',
          'electronicAccess' => [],
          'holdingsRecordId' => 'bcbe255f-731f-43e6-86a9-c2546434e8b1',
          'statisticalCodes' => [],
          'permanentLoanType' => 'Can circulate',
          'suppressFromDiscovery' => false }
      end
      let(:item2) do
        { 'id' => 'd38d9c48-63fa-4215-9bf6-945fed220e74',
          'tags' => { 'tagList' => [] },
          'notes' => [],
          'status' => 'In process',
          'location' =>
          { 'location' =>
            { 'code' => 'EAR-STACKS',
              'name' => 'Earth Sciences Stacks',
              'campusName' => 'Stanford Libraries',
              'libraryName' => 'Branner Earth Sciences',
              'institutionName' => 'Stanford University' },
            'permanentLocation' => {},
            'temporaryLocation' => {} },
          'formerIds' => [],
          'callNumber' => { 'typeId' => '95467209-6d7b-468b-94df-0f5d7ad2747d', 'typeName' => 'Library of Congress classification', 'callNumber' => 'G1 .N27' },
          'chronology' => 'SEP 2023',
          'enumeration' => 'v.243:no.9',
          'yearCaption' => [],
          'materialType' => 'periodical',
          'electronicAccess' => [],
          'holdingsRecordId' => 'bcbe255f-731f-43e6-86a9-c2546434e8b1',
          'statisticalCodes' => [],
          'permanentLoanType' => 'Can circulate',
          'suppressFromDiscovery' => false }
      end
      let(:item3) do
        { 'id' => 'ff7224d2-290b-4d3e-8364-1a48355ed27f',
          'tags' => { 'tagList' => [] },
          'notes' => [{ 'note' => 'TEST item', 'itemNoteTypeName' => 'Note' }],
          'status' => 'In transit',
          'barcode' => '123456789987654',
          'location' =>
          { 'location' =>
            { 'code' => 'PMD', 'name' => 'PILOT - Metadata', 'campusName' => 'Stanford Libraries', 'libraryName' => 'SUL', 'institutionName' => 'Stanford University' },
            'permanentLocation' =>
            { 'code' => 'EAR-STACKS',
              'name' => 'Earth Sciences Stacks',
              'campusName' => 'Stanford Libraries',
              'libraryName' => 'Branner Earth Sciences',
              'institutionName' => 'Stanford University' },
            'temporaryLocation' =>
            { 'code' => 'PMD', 'name' => 'PILOT - Metadata', 'campusName' => 'Stanford Libraries', 'libraryName' => 'SUL', 'institutionName' => 'Stanford University' } },
          'formerIds' => [],
          'callNumber' => { 'typeId' => '95467209-6d7b-468b-94df-0f5d7ad2747d', 'typeName' => 'Library of Congress classification', 'callNumber' => 'G1 .N27' },
          'copyNumber' => '1',
          'enumeration' => 'V.243:NO.2 FEB 2023',
          'yearCaption' => [],
          'materialType' => 'periodical',
          'electronicAccess' => [],
          'holdingsRecordId' => 'bcbe255f-731f-43e6-86a9-c2546434e8b1',
          'statisticalCodes' => [],
          'permanentLoanType' => 'Can circulate',
          'suppressFromDiscovery' => false }
      end
      let(:holding2) do
        { 'id' => 'bcbe255f-731f-43e6-86a9-c2546434e8b1',
          'notes' => [],
          'location' =>
          { 'effectiveLocation' =>
            { 'code' => 'EAR-STACKS',
              'name' => 'Earth Sciences Stacks',
              'campusName' => 'Stanford Libraries',
              'libraryName' => 'Branner Earth Sciences',
              'institutionName' => 'Stanford University' },
            'permanentLocation' =>
            { 'code' => 'EAR-STACKS',
              'name' => 'Earth Sciences Stacks',
              'campusName' => 'Stanford Libraries',
              'libraryName' => 'Branner Earth Sciences',
              'institutionName' => 'Stanford University' },
            'temporaryLocation' => {} },
          'formerIds' => [],
          'callNumber' => { 'typeId' => '95467209-6d7b-468b-94df-0f5d7ad2747d', 'typeName' => 'Library of Congress classification', 'callNumber' => 'G1 .N27' },
          'holdingsType' => { 'id' => '03c9c400-b9e3-4a07-ac0e-05ab470233ed', 'name' => 'Monograph', 'source' => 'folio' },
          'electronicAccess' => [],
          'receivingHistory' => { 'entries' => [{ 'enumeration' => 'TEST', 'publicDisplay' => true }, nil] },
          'statisticalCodes' => [],
          'holdingsStatements' => [{ 'note' => '', 'staffNote' => 'Such a good book' }],
          'suppressFromDiscovery' => false,
          'holdingsStatementsForIndexes' => [],
          'holdingsStatementsForSupplements' => [] }
      end

      let(:holdings) { [holding, holding2] }
      let(:items) { [item1, item2, item3] }
      let(:holdings_statements) do
        [
          { 'note' => 'Library has latest 10 yrs. only.' },
          { 'statement' => 'v.195(1999)-v.196(1999),v.201(2002),v.203(2003)-' }
        ]
      end
      it {
        is_expected.to eq [
          'EARTH-SCI -|- STACKS -|- Library has latest 10 yrs. only. -|- v.195(1999)-v.196(1999),v.201(2002),v.203(2003)- -|- ',
          'EARTH-SCI -|- STACKS -|-  -|-  -|- v.243:no.10 (OCT 2023)'
        ]
      }
    end

    context 'with a global note, an index statement, and multiple holding statements, one of which has a note (a2741508)' do
      let(:holdings) { [holding] }
      let(:items) { [] }

      let(:holdings_statements) do
        [{ 'note' => '1990-2006 also on microfiche: XF 441' },
         { 'staffNote' => 'Keep all', 'statement' => 'v.1-37' },
         { 'statement' => '"Digest" 1994' },
         { 'note' => 'Library has latest vol. only', 'staffNote' => 'Discard when replaced', 'statement' => '"Master table of contents"' }]
      end
      let(:index_statements) do
        [{ 'note' => '', 'staffNote' => '', 'statement' => '1992:Apr., 1994:Jan.-' }]
      end
      it {
        is_expected.to eq [
          'EARTH-SCI -|- STACKS -|- 1990-2006 also on microfiche: XF 441 -|- v.1-37 -|- ',
          'EARTH-SCI -|- STACKS -|- 1990-2006 also on microfiche: XF 441 -|- "Digest" 1994 -|- ',
          'EARTH-SCI -|- STACKS -|- 1990-2006 also on microfiche: XF 441 -|- "Master table of contents" Library has latest vol. only -|- ',
          'EARTH-SCI -|- STACKS -|- 1990-2006 also on microfiche: XF 441 -|- Index: 1992:Apr., 1994:Jan.- -|- '
        ]
      }
    end

    context 'with holdingsStatementsForSupplements that have statements' do
      let(:supplement_statements) do
        [{ 'note' => '', 'staffNote' => '', 'statement' => 'guide' }]
      end
      let(:holdings_statements) do
        [{ 'note' => '', 'staffNote' => '', 'statement' => 'reel 1-126 <series 1>' }]
      end
      it {
        is_expected.to eq [
          "EARTH-SCI -|- STACKS -|-  -|- reel 1-126 \u003cseries 1\u003e -|- ",
          'EARTH-SCI -|- STACKS -|-  -|- Supplement: guide -|- '
        ]
      }
    end

    context 'with holdingsStatementsForSupplements that have no statement' do
      # See hrid: a10362341
      let(:supplement_statements) do
        [{ 'note' => 'Library keeps latest only', 'staffNote' => 'Library keeps latest supplement only.' }]
      end
      let(:holdings_statements) do
        [{ 'staffNote' => 'Send to cataloging to receive and update holdings...', 'statement' => 'v.1, 11' }]
      end
      it { is_expected.to eq ['EARTH-SCI -|- STACKS -|-  -|- v.1, 11 -|- '] }
    end
  end

  describe 'bound_with_parents_struct' do
    let(:bound_with_parents) do
      [{
        'parentInstanceId' => '134624',
        'parentInstanceTitle' => 'Investigations of the relative amount of time spent on the ground',
        'parentItemBarcode' => '36105131576063',
        'parentItemId' => 'd1eece03-e4b6-5bd3-b6be-3d76ae8cf96d',
        'childHoldingCallNumber' => '064.8 .D191H'
      }]
    end
    before do
      allow(folio_record).to receive(:bound_with_parents).and_return(bound_with_parents)
    end
    it 'has bound with parent data as json' do
      # rubocop:disable Layout/LineLength
      expect(
        result['bound_with_parents_struct']
      ).to eq ['[{"parentInstanceId":"134624","parentInstanceTitle":"Investigations of the relative amount of time spent on the ground","parentItemBarcode":"36105131576063","parentItemId":"d1eece03-e4b6-5bd3-b6be-3d76ae8cf96d","childHoldingCallNumber":"064.8 .D191H"}]']
      # rubocop:enable Layout/LineLength
    end
  end
end
