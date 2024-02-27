# frozen_string_literal: true

require 'spec_helper'

describe 'comparing against a well-known location full of documents generated by solrmarc' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:record) { MARC::XMLReader.new(StringIO.new(marcxml)).to_a.first }
  let(:copy_fields) do
    %w[collection_search pub_date_search db_az_subject_search instructor course topic_display subject_other_display
       title_variant_display summary_display pub_display]
  end
  let(:ignored_fields) do
    %w[all_search created last_updated format _version_ author_sort author_title_search callnum_facet_hsim marcbib_xml marcxml mhld_display fund_facet building_facet collection] + copy_fields
  end
  let(:pending_fields) { %w[reverse_shelfkey shelfkey preferred_barcode item_display date_cataloged access_facet] }
  subject(:result) { indexer.map_record(folio_record).transform_values { |v| v.sort } }
  let(:folio_record) { marc_to_folio(record) }

  let(:holding_data) do
    # rubocop:disable Layout/LineLength
    { 'a7096288' => [{ permanent_location_code: 'STACKS', library: 'GREEN', item: { 'callNumberType' => { 'name' => 'LC' }, 'callNumber' => { 'callNumber' => 'DG70 .P7 W77 2007' }, 'barcode' => '36105123307642' } }],
      'a12000520' => [{ permanent_location_code: 'STACKS', library: 'GREEN', item: { 'callNumberType' => { 'name' => 'LC' }, 'callNumber' => { 'callNumber' => 'JZ1310 .R46 2017' }, 'barcode' => '36105225395669' } }],
      'a24200' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '868.4 .H899LA' }, 'barcode' =>  '36105044915473' } }],
      'a31341' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '281.9 .A781PM' }, 'barcode' =>  '36105046826009' } }],
      'a7097007' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'Shelving control number' }, 'callNumber' => { 'callNumber' => 'EPRI NP-1570 V.1' }, 'barcode' => '36105129611187' } }, { permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'Shelving control number' }, 'callNumber' => { 'callNumber' => 'EPRI NP-1570 V.2' }, 'barcode' => '36105129611179' } }],
      'a12006180' => [{ type: 'ONLINE', permanent_location_code: 'INTERNET', library: 'SUL', item: { 'callNumberType' => { 'name' => 'OTHER' }, 'barcode' => '12006180-1001' } }],
      'a26883' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'LC' }, 'callNumber' => { 'callNumber' => 'PQ8519 .M213 E4' }, 'barcode' => '36105033482840' } }],
      'a7096181' => [{ permanent_location_code: 'STACKS', library: 'GREEN', item: { 'callNumberType' => { 'name' => 'LC' }, 'callNumber' => { 'callNumber' => 'PR6114 .A35 L66 2007' }, 'barcode' => '36105123309457' } }],
      'a12000222' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'LC' }, 'callNumber' => { 'callNumber' => 'NK3638 .K56 A4 2000' }, 'barcode' => '36105222297884'  } }],
      'a47981' => [{ permanent_location_code: 'SEE-OTHER', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '331.9074 .K15 NO.89' }, 'barcode' => '47981-2001' } }],
      'a20279' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '472 .W158' }, 'barcode' => '36105047738104' } }],
      'a39562' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'LC' }, 'callNumber' => { 'callNumber' => 'F2581 .M68' }, 'barcode' => '36105033500658' } }],
      'a25184' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'LC' }, 'callNumber' => { 'callNumber' => 'F2845 .P56' }, 'barcode' => '36105033472817' } }],
      'a7070581' => [{ permanent_location_code: 'CHINESE', library: 'EAST-ASIA', item: { 'callNumberType' => { 'name' => 'LC' }, 'callNumber' => { 'callNumber' => 'S471 .C62 I568 2006' }, 'barcode' => '36105129913419' } }],
      'a43871' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'LC' }, 'callNumber' => { 'callNumber' => 'AS182 .H125 1966:V.26' }, 'barcode' => '36105033522975' } }],
      'a32038' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '914.472 .L628P' }, 'barcode' => '36105048600121' } }],
      'a43228' => [{ permanent_location_code: 'STACKS', library: 'GREEN', item: { 'callNumberType' => { 'name' => 'LC' }, 'callNumber' => { 'callNumber' => 'PA8118 .I5 S3 V.3' }, 'barcode' => '36105033519245'  } }],
      'a36560' => [{ permanent_location_code: 'PAGE-SP', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '297 .K842SA' }, 'barcode' =>  '36105025612040' } }],
      'a43716' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '330.92 .K94M' }, 'barcode' =>  '36105047262766' } }],
      'a34351' => [{ permanent_location_code: 'STACKS', library: 'SAL', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '917.9 .R956' }, 'barcode' => '36105048657089' } }],
      'a44964' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '330.954 .R313' }, 'barcode' => '36105047275958' } }],
      'a20815' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '492 .D784' }, 'barcode' =>  '36105047754911' } }],
      'a29763' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '282.1 .F825C' }, 'barcode' => '36105046830027' } }],
      'a12005356' => [{ permanent_location_code: 'ASK@LANE', library: 'LANE', item: { 'callNumberType' => { 'name' => 'LC' }, 'callNumber' => { 'callNumber' => 'AMA PUBL GROUP' }, 'barcode' => 'LL328803' } }],
      'a16671' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '204 .S855' }, 'barcode' => '36105019985089' } }],
      'a21608' => [{ permanent_location_code: 'SOUTH-MEZZ', library: 'SAL', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '094.442 .B334B' }, 'barcode' => '36105128988354' } }],
      'a29931' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '910 .B974' }, 'barcode' => '36105048551472' } }, { call_number: '910 .B974', permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '' }, 'barcode' => '36105048551480' } }],
      'a11065' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '135.2 .D372' }, 'barcode' => '36105046653627' } }],
      'a14883' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '224.1 .K36' }, 'barcode' => '36105020071994' } }],
      'a7000325' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'LC' }, 'callNumber' => { 'callNumber' => 'DK508.9 .K78 C745 1960Z' }, 'barcode' => '36105129616095' } }],
      'a12002011' => [{ type: 'ONLINE', permanent_location_code: 'INTERNET', library: 'SUL', item: { 'callNumberType' => { 'name' => 'OTHER' }, 'barcode' => '12002011-1001' } }],
      'a3500626' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'LC' }, 'callNumber' => { 'callNumber' => 'M1112 .A336 OP.10 NO.12 1996' }, 'barcode' => '36105017303723' } }],
      'a3503542' => [{ permanent_location_code: 'STACKS', library: 'GREEN', item: { 'callNumberType' => { 'name' => 'LC' }, 'callNumber' => { 'callNumber' => 'PS3563 .A67 R43 1996' }, 'barcode' =>  '36105020713389' } }],
      'a38116' => [{ permanent_location_code: 'SEE-OTHER', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '842.05 .P48 NO.21' }, 'barcode' =>  '38116-2001' } }],
      'a43508' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '330.91 .J35' }, 'barcode' => '36105047260786' } }],
      'a39408' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'LC' }, 'callNumber' => { 'callNumber' => 'F2581 .S3' }, 'barcode' => '36105033499786' } }],
      'a35203' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '919.11 .H474I' }, 'barcode' => '36105048674175' } }],
      'a3504435' => [{ permanent_location_code: 'SAL-PAGE', library: 'SAL', item: { 'callNumberType' => { 'name' => 'LC' }, 'callNumber' => { 'callNumber' => 'D2009 .S245 1997' }, 'barcode' => '36105070697011' } }],
      'a6412' => [{ permanent_location_code: 'RECORDINGS', library: 'ARS', item: { 'callNumberType' => { 'name' => 'OTHER' }, 'callNumber' => { 'callNumber' => 'UNCLAAA6821' }, 'barcode' => '001AAA6821' } }, { permanent_location_code: 'PAGE-LP', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'Shelving control number' }, 'callNumber' => { 'callNumber' => 'MD 3657' }, 'barcode' => '36105011299257' } }],
      'a7046041' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'Shelving control number' }, 'callNumber' => { 'callNumber' => 'CALIF E1950 .R4 NO.881M 1974:SUPPL.' }, 'barcode' => '36105005778845' } }, { permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'Shelving control number' }, 'callNumber' => { 'callNumber' => 'CALIF E1950 .R4 NO.881M 1970/1972:SUPPL.' }, 'barcode' => '36105126951651' } }, { permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'Shelving control number' }, 'callNumber' => { 'callNumber' => 'CALIF E1950 .R4 NO.881M 1970/1972' }, 'barcode' => '36105005778878' } }, { permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'Shelving control number' }, 'callNumber' => { 'callNumber' => 'CALIF E1950 .R4 NO.881M 1970/1971' }, 'barcode' => '36105113722453' } }],
      'a48334' => [{ permanent_location_code: 'SEE-OTHER', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'LC' }, 'callNumber' => { 'callNumber' => 'DK401 .P895 V.21:PT.2' }, 'barcode' => '001AAF0578' } }],
      'a12007015' => [{ type: 'ONLINE', permanent_location_code: 'INTERNET', library: 'SUL', item: { 'callNumberType' => { 'name' => 'OTHER' }, 'callNumber' => { 'callNumber' => '' }, 'barcode' => '12007015-1001' } }],
      'a12003712' => [{ permanent_location_code: 'ASK@LANE', library: 'LANE', item: { 'callNumberType' => { 'name' => 'LC' }, 'callNumber' => { 'callNumber' => 'Q603 .H47 1960' }, 'barcode' => 'LL112120' } }],
      'a12001577' => [{ type: 'ONLINE', permanent_location_code: 'INTERNET', library: 'SUL', item: { 'callNumberType' => { 'name' => 'OTHER' }, 'barcode' => '12001577-1001' } }],
      'a48749' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'LC' }, 'callNumber' => { 'callNumber' => 'P25 .P4 V.27' }, 'barcode' => '36105033528972' } }],
      'a16573' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '252 .R649SR' }, 'barcode' => '36105010340714' } }],
      'a28142' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '901.2 .J79' }, 'barcode' => '36105048536309' } }, { permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'DEWEY' }, 'callNumber' => { 'callNumber' => '901.2 .J79' }, 'barcode' => '36105048536317' } }],
      'a6295' => [{ permanent_location_code: 'RECORDINGS', library: 'ARS', item: { 'callNumberType' => { 'name' => 'OTHER' }, 'callNumber' => { 'callNumber' => 'UNCLAAA6697' }, 'barcode' => '001AAA6697'  } }],
      'a7045704' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'LC' }, 'callNumber' => { 'callNumber' => 'PN6222 .A3 N39 2000Z' }, 'barcode' => '36105128770034' } }],
      'a14161' => [{ permanent_location_code: 'STACKS', library: 'SAL3', item: { 'callNumberType' => { 'name' => 'LC' }, 'callNumber' => { 'callNumber' => 'BD161 .P72' }, 'barcode' => '36105000254214' } }] }
    # rubocop:enable Layout/LineLength
  end

  Dir.glob(File.expand_path('solrmarc_example_docs/*', file_fixture_path)).each do |fixture|
    context "with #{fixture}" do
      before do
        holdings = holding_data[folio_record.instance_id].map { |data| build(:holding, data) }
        allow(folio_record).to receive(:index_items).and_return(holdings)
      end

      let(:file) { File.read(fixture) }
      let(:data) { JSON.parse(file) }
      let(:solrmarc_doc) { data['doc'] }
      let(:expected_doc) do
        data['doc'].transform_values { |v| Array(v).map(&:to_s).sort }
      end
      let(:marcxml) { solrmarc_doc['marcxml'] }

      it 'maps the same general output' do
        # Stub the year so this test doesn't fail every January
        allow_any_instance_of(Time).to receive(:year).and_return(2019)
        expect(result).to include expected_doc.reject { |k, _v| (ignored_fields + pending_fields).include? k }
      end

      it 'maps the same general output' do
        skip unless pending_fields.any?
        pending
        expect(result.select { |k, _v| pending_fields.include? k }).to include expected_doc.select { |k, _v|
                                                                                 pending_fields.include? k
                                                                               }
        expect(false).to eq true # keep rspec happy if the above happens to pass
      end

      it 'maps collection' do
        # FOLIO add 'folio' to the list
        expect(result['collection']).to include(*expected_doc['collection'])
      end

      it 'maps building_facet' do
        # Some buildings change display names in FOLIO
        expect(result['building_facet']).to eq(expected_doc['building_facet']&.map do |x|
          case x
          when 'SAL1&2 (on-campus shelving)' then 'SAL1&2 (on-campus storage)'
          when 'Medical (Lane)' then 'Lane Medical'
          else
            x
          end
        end)
      end
    end
  end
end
