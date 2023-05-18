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
end
