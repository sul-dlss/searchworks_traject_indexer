# frozen_string_literal: true

require 'spec_helper'

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

    context 'with private notes' do
      let(:record) do
        {
          'instance' => {
            'id' => '0e050e3f-b160-5f5d-9fdb-2d49305fbb0d'
          },
          'holdings' => [],
          'source_record' => [{
            'fields' => [
              { '243' => {
                'ind1' => '0',
                'subfields' => [
                  { 'a' => 'An example of a private note' }
                ]
              } }
            ]
          }]
        }
      end

      it 'strips the record of that private note entirely' do
        expect(folio_record.marc_record['243']).to be_blank
      end
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
          'items' => [],
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
          'items' => [],
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
            { 'uri' => 'http://example.com/2', 'name' => 'Resource', 'materialsSpecification' => 'Provider' }
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
      expect(folio_record.marc_record['856'].subfields).to include(have_attributes(code: '3', value: 'Provider'), have_attributes(code: 'u', value: 'http://example.com/2'))
      expect(folio_record.marc_record['856'].subfields).not_to include(have_attributes(code: 'y'), have_attributes(code: 'z'))
    end

    context 'with nil electronicAccess data' do
      let(:record) do
        {
          'instance' => {
            'id' => '0e050e3f-b160-5f5d-9fdb-2d49305fbb0d'
          },
          'holdings' => [{
            'electronicAccess' => nil
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

      it 'does nothing with the 856 field data' do
        expect(folio_record.marc_record.fields('856').length).to eq(1)
        expect(folio_record.marc_record['856'].subfields).to include(have_attributes(code: 'u', value: 'http://example.com/1'))
      end
    end
  end

  describe '#index_items' do
    subject(:index_items) { folio_record.index_items }

    context 'bound-withs' do
      context 'when the bound with child is not in SAL3' do
        let(:folio_record) { described_class.new(JSON.parse(File.read(file_fixture('folio_bw_child.json'))), client) }
        it 'does not add SEE-OTHER as the display_location' do
          expect(index_items.first.display_location_code).not_to eq('SEE-OTHER')
        end
      end

      context 'when the bound with child is in SAL3' do
        let(:folio_record) { described_class.new(JSON.parse(File.read(file_fixture('folio_bw_child_see-other.json'))), client) }
        it 'adds SEE-OTHER as the display_location' do
          skip('Unclear whether we need to preserve this behavior in FOLIO')
          expect(index_items.first.display_location_code).to eq('SEE-OTHER')
        end
      end

      context 'for a bound-with principal' do
        let(:folio_record) { described_class.new(JSON.parse(File.read(file_fixture('folio_bw_principal.json'))), client) }

        it 'includes the bound-with principal only once' do
          expect(index_items).to contain_exactly(have_attributes(id: '2b9ba8c6-f25c-5ba2-a159-418a0c335703'))
        end
      end

      context 'with Symphony migrated data without the right linkages between the bound-with holding and item' do
        let(:record) do
          {
            'instance' => {
              'id' => '0e050e3f-b160-5f5d-9fdb-2d49305fbb0d',
              'hrid' => 'a14154194'
            },
            'holdings' => [{
              'id' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
              'holdingsType' => { 'name' => 'Bound-with' },
              'location' => {
                'effectiveLocation' => {
                  'code' => 'EAR-SEE-OTHER',
                  'library' => { 'code' => 'EARTH-SCI' }
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

        it 'creates a stub bound-with item' do
          expect(index_items.first).to have_attributes(
            id: nil,
            # barcode: '14154194-1001',
            display_location_code: 'EAR-SEE-OTHER',
            library: 'EARTH-SCI'
          )
        end
      end
    end

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
                'code' => 'GRE-STACKS',
                'library' => { 'code' => 'GREEN' }
              }
            }
          }],
          'items' => [{
            'holdingsRecordId' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
            'location' => {
              'temporaryLocation' => {
                'code' => 'GRE-SSRC',
                'library' => { 'code' => 'GREEN' }
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
        expect(index_items.first).to have_attributes(
          temporary_location_code: 'GRE-SSRC',
          display_location_code: 'GRE-STACKS',
          library: 'GREEN'
        )
      end
    end

    context 'with an item with a course reserves-like location' do
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
                'code' => 'SAL3-STACKS'
              }
            }
          }],
          'items' => [{
            'holdingsRecordId' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
            'location' => {
              'temporaryLocation' => {
                'code' => 'GRE-CRES',
                'library' => { 'code' => 'GREEN' },
                'details' => {
                  'searchworksTreatTemporaryLocationAsPermanentLocation' => 'true'
                }
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

      it 'uses the temp location as the home location' do
        expect(index_items.first).to have_attributes(
          display_location_code: 'GRE-CRES',
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
                'code' => 'GRE-STACKS',
                'library' => { 'code' => 'GREEN' }
              }
            }
          }],
          'items' => [{
            'holdingsRecordId' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
            'location' => {
              'permanentLocation' => {
                'code' => 'GRE-HH-MAGAZINE',
                'library' => { 'code' => 'GREEN' }
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
        expect(index_items.first).to have_attributes(
          display_location_code: 'GRE-HH-MAGAZINE',
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
                'code' => 'GRE-STACKS',
                'library' => { 'code' => 'GREEN' }
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
        expect(index_items.first).to have_attributes(
          display_location_code: 'GRE-STACKS',
          library: 'GREEN'
        )
      end
    end

    context 'with an item with a temporary location that implies availability' do
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
                'code' => 'SAL3-STACKS',
                'library' => { 'code' => 'SAL3' }
              }
            }
          }],
          'items' => [{
            'holdingsRecordId' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
            'status' => 'In transit',
            'location' => {
              'temporaryLocation' => {
                'code' => 'SUL-TS-PROCESSING',
                'details' => {
                  'availabilityClass' => 'In_process'
                }
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

      it 'uses the FOLIO location code as the current location' do
        expect(index_items.first).to have_attributes(
          display_location_code: 'SAL3-STACKS',
          library: 'SAL3',
          temporary_location_code: 'SUL-TS-PROCESSING'
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
                'code' => 'GRE-STACKS',
                'library' => { 'code' => 'GREEN' }
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
        expect(index_items.first).to have_attributes(
          display_location_code: 'GRE-STACKS',
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
                'code' => 'GRE-STACKS',
                'library' => { 'code' => 'GREEN' }
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
        expect(index_items.first).to have_attributes(
          barcode: nil,
          status: 'On order',
          display_location_code: 'GRE-STACKS',
          library: 'GREEN'
        )
      end
    end
  end

  describe '#courses' do
    context 'with a suppressed e-resource' do
      let(:record) do
        {
          'items' => [{
            'suppressedFromDiscovery' => true,
            'courses' => [{
              'name' => 'CHEM 31A'
            }]
          }]
        }
      end

      it 'returns the course for the suppressed item' do
        expect(folio_record.courses).to match_array(hash_including(course_name: 'CHEM 31A'))
      end
    end
  end

  describe '#eresource?' do
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
           'holdingsStatements' => [] }] }
    end

    let(:source_record_json) do
      JSON.parse(File.read(file_fixture('a12451243.json')))
    end

    let(:folio_record) do
      FolioRecord.new_from_source_record(source_record_json, client)
    end

    before do
      allow(folio_record).to receive(:items_and_holdings).and_return(items_and_holdings)
    end

    context 'record does not have any fulltext links (but does have an 856/956)' do
      let(:source_record_json) do
        JSON.parse(File.read(file_fixture('a14185492.json')))
      end

      it { is_expected.to be_eresource }
    end

    context 'the holding library is Lane (without a explicit holdingsType)' do
      let(:items_and_holdings) do
        { 'items' => [],
          'holdings' =>
          [{ 'location' =>
            { 'permanentLocation' =>
              { 'code' => 'LANE-EDATA' },
              'effectiveLocation' =>
              { 'code' => 'LANE-EDATA', 'library' => { 'code' => 'LANE' }, 'details' => { 'holdingsTypeName' => 'Electronic' } } },
             'holdingsType' => { 'name' => 'Monograph' },
             'suppressFromDiscovery' => false,
             'id' => '81a56270-e8dd-5759-8083-5cc96cdf0045',
             'holdingsStatements' => [] }] }
      end

      it { is_expected.to be_eresource }
    end
  end
end
