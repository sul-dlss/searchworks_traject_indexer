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

  describe 'mhld_display' do
    subject(:mhld_display) { result.fetch('mhld_display') }

    let(:items_and_holdings) do
      { 'instanceId' => 'cc3d8728-a6b9-45c4-ad0c-432873c3ae47',
        'source' => 'MARC',
        'modeOfIssuance' => 'serial',
        'natureOfContent' => [],
        'holdings' =>
         [{ 'id' => '4a3a0693-f2a5-4d79-8603-5659ed121ae2',
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
            'holdingsType' => 'Unknown',
            'electronicAccess' => [],
            'receivingHistory' => { 'entries' => [] },
            'statisticalCodes' => [],
            'holdingsStatements' => holdings_statements,
            'suppressFromDiscovery' => false,
            'holdingsStatementsForIndexes' => [],
            'holdingsStatementsForSupplements' => [] },
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
            'holdingsType' => 'Monograph',
            'electronicAccess' => [],
            'receivingHistory' => { 'entries' => [{ 'enumeration' => 'TEST', 'publicDisplay' => true }, nil] },
            'statisticalCodes' => [],
            'holdingsStatements' => [],
            'suppressFromDiscovery' => false,
            'holdingsStatementsForIndexes' => [],
            'holdingsStatementsForSupplements' => [] }],
        'items' =>
         [{ 'id' => '8f6446bf-a0f3-4b73-92ad-e9466bb4448e',
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
            'suppressFromDiscovery' => false },
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
            'suppressFromDiscovery' => false },
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
            'suppressFromDiscovery' => false }] }
    end

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

    context 'with a single note and a single statement' do
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

    context 'with multiple notes and statements (a2741508)' do
      let(:holdings_statements) do
        [{ 'note' => '1990-2006 also on microfiche: XF 441' },
         { 'staffNote' => 'Keep all', 'statement' => 'v.1-37' },
         { 'statement' => '"Digest" 1994' },
         { 'note' => 'Library has latest vol. only', 'staffNote' => 'Discard when replaced', 'statement' => '"Master table of contents"' }]
      end
      it {
        is_expected.to eq [
          'EARTH-SCI -|- STACKS -|- 1990-2006 also on microfiche: XF 441 -|- v.1-37 -|- ',
          'EARTH-SCI -|- STACKS -|- 1990-2006 also on microfiche: XF 441 -|- "Digest" 1994 -|- ',
          'EARTH-SCI -|- STACKS -|- 1990-2006 also on microfiche: XF 441 -|- "Master table of contents" Library has latest vol. only -|- ',
          'EARTH-SCI -|- STACKS -|-  -|-  -|- v.243:no.10 (OCT 2023)'
        ]
      }
    end
  end
end
