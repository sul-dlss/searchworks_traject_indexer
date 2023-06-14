# frozen_string_literal: true

require 'folio_client'
require 'folio_record'
require 'sirsi_holding'

RSpec.describe FolioRecord do
  subject(:folio_record) { described_class.new(record, client) }
  let(:client) { instance_double(FolioClient) }
  let(:record) do
    {
      'instance' => {
        'id' => '0e050e3f-b160-5f5d-9fdb-2d49305fbb0d'
      },
      'holdings' => [],
      'source_record' => [{
        'fields' => [
          { '001' => 'a14154194' },
          { '918' => {
            'subfields' => [
              { 'a' => '14154194' }
            ]
          } }
        ]
      }]
    }
  end

  describe '#marc_record' do
    it 'strips junk tags' do
      expect(folio_record.marc_record['918']).to be_nil
    end

    it 'preserves non-junk tags' do
      expect(folio_record.marc_record['001']).to have_attributes(tag: '001', value: 'a14154194')
    end
  end

  describe 'the 590 field' do
    context 'when record has existing 590 in its MARC' do
      context 'when 590 has subfield a' do
        let(:record) do
          {
            'instance' => {
              'id' => '0e050e3f-b160-5f5d-9fdb-2d49305fbb0d'
            },
            'holdings' => [],
            'source_record' => [{
              'fields' => [
                { '001' => 'a14154194' },
                { '590' => {
                  'subfields' => [
                    { 'a' => 'Cataloged info about the Bound-with' }
                  ]
                } }
              ]
            }]
          }
        end
        it 'does not overwrite existing 590s' do
          expect(folio_record.marc_record['590']['a']).to eq('Cataloged info about the Bound-with')
        end
      end

      context 'when 590 exists but is missing subfield a, c, or d, and has Bound-with parents via FOLIO APIs' do
        let(:record) do
          {
            'instance' => {
              'id' => '0e050e3f-b160-5f5d-9fdb-2d49305fbb0d'
            },
            'holdings' => [],
            'source_record' => [{
              'fields' => [
                { '001' => 'a14154194' },
                { '590' => {
                  'subfields' => []
                } }
              ]
            }],
            'boundWithParents' => [
              {
                'parentInstanceId' => '134624',
                'parentInstanceTitle' => 'Mursilis Sprachlähmung',
                'parentItemId' => 'd1eece03-e4b6-5bd3-b6be-3d76ae8cf96d',
                'parentItemBarcode' => '36105018739321',
                'childHoldingCallNumber' => '064.8 .D191H'
              }
            ]
          }
        end
        it 'writes a new 590' do
          expect(folio_record.marc_record['590'].subfields).to match_array([
                                                                             have_attributes(code: 'a', value: '064.8 .D191H bound with Mursilis Sprachlähmung'),
                                                                             have_attributes(code: 'c', value: '134624 (parent record)')
                                                                           ])
        end
      end
    end
    context 'when record does not have existing 590 in its MARC' do
      let(:record) do
        {
          'instance' => {
            'id' => '0e050e3f-b160-5f5d-9fdb-2d49305fbb0d'
          },
          'holdings' => [],
          'source_record' => [{
            'fields' => [
              { '001' => 'a14154194' }
            ]
          }],
          'boundWithParents' => [
            {
              'parentInstanceId' => '134624',
              'parentInstanceTitle' => 'Mursilis Sprachlähmung',
              'parentItemId' => 'd1eece03-e4b6-5bd3-b6be-3d76ae8cf96d',
              'parentItemBarcode' => '36105018739321',
              'childHoldingCallNumber' => '064.8 .D191H'
            }
          ]
        }
      end

      context 'when FOLIO returns Bound-with data' do
        it 'writes a new 590' do
          expect(folio_record.marc_record['590'].subfields).to match_array([
                                                                             have_attributes(code: 'a', value: '064.8 .D191H bound with Mursilis Sprachlähmung'),
                                                                             have_attributes(code: 'c', value: '134624 (parent record)')
                                                                           ])
        end
      end
      context 'when FOLIO does not return Bound-with data' do
        let(:record) do
          {
            'instance' => {
              'id' => '0e050e3f-b160-5f5d-9fdb-2d49305fbb0d'
            },
            'holdings' => [],
            'source_record' => [{
              'fields' => [
                { '001' => 'a14154194' }
              ]
            }],
            'boundWithParents' => []
          }
        end

        it 'does not create a new 590 field' do
          expect(folio_record.marc_record['590']).to be_nil
        end
      end
    end
  end

  describe '#bound_with_holdings' do
    context 'when the holding is not a bound-with child' do
      let(:folio_record) { described_class.new(JSON.parse(File.read(file_fixture('folio_basic.json'))), client) }
      it 'does not return any bound-with holdings' do
        expect(folio_record.bound_with_holdings).to be_empty
      end
    end
    context 'when the bound with child is not in SAL3' do
      let(:folio_record) { described_class.new(JSON.parse(File.read(file_fixture('folio_bw_child.json'))), client) }
      it 'does not add SEE-OTHER as the home_location' do
        expect(folio_record.bound_with_holdings.first.home_location).not_to eq('SEE-OTHER')
      end
    end
    context 'when the bound with child is in SAL3' do
      let(:folio_record) { described_class.new(JSON.parse(File.read(file_fixture('folio_bw_child_see-other.json'))), client) }
      it 'adds SEE-OTHER as the home_location' do
        expect(folio_record.bound_with_holdings.first.home_location).to eq('SEE-OTHER')
      end
    end
  end
end
