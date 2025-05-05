# frozen_string_literal: true

RSpec.describe 'Access config' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:result) { indexer.map_record(record) }
  let(:record) { FolioRecord.new(folio_response, client) }
  let(:folio_response) do
    empty_holdings = { 'holdingsStatements' => [], 'holdingsStatementsForIndexes' => [], 'holdingsStatementsForSupplements' => [] }
    {
      'source_record' => [marc_record.to_hash],
      'instance' => { 'hrid' => 'in0001', 'statisticalCodes' => [] }.merge(instance),
      'holdings' => holdings.map { |h| empty_holdings.merge(h) },
      'items' => items,
      'pieces' => pieces
    }
  end
  let(:instance) { {} }
  let(:holdings) { [] }
  let(:items) { [] }
  let(:pieces) { [] }
  let(:client) { instance_double(FolioClient, statistical_codes: [], instance: {}) }
  let(:marc_record) { MARC::Record.new }

  describe 'access_facet' do
    subject(:field) { result['access_facet'] }

    context 'with an electronic resource' do
      let(:marc_record) do
        MARC::Record.new.tap do |r|
          r.leader = '00988nas a2200193z  4500'
          r.append(MARC::ControlField.new('008', '071214uuuuuuuuuxx uu |ss    u|    |||| d'))
          r.append(MARC::DataField.new('956', '4', '0',
                                       MARC::Subfield.new('u', 'http://caslon.stanford.edu:3210/sfxlcl3?url_ver=Z39.88-2004&amp;ctx_ver=Z39.88-2004&amp;ctx_enc=info:ofi/enc:UTF-8&amp;rfr_id=info:sid/sfxit.com:opac_856&amp;url_ctx_fmt=info:ofi/fmt:kev:mtx:ctx&amp;sfx.ignore_date_threshold=1&amp;rft.object_id=110978984448763&amp;svc_val_fmt=info:ofi/fmt:kev:mtx:sch_svc&amp;')))
        end
      end
      let(:holdings) do
        [{ 'holdingsType' => { 'name' => 'Electronic' },
           'location' => { 'effectiveLocation' => { 'code' => 'SUL-ELECTRONIC' } } }]
      end

      specify { expect(field).to contain_exactly 'Online' }
    end

    context 'for an item' do
      let(:holdings) do
        [{
          'id' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
          'location' => {
            'effectiveLocation' => {
              'code' => 'GRE-STACKS'
            }
          }
        }]
      end

      let(:items) do
        [{
          'holdingsRecordId' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
          'location' => {}
        }]
      end

      specify { expect(field).to eq ['At the Library'] }
    end

    context 'with a bound-with' do
      let(:record) { FolioRecord.new(JSON.parse(File.read(file_fixture('folio_bw_child.json'))), client) }

      specify { expect(field).to eq ['At the Library'] }
    end

    context 'for an item with electronic holdings too' do
      let(:holdings) do
        [{
          'id' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
          'location' => {
            'effectiveLocation' => {
              'code' => 'GRE-STACKS'
            }
          }
        }] +
          [{ 'holdingsType' => { 'name' => 'Electronic' },
             'location' => { 'effectiveLocation' => { 'code' => 'SUL-ELECTRONIC' } } }]
      end

      let(:marc_record) do
        MARC::Record.new.tap do |r|
          r.leader = '00988nas a2200193z  4500'
          r.append(MARC::ControlField.new('008', '071214uuuuuuuuuxx uu |ss    u|    |||| d'))
          r.append(MARC::DataField.new('956', '4', '0',
                                       MARC::Subfield.new('u', 'http://caslon.stanford.edu:3210/sfxlcl3?url_ver=Z39.88-2004&amp;ctx_ver=Z39.88-2004&amp;ctx_enc=info:ofi/enc:UTF-8&amp;rfr_id=info:sid/sfxit.com:opac_856&amp;url_ctx_fmt=info:ofi/fmt:kev:mtx:ctx&amp;sfx.ignore_date_threshold=1&amp;rft.object_id=110978984448763&amp;svc_val_fmt=info:ofi/fmt:kev:mtx:sch_svc&amp;')))
        end
      end

      let(:items) do
        [{
          'holdingsRecordId' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
          'location' => {}
        }]
      end

      specify { expect(field).to contain_exactly 'At the Library', 'Online' }
    end

    context 'with an associated order' do
      let(:holdings) do
        [{
          'id' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
          'location' => {
            'effectiveLocation' => {
              'code' => 'GRE-STACKS'
            }
          }
        }]
      end

      let(:pieces) do
        [{
          'holdingId' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
          'receivingStatus' => 'Expected',
          'discoverySuppress' => false
        }]
      end

      specify { expect(field).to contain_exactly 'On order' }
    end

    context 'with item and also an associated order' do
      let(:holdings) do
        [{
          'id' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
          'location' => {
            'effectiveLocation' => {
              'code' => 'GRE-STACKS'
            }
          }
        }]
      end

      let(:items) do
        [{
          'holdingsRecordId' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
          'location' => {}
        }]
      end

      let(:pieces) do
        [{
          'holdingId' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
          'receivingStatus' => 'Expected',
          'discoverySuppress' => false
        }]
      end

      specify { expect(field).to contain_exactly 'At the Library' }
    end

    context 'for a suppressed item' do
      let(:holdings) do
        [{
          'id' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
          'location' => {
            'effectiveLocation' => {
              'code' => 'GRE-STACKS'
            }
          }
        }]
      end

      let(:items) do
        [{
          'holdingsRecordId' => '1146c4fa-5798-40e1-9b8e-92ee4c9f2ee2',
          'location' => {},
          'suppressFromDiscovery' => true
        }]
      end

      specify { expect(field).to be_nil }
    end

    context 'by default' do
      specify { expect(field).to be_nil }
    end
  end

  describe 'access_status_ssim' do
    subject(:field) { result['access_status_ssim'] }

    context 'with an 856$7 == "0"' do
      let(:marc_record) do
        MARC::Record.new.tap do |r|
          r.leader = '00988nas a2200193z  4500'
          r.append(MARC::ControlField.new('008', '071214uuuuuuuuuxx uu |ss    u|    |||| d'))
          r.append(MARC::DataField.new('856', '4', '0',
                                       MARC::Subfield.new('7', '0')))
        end
      end

      specify { expect(field).to contain_exactly 'Open Access' }
    end

    context 'by default' do
      specify { expect(field).to be_nil }
    end
  end
end
