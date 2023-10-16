# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Folio::MhldBuilder do
  subject(:mhld_display) { described_class.build(holdings, holding_summaries, pieces) }

  let(:holdings) { [] }
  let(:holding_summaries) { [] }
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
    let(:holding_summaries) do
      [{ 'poLineId' => '99dc412a-6ee3-4560-abca-0fa53c174c85',
         'poLineNumber' => '12545-1',
         'polReceiptStatus' => 'Received',
         'orderType' => 'Ongoing',
         'orderStatus' => 'Open',
         'orderSentDate' => '2023-03-11T00:00:00.000Z',
         'orderCloseReason' => nil }]
    end

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

      context 'when the order is one-time' do
        let(:pieces) do
          [{ 'id' => '0f4d596c-ec1b-42c5-9bcc-e3d61e225924',
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
        let(:holding_summaries) do
          [{ 'poLineId' => '99dc412a-6ee3-4560-abca-0fa53c174c85',
             'poLineNumber' => '12545-1',
             'polReceiptStatus' => 'Received',
             'orderType' => 'One-time',
             'orderStatus' => 'Open',
             'orderSentDate' => '2023-03-11T00:00:00.000Z',
             'orderCloseReason' => nil }]
        end

        it { is_expected.to eq ['EARTH-SCI -|- STACKS -|- Library has latest 10 yrs. only. -|- v.195(1999)-v.196(1999),v.201(2002),v.203(2003)- -|- '] }
      end

      context 'when the order is closed' do
        let(:pieces) do
          [{ 'id' => '0f4d596c-ec1b-42c5-9bcc-e3d61e225924',
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
        let(:holding_summaries) do
          [{ 'poLineId' => '99dc412a-6ee3-4560-abca-0fa53c174c85',
             'poLineNumber' => '12545-1',
             'polReceiptStatus' => 'Received',
             'orderType' => 'Ongoing',
             'orderStatus' => 'Closed',
             'orderSentDate' => '2023-03-11T00:00:00.000Z',
             'orderCloseReason' => nil }]
        end

        it { is_expected.to eq ['EARTH-SCI -|- STACKS -|- Library has latest 10 yrs. only. -|- v.195(1999)-v.196(1999),v.201(2002),v.203(2003)- -|- '] }
      end

      context 'with unreceived pieces' do
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
             'receivingStatus' => 'Expected',
             'supplement' => false,
             'receiptDate' => '2023-03-22T00:00:00.000+00:00',
             'receivedDate' => '2023-03-22T13:58:34.083+00:00' }]
        end

        it { is_expected.to eq ['EARTH-SCI -|- STACKS -|- Library has latest 10 yrs. only. -|- v.195(1999)-v.196(1999),v.201(2002),v.203(2003)- -|- v.243:no.9 (SEP 2023)'] }
      end
    end

    context 'with Electronic holdings types' do
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
          'holdingsType' => { 'id' => '03c9c400-b9e3-4a07-ac0e-05ab470233ed', 'name' => 'Electronic', 'source' => 'folio' },
          'electronicAccess' => [],
          'receivingHistory' => { 'entries' => [] },
          'statisticalCodes' => [],
          'holdingsStatements' => holdings_statements,
          'suppressFromDiscovery' => false,
          'holdingsStatementsForIndexes' => index_statements,
          'holdingsStatementsForSupplements' => supplement_statements }
      end

      let(:holdings_statements) do
        [
          { 'note' => 'Library has latest 10 yrs. only.' },
          { 'statement' => 'v.195(1999)-v.196(1999),v.201(2002),v.203(2003)-' }
        ]
      end

      it { is_expected.to be_empty }
    end

    context 'with Lane electronic statements' do
      let(:holding) do
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
          'callNumber' => {},
          'holdingsType' => {},
          'electronicAccess' => [],
          'receivingHistory' => { 'entries' => [] },
          'statisticalCodes' => [],
          'holdingsStatements' => holdings_statements,
          'suppressFromDiscovery' => false,
          'holdingsStatementsForIndexes' => index_statements,
          'holdingsStatementsForSupplements' => supplement_statements }
      end

      let(:holdings_statements) do
        [
          { 'note' => 'Library has latest 10 yrs. only.' },
          { 'statement' => 'v.195(1999)-v.196(1999),v.201(2002),v.203(2003)-' }
        ]
      end

      it { is_expected.to be_empty }
    end

    context 'when the holding is suppressed from discovery' do
      let(:holding) do
        { 'id' => '4a3a0693-f2a5-4d79-8603-5659ed121ae2',
          'notes' => [],
          'location' =>
          { 'effectiveLocation' =>
            { 'code' => 'SUL-MIGRATE-ERR',
              'name' => 'Error during migration',
              'campusName' => 'Lane',
              'libraryName' => 'Lane',
              'institutionName' => 'Stanford University' },
            'permanentLocation' => {},
            'temporaryLocation' => {} },
          'formerIds' => [],
          'callNumber' => {},
          'holdingsType' => {},
          'electronicAccess' => [],
          'receivingHistory' => { 'entries' => [] },
          'statisticalCodes' => [],
          'holdingsStatements' => holdings_statements,
          'suppressFromDiscovery' => true,
          'holdingsStatementsForIndexes' => index_statements,
          'holdingsStatementsForSupplements' => supplement_statements }
      end

      let(:holdings_statements) do
        [
          { 'statement' => 'v.1:no.18(1996:Jan.22)-v.1:no.50(1996:Sept.9),v.2:no.1(1996:Sep.16)-v.21:no.16(2015:Dec.28/2016:Jan.4)' }
        ]
      end

      it { is_expected.to be_empty }
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

    let(:holding_summaries) do
      [{ 'poLineId' => 'a866835f-9c89-4772-bdeb-803dbc155694',
         'poLineNumber' => '12545-1',
         'polReceiptStatus' => 'Received',
         'orderType' => 'Ongoing',
         'orderStatus' => 'Open',
         'orderSentDate' => '2023-03-11T00:00:00.000Z',
         'orderCloseReason' => nil }]
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

  context 'when pieces is present and has no enumeration or chronology' do
    let(:holdings) do
      [
        { 'id' => '5de47999-ea02-501c-b99c-512669581b81',
          'hrid' => 'ah3225044_2',
          'notes' => [],
          '_version' => 1,
          'metadata' =>
          { 'createdDate' => '2023-05-06T12:15:24.413Z',
            'updatedDate' => '2023-05-06T12:15:24.413Z',
            'createdByUserId' => '3e2ed889-52f2-45ce-8a30-8767266f07d2',
            'updatedByUserId' => '3e2ed889-52f2-45ce-8a30-8767266f07d2' },
          'sourceId' => '036ee84a-6afd-4c3c-9ad3-4a12ab875f59',
          'boundWith' => nil,
          'formerIds' => [],
          'illPolicy' => nil,
          'copyNumber' => '1',
          'instanceId' => 'c4a0abd3-6705-5490-b72c-7a73a741b4c1',
          'holdingsType' => { 'id' => 'e6da6c98-6dd0-41bc-8b4b-cfd4bbd9c3ae', 'name' => 'Serial', 'source' => 'folio' },
          'holdingsItems' => [],
          'callNumberType' => { 'id' => '95467209-6d7b-468b-94df-0f5d7ad2747d', 'name' => 'Library of Congress classification', 'source' => 'folio' },
          'holdingsTypeId' => 'e6da6c98-6dd0-41bc-8b4b-cfd4bbd9c3ae',
          'callNumberTypeId' => '95467209-6d7b-468b-94df-0f5d7ad2747d',
          'electronicAccess' => [],
          'bareHoldingsItems' => [],
          'discoverySuppress' => false,
          'holdingsStatements' => [{ 'note' => 'Library has latest full year only' }],
          'statisticalCodeIds' => [],
          'administrativeNotes' => [],
          'effectiveLocationId' => '5ecf146b-ce87-42f2-aa63-00d085e82d81',
          'permanentLocationId' => '5ecf146b-ce87-42f2-aa63-00d085e82d81',
          'suppressFromDiscovery' => false,
          'holdingsStatementsForIndexes' => [],
          'holdingsStatementsForSupplements' => [],
          'location' =>
          { 'effectiveLocation' =>
            { 'id' => '5ecf146b-ce87-42f2-aa63-00d085e82d81',
              'code' => 'LAW-STACKS1',
              'name' => 'Law 1st Floor Stacks',
              'campus' => { 'id' => '7003123d-ef65-45f6-b469-d2b9839e1bb3', 'code' => 'LAW', 'name' => 'Law School' },
              'details' => nil,
              'library' => { 'id' => '7e4c05e3-1ce6-427d-b9ce-03464245cd78', 'code' => 'LAW', 'name' => 'Robert Crown Law' },
              'isActive' => true,
              'institution' => { 'id' => '8d433cdd-4e8f-4dc1-aa24-8a4ddb7dc929', 'code' => 'SU', 'name' => 'Stanford University' } },
            'permanentLocation' =>
            { 'id' => '5ecf146b-ce87-42f2-aa63-00d085e82d81',
              'code' => 'LAW-STACKS1',
              'name' => 'Law 1st Floor Stacks',
              'campus' => { 'id' => '7003123d-ef65-45f6-b469-d2b9839e1bb3', 'code' => 'LAW', 'name' => 'Law School' },
              'details' => nil,
              'library' => { 'id' => '7e4c05e3-1ce6-427d-b9ce-03464245cd78', 'code' => 'LAW', 'name' => 'Robert Crown Law' },
              'isActive' => true,
              'institution' => { 'id' => '8d433cdd-4e8f-4dc1-aa24-8a4ddb7dc929', 'code' => 'SU', 'name' => 'Stanford University' } } } }
      ]
    end

    let(:holding_summaries) do
      [{ 'poLineId' => '253a67d4-2a17-472d-81d4-3afc8db2b062',
         'orderType' => 'Ongoing',
         'orderStatus' => 'Open',
         'poLineNumber' => '6102L00-1',
         'orderSentDate' => '2000-08-22T08:00:00.000+00:00',
         'orderCloseReason' => nil,
         'polReceiptStatus' => 'Ongoing' }]
    end

    let(:pieces) do
      [{ 'id' => '3ceb55f5-8a63-431f-a6ee-afe5029cd406',
         'format' => 'Physical',
         'itemId' => 'bb963566-b400-4c59-94f3-18fd676353fe',
         'titleId' => '08a59b0f-099b-47f4-82e0-e6fa22e4a510',
         'poLineId' => '253a67d4-2a17-472d-81d4-3afc8db2b062',
         'holdingId' => '5de47999-ea02-501c-b99c-512669581b81',
         'copyNumber' => 'test',
         'supplement' => false,
         'receivedDate' => '2023-06-22T22:39:26.113+00:00',
         'receivingStatus' => 'Received',
         'displayOnHolding' => true }]
    end

    it { is_expected.to eq ['LAW -|- STACKS-1 -|- Library has latest full year only -|-  -|- '] }
  end
end
