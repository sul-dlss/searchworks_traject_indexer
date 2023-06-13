# frozen_string_literal: true

require 'spec_helper'
require 'folio/mhld_builder'

RSpec.describe Folio::MhldBuilder do
  subject(:mhld_display) { described_class.build(holdings, pieces) }

  let(:holdings) { [] }
  let(:pieces) { [] }

  it { is_expected.to be_empty }

  context 'when a holding is present' do
    let(:holdings) { [holding] }
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
    let(:index_statements) { [] }
    let(:supplement_statements) { [] }

    context 'without holdings statements' do
      let(:holdings_statements) { [] }

      it { is_expected.to be_empty }
    end

    context 'with holdings statements' do
      let(:holdings_statements) do
        [
          { 'note' => 'Library has latest 10 yrs. only.' },
          { 'statement' => 'v.195(1999)-v.196(1999),v.201(2002),v.203(2003)-' }
        ]
      end

      it { is_expected.to eq ['EARTH-SCI -|- STACKS -|- Library has latest 10 yrs. only. -|- v.195(1999)-v.196(1999),v.201(2002),v.203(2003)- -|- '] }

      context 'with pieces having a MON YYYY cronology' do
        let(:pieces) do
          [{ 'id' => '6df463df-f3e3-4eb5-86b0-5b496938132b',
             'comment' => 'TEST Receiving history',
             'format' => 'Physical',
             'itemId' => 'd38d9c48-63fa-4215-9bf6-945fed220e74',
             'poLineId' => '99dc412a-6ee3-4560-abca-0fa53c174c85',
             'titleId' => '7fa131ef-7443-4a21-b970-ce2b4669004a',
             'holdingId' => '4a3a0693-f2a5-4d79-8603-5659ed121ae2',
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
             'holdingId' => '4a3a0693-f2a5-4d79-8603-5659ed121ae2',
             'displayOnHolding' => true,
             'enumeration' => 'v.243:no.10',
             'chronology' => 'OCT 2023',
             'copyNumber' => '1',
             'receivingStatus' => 'Received',
             'supplement' => false,
             'receiptDate' => '2023-03-22T00:00:00.000+00:00',
             'receivedDate' => '2023-03-22T13:58:34.083+00:00' }]
        end

        it { is_expected.to eq ['EARTH-SCI -|- STACKS -|- Library has latest 10 yrs. only. -|- v.195(1999)-v.196(1999),v.201(2002),v.203(2003)- -|- v.243:no.10 (OCT 2023)'] }
      end

      context 'with pieces having a (season) WIN YYYY cronology' do
        let(:pieces) do
          [{ 'id' => '6df463df-f3e3-4eb5-86b0-5b496938132b',
             'comment' => 'TEST Receiving history',
             'format' => 'Physical',
             'itemId' => 'd38d9c48-63fa-4215-9bf6-945fed220e74',
             'poLineId' => '99dc412a-6ee3-4560-abca-0fa53c174c85',
             'titleId' => '7fa131ef-7443-4a21-b970-ce2b4669004a',
             'holdingId' => '4a3a0693-f2a5-4d79-8603-5659ed121ae2',
             'displayOnHolding' => true,
             'enumeration' => 'v.243:no.9',
             'chronology' => 'WIN 2023',
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
             'holdingId' => '4a3a0693-f2a5-4d79-8603-5659ed121ae2',
             'displayOnHolding' => true,
             'enumeration' => 'v.243:no.10',
             'chronology' => 'OCT 2023',
             'copyNumber' => '1',
             'receivingStatus' => 'Received',
             'supplement' => false,
             'receiptDate' => '2023-03-22T00:00:00.000+00:00',
             'receivedDate' => '2023-03-22T13:58:34.083+00:00' }]
        end

        it { is_expected.to eq ['EARTH-SCI -|- STACKS -|- Library has latest 10 yrs. only. -|- v.195(1999)-v.196(1999),v.201(2002),v.203(2003)- -|- v.243:no.10 (OCT 2023)'] }
      end

      context 'with pieces having a YYYY cronology' do
        let(:pieces) do
          [{ 'id' => '6df463df-f3e3-4eb5-86b0-5b496938132b',
             'comment' => 'TEST Receiving history',
             'format' => 'Physical',
             'itemId' => 'd38d9c48-63fa-4215-9bf6-945fed220e74',
             'poLineId' => '99dc412a-6ee3-4560-abca-0fa53c174c85',
             'titleId' => '7fa131ef-7443-4a21-b970-ce2b4669004a',
             'holdingId' => '4a3a0693-f2a5-4d79-8603-5659ed121ae2',
             'displayOnHolding' => true,
             'enumeration' => 'v.243',
             'chronology' => '2022',
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
             'holdingId' => '4a3a0693-f2a5-4d79-8603-5659ed121ae2',
             'displayOnHolding' => true,
             'enumeration' => 'v.244',
             'chronology' => '2023',
             'copyNumber' => '1',
             'receivingStatus' => 'Received',
             'supplement' => false,
             'receiptDate' => '2023-03-22T00:00:00.000+00:00',
             'receivedDate' => '2023-03-22T13:58:34.083+00:00' }]
        end

        it { is_expected.to eq ['EARTH-SCI -|- STACKS -|- Library has latest 10 yrs. only. -|- v.195(1999)-v.196(1999),v.201(2002),v.203(2003)- -|- v.244 (2023)'] }
      end
    end
  end

  context 'when pieces is present and has no enumeration' do
    let(:holdings) do
      [{ 'id' => 'ef966540-7893-5eb0-b2a6-6fc7e1240ebd',
         'hrid' => 'ah13475642_2',
         'notes' => [],
         '_version' => 1,
         'location' =>
         { 'effectiveLocation' =>
           { 'id' => '1a2856e5-fe97-4731-974e-951d778c41a0',
             'code' => 'GRE-CURRENTPER',
             'name' => 'Green Library Current Periodicals',
             'campus' => { 'id' => 'c365047a-51f2-45ce-8601-e421ca3615c5', 'code' => 'SUL', 'name' => 'Stanford Libraries' },
             'details' => nil,
             'library' => { 'id' => 'f6b5519e-88d9-413e-924d-9ed96255f72e', 'code' => 'GREEN', 'name' => 'Cecil H. Green' },
             'institution' => { 'id' => '8d433cdd-4e8f-4dc1-aa24-8a4ddb7dc929', 'code' => 'SU', 'name' => 'Stanford University' } },
           'permanentLocation' =>
           { 'id' => '1a2856e5-fe97-4731-974e-951d778c41a0',
             'code' => 'GRE-CURRENTPER',
             'name' => 'Green Library Current Periodicals',
             'campus' => { 'id' => 'c365047a-51f2-45ce-8601-e421ca3615c5', 'code' => 'SUL', 'name' => 'Stanford Libraries' },
             'details' => nil,
             'library' => { 'id' => 'f6b5519e-88d9-413e-924d-9ed96255f72e', 'code' => 'GREEN', 'name' => 'Cecil H. Green' },
             'institution' => { 'id' => '8d433cdd-4e8f-4dc1-aa24-8a4ddb7dc929', 'code' => 'SU', 'name' => 'Stanford University' } },
           'temporaryLocation' => nil },
         'metadata' =>
         { 'createdDate' => '2023-05-07T13:07:06.828Z',
           'updatedDate' => '2023-05-07T13:07:06.828Z',
           'createdByUserId' => '3e2ed889-52f2-45ce-8a30-8767266f07d2',
           'updatedByUserId' => '3e2ed889-52f2-45ce-8a30-8767266f07d2' },
         'sourceId' => '036ee84a-6afd-4c3c-9ad3-4a12ab875f59',
         'formerIds' => [],
         'illPolicy' => nil,
         'instanceId' => '26bc8396-bac4-5fa6-a170-bd024c13dd69',
         'holdingsType' => { 'id' => 'e6da6c98-6dd0-41bc-8b4b-cfd4bbd9c3ae', 'name' => 'Serial', 'source' => 'folio' },
         'holdingsItems' => [],
         'callNumberType' =>
         { 'id' => '95467209-6d7b-468b-94df-0f5d7ad2747d', 'name' => 'Library of Congress classification', 'source' => 'folio' },
         'holdingsTypeId' => 'e6da6c98-6dd0-41bc-8b4b-cfd4bbd9c3ae',
         'callNumberTypeId' => '95467209-6d7b-468b-94df-0f5d7ad2747d',
         'electronicAccess' => [],
         'bareHoldingsItems' => [],
         'discoverySuppress' => false,
         'holdingsStatements' =>
         [{ 'note' => 'Latest issues in CURRENT PERIODICALS; earlier issues in STACKS' }, { 'statement' => '2018' }],
         'statisticalCodeIds' => [],
         'administrativeNotes' => [],
         'effectiveLocationId' => '1a2856e5-fe97-4731-974e-951d778c41a0',
         'permanentLocationId' => '1a2856e5-fe97-4731-974e-951d778c41a0',
         'suppressFromDiscovery' => false,
         'holdingsStatementsForIndexes' => [],
         'holdingsStatementsForSupplements' => [] }]
    end

    let(:pieces) do
      [{ 'id' => '1e504a21-66c3-417f-aff8-25174d73c592',
         'format' => 'Physical',
         'itemId' => '0797fa1f-2e40-426c-aa31-f1cf6e9fc875',
         'titleId' => 'dab77adb-1955-406e-94b0-165d9fb0a8e0',
         'poLineId' => 'a866835f-9c89-4772-bdeb-803dbc155694',
         'holdingId' => 'ef966540-7893-5eb0-b2a6-6fc7e1240ebd',
         'chronology' => 'JUN 2022',
         'supplement' => false,
         'receivedDate' => '2023-05-18T18:00:09.036+00:00',
         'receivingStatus' => 'Received',
         'displayOnHolding' => true }]
    end

    it { is_expected.to eq ['GREEN -|- CURRENTPER -|- Latest issues in CURRENT PERIODICALS; earlier issues in STACKS -|- 2018 -|- JUN 2022'] }
  end
end
