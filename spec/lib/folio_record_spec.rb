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

    context 'with subfield 0 data that used to be in the subfield =' do
      let(:record) do
        {
          'instance' => {
            'id' => '0e050e3f-b160-5f5d-9fdb-2d49305fbb0d'
          },
          'holdings' => [],
          'source_record' => [{
            'fields' => [
              { '264' => {
                'subfields' => [
                  { '0' => '(SIRSI)blah' },
                  { '0' => 'http://example.com' }
                ]
              } }
            ]
          }]
        }
      end

      it 'strips only that migrated data' do
        expect(folio_record.marc_record['264'].subfields).to match_array([
                                                                           have_attributes(code: '0', value: 'http://example.com')
                                                                         ])
      end
    end

    context 'when deriving from the instance record' do
      let(:record) do
        {
          'instance' => {
            'id' => '0e050e3f-b160-5f5d-9fdb-2d49305fbb0d',
            'title' => 'The title',
            'identifiers' => [
              { 'value' => 'garbage' },
              { 'value' => '(OCoLC-M)948533645' },
              { 'value' => 'sn2021236856' },
              { 'value' => '   68038902 //r84' },
              { 'value' => '2381-5868' },
              { 'value' => '1485631076 (paperback)' },
              { 'value' => '9781485631071 (paperback)' }
            ],
            'languages' => [],
            'contributors' => [],
            'editions' => [],
            'publication' => [],
            'physicalDescriptions' => [],
            'publicationFrequency' => [],
            'publicationRange' => [],
            'notes' => [],
            'series' => [],
            'subjects' => [],
            'electronicAccess' => []
          },
          'holdings' => [],
          'source_record' => []
        }
      end

      it 'derives the ISBN from the identifiers' do
        expect(folio_record.marc_record.fields('020').first.subfields).to match_array(
          [have_attributes(code: 'a', value: '1485631076 (paperback)')]
        )
        expect(folio_record.marc_record.fields('020').last.subfields).to match_array(
          [have_attributes(code: 'a', value: '9781485631071 (paperback)')]
        )
      end

      it 'derives the LCCN from the identifiers' do
        expect(folio_record.marc_record.fields('010').first.subfields).to match_array(
          [have_attributes(code: 'a', value: 'sn2021236856')]
        )
        expect(folio_record.marc_record.fields('010').last.subfields).to match_array(
          [have_attributes(code: 'a', value: '   68038902 //r84')]
        )
      end

      it 'derives the ISSN from the identifiers' do
        expect(folio_record.marc_record['022'].subfields).to match_array(
          [have_attributes(code: 'a', value: '2381-5868')]
        )
      end

      it 'derives the OCLC number from the identifiers' do
        expect(folio_record.marc_record['035'].subfields).to match_array(
          [have_attributes(code: 'a', value: '(OCoLC-M)948533645')]
        )
      end
    end
  end

  describe 'the 590 field' do
    context 'when record has existing bound-with 590 in its MARC' do
      let(:record) do
        {
          'instance' => {
            'id' => '0e050e3f-b160-5f5d-9fdb-2d49305fbb0d'
          },
          'holdings' => [{
            'id' => 'd1eece03-e4b6-5bd3-b6be-3d76ae8cf96d',
            'callNumber' => '064.8 .D191H',
            'boundWith' => {
              'instance' => {
                'hrid' => '134624',
                'title' => 'Mursilis Sprachlähmung'
              },
              'item' => {
                'id' => 'd1eece03-e4b6-5bd3-b6be-3d76ae8cf96d',
                'barcode' => '36105018739321'
              }
            }
          }],
          'source_record' => [{
            'fields' => [
              { '001' => 'a14154194' },
              { '590' => {
                'subfields' => [
                  { 'a' => 'Cataloged info about the Bound-with' },
                  { 'c' => '1234 (parent record)' }
                ]
              } }
            ]
          }]
        }
      end

      it 'does not overwrite existing 590s' do
        expect(folio_record.marc_record.fields('590').length).to eq 1
        expect(folio_record.marc_record.fields('590').first.subfields).to match_array([
                                                                                        have_attributes(code: 'a', value: 'Cataloged info about the Bound-with'),
                                                                                        have_attributes(code: 'c', value: '1234 (parent record)')
                                                                                      ])
      end
    end

    context 'when 590 exists but it is not a bound-with and has Bound-with parents via FOLIO APIs' do
      let(:record) do
        {
          'instance' => {
            'id' => '0e050e3f-b160-5f5d-9fdb-2d49305fbb0d'
          },
          'holdings' => [{
            'id' => 'd1eece03-e4b6-5bd3-b6be-3d76ae8cf96d',
            'callNumber' => '064.8 .D191H',
            'boundWith' => {
              'instance' => {
                'hrid' => '134624',
                'title' => 'Mursilis Sprachlähmung'
              },
              'item' => {
                'id' => 'd1eece03-e4b6-5bd3-b6be-3d76ae8cf96d',
                'barcode' => '36105018739321'
              }
            }
          }],
          'source_record' => [{
            'fields' => [
              { '001' => 'a14154194' },
              { '590' => {
                'subfields' => [{ 'a' => 'Totally not a bound-with' }]
              } }
            ]
          }]
        }
      end
      it 'writes a new 590' do
        expect(folio_record.marc_record.fields('590').first.subfields).to match_array([
                                                                                        have_attributes(code: 'a', value: 'Totally not a bound-with')
                                                                                      ])
        expect(folio_record.marc_record.fields('590').last.subfields).to match_array([
                                                                                       have_attributes(code: 'a', value: '064.8 .D191H bound with Mursilis Sprachlähmung'),
                                                                                       have_attributes(code: 'c', value: '134624 (parent record)')
                                                                                     ])
      end
    end

    context 'when record does not have existing 590 in its MARC' do
      let(:record) do
        {
          'instance' => {
            'id' => '0e050e3f-b160-5f5d-9fdb-2d49305fbb0d'
          },
          'holdings' => [{
            'id' => 'd1eece03-e4b6-5bd3-b6be-3d76ae8cf96d',
            'callNumber' => '064.8 .D191H',
            'boundWith' => {
              'instance' => {
                'hrid' => '134624',
                'title' => 'Mursilis Sprachlähmung'
              },
              'item' => {
                'id' => 'd1eece03-e4b6-5bd3-b6be-3d76ae8cf96d',
                'barcode' => '36105018739321'
              }
            }
          }],
          'source_record' => [{
            'fields' => [
              { '001' => 'a14154194' }
            ]
          }]
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

  describe 'derived 856 fields' do
    let(:record) do
      {
        'instance' => {
          'id' => '0e050e3f-b160-5f5d-9fdb-2d49305fbb0d'
        },
        'holdings' => [{
          'electronicAccess' => [
            { 'uri' => 'http://example.com/2', 'name' => 'Resource' }
          ]
        }],
        'source_record' => [{
          'fields' => [
            { '001' => 'a14154194' },
            { '856' => {
              'subfields' => [
                { 'u' => 'http://example.com/1' }
              ]
            } }
          ]
        }]
      }
    end

    it 'replaces any 856 field data with a derived values from the electronic access statement in the FOLIO holdings' do
      expect(folio_record.marc_record.fields('856').length).to eq(1)
      expect(folio_record.marc_record['856'].subfields).to include(have_attributes(code: 'u', value: 'http://example.com/2'))
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

  describe '#sirsi_holdings' do
    context 'with an item with a temporary location' do
      let(:record) do
        {
          'instance' => {
            'id' => '0e050e3f-b160-5f5d-9fdb-2d49305fbb0d'
          },
          'pieces' => [{ 'id' => '3b0c1675-b3ec-4bc4-888d-2519fb72b71f',
                         'holdingId' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
                         'receivingStatus' => 'Expected',
                         'displayOnHolding' => false }],
          'holdings' => [{
            'id' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
            'location' => {
              'effectiveLocation' => {
                'code' => 'GRE-STACKS'
              }
            }
          }],
          'items' => [{
            'holdingsRecordId' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
            'location' => {
              'temporaryLocation' => {
                'code' => 'GRE-CRES'
              }
            }
          }],
          'source_record' => [{
            'fields' => [
              { '001' => 'a14154194' }
            ]
          }]
        }
      end

      it 'uses the temp location as the current location' do
        expect(folio_record.sirsi_holdings.first).to have_attributes(
          current_location: 'GRE-CRES',
          home_location: 'STACKS',
          library: 'GREEN'
        )
      end
    end

    context 'with an item with a permanent location' do
      let(:record) do
        {
          'instance' => {
            'id' => '0e050e3f-b160-5f5d-9fdb-2d49305fbb0d'
          },
          'pieces' => [{ 'id' => '3b0c1675-b3ec-4bc4-888d-2519fb72b71f',
                         'holdingId' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
                         'receivingStatus' => 'Expected',
                         'displayOnHolding' => false }],
          'holdings' => [{
            'id' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
            'location' => {
              'effectiveLocation' => {
                'code' => 'GRE-STACKS'
              }
            }
          }],
          'items' => [{
            'holdingsRecordId' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
            'location' => {
              'permanentLocation' => {
                'code' => 'GRE-HH-MAGAZINE'
              }
            }
          }],
          'source_record' => [{
            'fields' => [
              { '001' => 'a14154194' }
            ]
          }]
        }
      end

      it 'uses the permanent location of the item as the home location' do
        expect(folio_record.sirsi_holdings.first).to have_attributes(
          current_location: nil,
          home_location: 'MAGAZINE',
          library: 'GREEN'
        )
      end
    end

    context 'with an item without a permanent location' do
      let(:record) do
        {
          'instance' => {
            'id' => '0e050e3f-b160-5f5d-9fdb-2d49305fbb0d'
          },
          'pieces' => [{ 'id' => '3b0c1675-b3ec-4bc4-888d-2519fb72b71f',
                         'holdingId' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
                         'receivingStatus' => 'Expected',
                         'displayOnHolding' => false }],
          'holdings' => [{
            'id' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
            'location' => {
              'effectiveLocation' => {
                'code' => 'GRE-STACKS'
              }
            }
          }],
          'items' => [{
            'holdingsRecordId' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
            'location' => {}
          }],
          'source_record' => [{
            'fields' => [
              { '001' => 'a14154194' }
            ]
          }]
        }
      end

      it 'uses the effective location of the holding as the home location' do
        expect(folio_record.sirsi_holdings.first).to have_attributes(
          current_location: nil,
          home_location: 'STACKS',
          library: 'GREEN'
        )
      end
    end

    context 'with an item without a temporary location' do
      let(:record) do
        {
          'instance' => {
            'id' => '0e050e3f-b160-5f5d-9fdb-2d49305fbb0d'
          },
          'pieces' => [{ 'id' => '3b0c1675-b3ec-4bc4-888d-2519fb72b71f',
                         'holdingId' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
                         'receivingStatus' => 'Expected',
                         'displayOnHolding' => false }],
          'holdings' => [{
            'id' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
            'location' => {
              'effectiveLocation' => {
                'code' => 'GRE-STACKS'
              }
            }
          }],
          'items' => [{
            'holdingsRecordId' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
            'status' => 'In process',
            'location' => {}
          }],
          'source_record' => [{
            'fields' => [
              { '001' => 'a14154194' }
            ]
          }]
        }
      end

      it 'uses the item status of the holding as the current location' do
        expect(folio_record.sirsi_holdings.first).to have_attributes(
          current_location: 'INPROCESS',
          home_location: 'STACKS',
          library: 'GREEN'
        )
      end
    end
    context 'with Symphony migrated data without on-order item records' do
      let(:record) do
        {
          'instance' => {
            'id' => '0e050e3f-b160-5f5d-9fdb-2d49305fbb0d'
          },
          'pieces' => [{ 'id' => '3b0c1675-b3ec-4bc4-888d-2519fb72b71f',
                         'holdingId' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
                         'receivingStatus' => 'Expected',
                         'displayOnHolding' => false }],
          'holdings' => [{
            'id' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
            'location' => {
              'effectiveLocation' => {
                'code' => 'GRE-STACKS'
              }
            }
          }],
          'items' => [],
          'source_record' => [{
            'fields' => [
              { '001' => 'a14154194' }
            ]
          }]
        }
      end

      it 'creates a stub on-order item' do
        expect(folio_record.sirsi_holdings.first).to have_attributes(
          barcode: nil,
          current_location: 'ON-ORDER',
          home_location: 'STACKS',
          library: 'GREEN'
        )
      end
    end
  end
end
