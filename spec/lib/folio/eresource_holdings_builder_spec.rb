# frozen_string_literal: true

require 'spec_helper'

require 'folio_client'
require 'folio/eresource_holdings_builder'
require 'folio_record'
require 'marc_links'
require 'sirsi_holding'

RSpec.describe Folio::EresourceHoldingsBuilder do
  subject(:holdings) { described_class.build(folio_record.hrid, folio_record.holdings, folio_record.marc_record) }

  let(:folio_record) do
    FolioRecord.new_from_source_record(source_record_json, client)
  end

  let(:source_record_json) do
    JSON.parse(File.read(file_fixture('a12451243.json')))
  end

  let(:client) { instance_double(FolioClient) }

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
          'holdingsStatements' => [] }] }
  end

  before do
    allow(folio_record).to receive(:items_and_holdings).and_return(items_and_holdings)
    folio_record.instance['hrid'] = 'a12451243'
    allow(client).to receive(:pieces).and_return([])
  end

  it { expect(holdings.count).to eq 1 }
  it { expect(holdings.first).to be_a SirsiHolding }
  it { expect(holdings.first.call_number.call_number).to eq 'INTERNET RESOURCE' }
  it { expect(holdings.first.home_location).to eq 'INTERNET' }
  it { expect(holdings.first.library).to eq 'SUL' }
  it { expect(holdings.first.type).to eq 'ONLINE' }
  it { expect(holdings.first.barcode).to eq 'a12451243-0000' }
  it { expect(holdings.first.tag).to be_a MARC::DataField }

  context 'record does not have any fulltext links' do
    let(:source_record_json) do
      JSON.parse(File.read(file_fixture('a14185492.json')))
    end

    it { expect(holdings).to be_empty }
  end

  context 'the holding library is Law' do
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
            'holdingsStatements' => [] }] }
    end

    it { expect(holdings.first.library).to eq 'LAW' }
  end

  context 'the holding does not include an electronic location' do
    let(:items_and_holdings) do
      { 'items' => [],
        'holdings' =>
         [{ 'location' =>
          { 'permanentLocation' =>
            { 'code' => 'LAW-BASEMENT' },
            'effectiveLocation' =>
            { 'code' => 'LAW-BASEMENT' } },
            'suppressFromDiscovery' => false,
            'id' => '81a56270-e8dd-5759-8083-5cc96cdf0045',
            'holdingsStatements' => [] }] }
    end

    it { expect(holdings).to be_empty }
  end
end