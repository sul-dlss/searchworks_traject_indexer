# frozen_string_literal: true

RSpec.describe 'ItemInfo config' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:record) { records.first }
  let(:folio_record) { marc_to_folio(record) }
  let(:result) { indexer.map_record(folio_record) }
  let(:record) { MARC::Record.new }
  let(:holdings) { [] }
  subject(:value) { result[field] }

  before do
    allow(folio_record).to receive(:item_holdings).and_return(holdings)
  end

  describe 'barcode_search' do
    let(:field) { 'barcode_search' }

    context 'with one barcode' do
      let(:holdings) { [build(:lc_holding, barcode: '36105033811451')] }

      it { is_expected.to eq ['36105033811451'] }
    end

    context 'with many barcodes' do
      let(:holdings) { [build(:lc_holding, barcode: '36105037439663'), build(:lc_holding, barcode: '36105001623284')] }

      it { is_expected.to eq %w[36105037439663 36105001623284] }
    end
  end

  describe 'building_facet' do
    let(:field) { 'building_facet' }

    context 'with ARS' do
      let(:holdings) { [build(:lc_holding, library: 'ARS')] }

      it { is_expected.to eq ['Archive of Recorded Sound'] }
    end

    context 'with ART' do
      let(:holdings) { [build(:lc_holding, library: 'ART')] }

      it { is_expected.to eq ['Art & Architecture (Bowes)'] }
    end

    context 'with SAL-NEWARK' do
      let(:holdings) { [build(:lc_holding, library: 'SAL-NEWARK')] }

      it { is_expected.to eq ['SAL Newark (off-campus storage)'] }
    end

    context 'with CLASSICS' do
      let(:holdings) { [build(:lc_holding, library: 'CLASSICS')] }

      it { is_expected.to eq ['Classics'] }
    end

    context 'with EARTH-SCI' do
      let(:holdings) { [build(:lc_holding, library: 'EARTH-SCI')] }

      it { is_expected.to eq ['Earth Sciences (Branner)'] }
    end

    context 'with EDUCATION' do
      let(:holdings) { [build(:lc_holding, library: 'EDUCATION')] }

      it { is_expected.to eq ['Education (Cubberley)'] }
    end

    context 'with ENG' do
      let(:holdings) { [build(:lc_holding, library: 'ENG')] }

      it { is_expected.to eq ['Engineering (Terman)'] }
    end

    context 'with BUSINESS' do
      let(:holdings) { [build(:lc_holding, library: 'BUSINESS')] }

      it { is_expected.to eq ['Business'] }
    end

    context 'with MARINE-BIO' do
      let(:holdings) { [build(:lc_holding, library: 'MARINE-BIO')] }

      it { is_expected.to eq ['Marine Biology (Miller)'] }
    end

    context 'with SPEC-COLL' do
      let(:holdings) { [build(:lc_holding, library: 'SPEC-COLL')] }

      it { is_expected.to eq ['Special Collections'] }
    end

    context 'with TANNER' do
      let(:holdings) { [build(:lc_holding, library: 'TANNER')] }

      it { is_expected.to eq ['Philosophy (Tanner)'] }
    end

    context 'with LAW' do
      let(:holdings) { [build(:lc_holding, library: 'LAW')] }

      it { is_expected.to eq ['Law (Crown)'] }
    end

    context 'with MUSIC' do
      let(:holdings) { [build(:lc_holding, library: 'MUSIC')] }

      it { is_expected.to eq ['Music'] }
    end

    context 'with EAST-ASIA' do
      let(:holdings) { [build(:lc_holding, library: 'EAST-ASIA')] }

      it { is_expected.to eq ['East Asia'] }
    end

    context 'with MEDIA-CENTER' do
      let(:holdings) { [build(:lc_holding, library: 'MEDIA-CENTER')] }

      it { is_expected.to eq ['Media Center'] }
    end

    context 'with RUMSEY-MAP' do
      let(:holdings) { [build(:lc_holding, library: 'RUMSEY-MAP')] }

      it { is_expected.to eq ['David Rumsey Map Center'] }
    end

    context 'with SCIENCE' do
      let(:holdings) { [build(:lc_holding, library: 'SCIENCE')] }

      it { is_expected.to eq ['Science (Li and Ma)'] }
    end

    context 'with SAL3' do
      let(:holdings) { [build(:lc_holding, library: 'SAL3')] }

      it { is_expected.to eq ['SAL3 (off-campus storage)'] }
    end

    context 'with LANE' do
      let(:holdings) { [build(:lc_holding, library: 'LANE')] }

      it { is_expected.to eq ['Lane Medical'] }
    end

    context 'with HILA' do
      let(:holdings) { [build(:lc_holding, library: 'HILA')] }

      it { is_expected.to eq ['Hoover Institution Library & Archives'] }
    end

    context 'with multiple holdings' do
      let(:holdings) { [build(:lc_holding, library: 'GREEN'), build(:lc_holding, library: 'SAL')] }

      it { is_expected.to eq ['Green', 'SAL1&2 (on-campus storage)'] }
    end
  end

  describe 'building_location_facet_ssim' do
    let(:field) { 'building_location_facet_ssim' }

    context 'with ARS/STACKS' do
      let(:holdings) { [build(:lc_holding, library: 'ARS', permanent_location_code: 'STACKS', type: 'STKS-MONO')] }

      it { is_expected.to include 'ARS/STACKS', 'ARS/STACKS/type/STKS-MONO', 'ARS/*/type/STKS-MONO' }
    end

    context 'with GREEN/STACKS' do
      let(:holdings) { [build(:lc_holding, library: 'GREEN', permanent_location_code: 'STACKS', type: 'STKS-MONO')] }

      it { is_expected.to include 'GREEN/STACKS', 'GREEN/STACKS/type/STKS-MONO', 'GREEN/*/type/STKS-MONO' }
    end
  end

  describe 'item_display_struct' do
    let(:field) { 'item_display_struct' }
    subject(:value) { result[field].map { |x| JSON.parse(x) } }

    context 'when an item is on-order' do
      # NOTE: This test exercises on_order_stub_holdings
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(
            MARC::DataField.new(
              '596', ' ', ' ',
              MARC::Subfield.new('a', '1 2 22')
            )
          )
        end
      end

      it { is_expected.to match_array([hash_including('library' => 'GREEN'), hash_including('library' => 'ART')]) }
    end

    context 'when an item is bound-with' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(
            MARC::DataField.new(
              '590', ' ', ' ',
              MARC::Subfield.new('a', 'bound with something else'),
              MARC::Subfield.new('c', '1234 (parent catkey)')
            )
          )
        end
      end

      context 'without any holdings' do
        it 'omits the on-order placeholder' do
          expect(result[field]).to be_nil
        end
      end

      context 'with holdings' do
        let(:holdings) { [build(:lc_holding, :bound_with)] }

        before do
          allow(folio_record).to receive(:item_holdings).and_return([])
          allow(folio_record).to receive(:bound_with_holdings).and_return(holdings)
        end

        it 'contains a bound_with parent' do
          expect(value).to match_array([
                                         hash_including('bound_with' => {
                                                          'call_number' => '630.654 .I39M', 'chronology' => nil,
                                                          'enumeration' => 'V.5:NO.1', 'hrid' => 'a5488000',
                                                          'title' => 'The gases of swamp rice soils ...',
                                                          'volume' => nil
                                                        })
                                       ])
        end
      end
    end

    describe 'field is populated correctly, focusing on building/library' do
      context 'when library is APPLIEDPHY' do
        let(:holdings) { [build(:lc_holding, library: 'APPLIEDPHY')] }

        it { is_expected.to match_array([hash_including('library' => 'APPLIEDPHY')]) }
      end

      context 'when library is ART' do
        let(:holdings) { [build(:lc_holding, library: 'ART')] }

        it { is_expected.to match_array([hash_including('library' => 'ART')]) }
      end

      context 'when library is CLASSICS' do
        let(:holdings) { [build(:lc_holding, library: 'CLASSICS')] }

        it { is_expected.to match_array([hash_including('library' => 'CLASSICS')]) }
      end

      context 'when library is ENG' do
        let(:holdings) { [build(:lc_holding, library: 'ENG')] }

        it { is_expected.to match_array([hash_including('library' => 'ENG')]) }
      end

      context 'when library is GOV-DOCS' do
        let(:holdings) { [build(:lc_holding, library: 'GOV-DOCS')] }

        it { is_expected.to match_array([hash_including('library' => 'GOV-DOCS')]) }
      end

      context 'when library is GREEN' do
        let(:holdings) { [build(:lc_holding, library: 'GREEN')] }

        it { is_expected.to match_array([hash_including('library' => 'GREEN')]) }
      end

      context 'when library is HILA' do
        let(:holdings) { [build(:lc_holding, library: 'HILA')] }

        it { is_expected.to match_array([hash_including('library' => 'HILA')]) }
      end

      context 'when library is SAL3' do
        let(:holdings) { [build(:lc_holding, library: 'SAL3')] }

        it { is_expected.to match_array([hash_including('library' => 'SAL3')]) }
      end

      context 'when library is SCIENCE' do
        let(:holdings) { [build(:lc_holding, library: 'SCIENCE')] }

        it { is_expected.to match_array([hash_including('library' => 'SCIENCE')]) }
      end

      context 'when library is SPEC-COLL' do
        let(:holdings) { [build(:lc_holding, library: 'SPEC-COLL')] }

        it { is_expected.to match_array([hash_including('library' => 'SPEC-COLL')]) }
      end

      context 'when library is LANE' do
        let(:holdings) { [build(:lc_holding, barcode: '36105082101390', call_number: 'Z3871.Z8 V.22 1945', library: 'LANE')] }

        it { is_expected.to match_array([hash_including('barcode' => '36105082101390', 'library' => 'LANE', 'callnumber' => 'Z3871.Z8 V.22 1945')]) }
      end

      context 'with multiple holdings in single record, diff buildings' do
        let(:holdings) do
          [build(:lc_holding, call_number: 'BX4659.E85 W44', barcode: '36105037439663', library: 'GREEN'),
           build(:lc_holding, call_number: 'BX4659 .E85 W44 1982', barcode: '36105001623284', library: 'SAL')]
        end
        it {
          is_expected.to match_array([
                                       hash_including('barcode' => '36105037439663', 'library' => 'GREEN', 'callnumber' => 'BX4659.E85 W44'),
                                       hash_including('barcode' => '36105001623284', 'library' => 'SAL', 'callnumber' => 'BX4659 .E85 W44 1982')
                                     ])
        }
      end

      context 'withsame build, same loc, same callnum, one in another building' do
        let(:holdings) do
          [build(:lc_holding, barcode: '36105003934432', call_number: 'PR3724.T3', library: 'SAL'),
           build(:lc_holding, barcode: '36105003934424', call_number: 'PR3724.T3', library: 'SAL'),
           build(:lc_holding, barcode: '36105048104132', call_number: '827.5 .S97TG', library: 'SAL3')]
        end

        it {
          is_expected.to match_array([
                                       hash_including('barcode' => '36105003934432', 'library' => 'SAL', 'callnumber' => 'PR3724.T3'),
                                       hash_including('barcode' => '36105003934424', 'library' => 'SAL', 'callnumber' => 'PR3724.T3'),
                                       hash_including('barcode' => '36105048104132', 'library' => 'SAL3', 'callnumber' => '827.5 .S97TG')
                                     ])
        }
      end

      context 'when location is STACKS' do
        let(:holdings) { [build(:lc_holding, permanent_location_code: 'STACKS')] }

        it { is_expected.to match_array([hash_including('permanent_location_code' => 'STACKS')]) }
      end

      context 'when location is ASK@LANE' do
        let(:holdings) { [build(:lc_holding, permanent_location_code: 'ASK@LANE')] }

        it { is_expected.to match_array([hash_including('permanent_location_code' => 'ASK@LANE')]) }
      end

      context 'when there are multiple holdings with different locations' do
        let(:holdings) { [build(:lc_holding, permanent_location_code: 'STACKS'), build(:lc_holding, permanent_location_code: 'BENDER')] }

        it { is_expected.to match_array([hash_including('permanent_location_code' => 'STACKS'), hash_including('permanent_location_code' => 'BENDER')]) }
      end

      context 'with an on order location' do
        let(:holdings) do
          [build(:lc_holding, barcode: '36105007402873', permanent_location_code: 'ON-ORDER', call_number: 'E184.S75 R47A V.1 1980'),
           build(:lc_holding)]
        end

        it {
          is_expected.to match_array([
                                       hash_including('barcode' => '36105007402873', 'library' => 'GREEN', 'permanent_location_code' => 'ON-ORDER', 'callnumber' => 'E184.S75 R47A V.1 1980'),
                                       hash_including('barcode' => 'barcode')
                                     ])
        }
      end
      context 'with an reserve location' do
        let(:holdings) do
          [build(:lc_holding, barcode: '36105046693508', permanent_location_code: 'BRAN-RESV', library: 'EARTH-SCI')]
        end

        it {
          is_expected.to match_array([
                                       hash_including('barcode' => '36105046693508', 'library' => 'EARTH-SCI', 'permanent_location_code' => 'BRAN-RESV')
                                     ])
        }
      end

      context 'with multiple items in the same library / location and with a different callnum' do
        let(:holdings) do
          [build(:lc_holding, barcode: '36105003934432', permanent_location_code: 'STACKS', call_number: 'PR3724.T3'),
           build(:lc_holding, barcode: '36105003934424', permanent_location_code: 'STACKS', call_number: 'PR3724.T3 A2 V.1'),
           build(:lc_holding, barcode: '36105048104132', permanent_location_code: 'STACKS', call_number: 'PR3724.T3 A2 V.2')]
        end

        it {
          is_expected.to match_array([
                                       hash_including('barcode' => '36105003934432', 'library' => 'GREEN', 'permanent_location_code' => 'STACKS'),
                                       hash_including('barcode' => '36105003934424', 'library' => 'GREEN', 'permanent_location_code' => 'STACKS'),
                                       hash_including('barcode' => '36105048104132', 'library' => 'GREEN', 'permanent_location_code' => 'STACKS')
                                     ])
        }
      end
    end

    context 'when holdings are checked-out' do
      let(:holdings) do
        [build(:lc_holding, status: 'Checked out', permanent_location_code: 'STACKS', barcode: '36105035087092'),
         build(:lc_holding, status: 'Checked out', permanent_location_code: 'STACKS', barcode: '36105035087093')]
      end

      it {
        is_expected.to match_array([
                                     hash_including('barcode' => '36105035087092', 'library' => 'GREEN', 'permanent_location_code' => 'STACKS', 'status' => 'Checked out'),
                                     hash_including('barcode' => '36105035087093', 'library' => 'GREEN', 'permanent_location_code' => 'STACKS', 'status' => 'Checked out')
                                   ])
      }
    end

    describe 'location implies item is shelved by title' do
      context 'with SCI-SHELBYTITLE' do
        let(:holdings) { [build(:lc_holding, call_number: 'PQ9661 .P31 C6', enumeration: 'VOL 1 1946', barcode: '36105129694373', library: 'SCIENCE', permanent_location_code: 'SCI-SHELBYTITLE', type: 'STKS-MONO')] }

        it {
          is_expected.to match_array([
                                       hash_including('barcode' => '36105129694373', 'library' => 'SCIENCE', 'permanent_location_code' => 'SCI-SHELBYTITLE',
                                                      'callnumber' => 'Shelved by title VOL 1 1946')
                                     ])
        }
      end

      context 'with SCI-SHELBYSERIES' do
        let(:holdings) { [build(:lc_holding, call_number: 'PQ9661 .P31 C6', enumeration: 'VOL 1 1946', barcode: '36105129694374', library: 'SCIENCE', permanent_location_code: 'SCI-SHELBYSERIES', type: 'STKS-MONO')] }

        it {
          is_expected.to match_array([
                                       hash_including('barcode' => '36105129694374', 'library' => 'SCIENCE', 'permanent_location_code' => 'SCI-SHELBYSERIES',
                                                      'callnumber' => 'Shelved by Series title VOL 1 1946')
                                     ])
        }
      end
    end

    describe 'holding record variations' do
      context 'with a NEWS-STKS location' do
        let(:holdings) do
          [
            build(:lc_holding, call_number: 'PQ9661 .P31 C6', enumeration: 'VOL 1 1946', barcode: '36105111222333', library: 'BUSINESS', permanent_location_code: 'BUS-NEWS-STKS')
          ]
        end

        it 'is shelved by title' do
          expect(result[field].map { |x| JSON.parse(x) }).to match_array([
                                                                           hash_including('barcode' => '36105111222333', 'library' => 'BUSINESS', 'permanent_location_code' => 'BUS-NEWS-STKS', 'callnumber' => 'Shelved by title VOL 1 1946')
                                                                         ])
        end
      end

      context 'with a NEWS-STKS location and an ALPHANUM call number' do
        let(:holdings) do
          [
            build(:alphanum_holding, call_number: 'BUS54594-11', enumeration: 'V.3 1986 MAY-AUG.', barcode: '20504037816', library: 'BUSINESS', permanent_location_code: 'BUS-NEWS-STKS')
          ]
        end

        it 'is shelved by title' do
          expect(result[field].map { |x| JSON.parse(x) }).to match_array([
                                                                           hash_including('barcode' => '20504037816', 'library' => 'BUSINESS', 'permanent_location_code' => 'BUS-NEWS-STKS', 'callnumber' => 'Shelved by title V.3 1986 MAY-AUG.')
                                                                         ])
        end
      end

      context 'volume includes an O.S. (old series) designation' do
        let(:holdings) do
          [
            build(:lc_holding, call_number: '551.46 .I55', enumeration: 'O.S:V.1 1909/1910', permanent_location_code: 'MAR-SHELBYTITLE')
          ]
        end

        it 'retains the O.S. designation before the volume number' do
          expect(result[field].map { |x| JSON.parse(x) }).to match_array([
                                                                           hash_including('callnumber' => end_with('O.S:V.1 1909/1910'))
                                                                         ])
        end
      end

      context 'volume includes an N.S. (new series) designation' do
        let(:holdings) do
          [
            build(:lc_holding, call_number: '551.46 .I55', enumeration: 'N.S:V.1 1909/1910', permanent_location_code: 'MAR-SHELBYTITLE')
          ]
        end

        it 'retains the N.S. designation before the volume number' do
          expect(result[field].map { |x| JSON.parse(x) }).to match_array([
                                                                           hash_including('callnumber' => end_with('N.S:V.1 1909/1910'))
                                                                         ])
        end
      end
    end

    context 'when location is to be left "as is"  (no translation in map, but don\'t skip)' do
      let(:holdings) do
        [build(:lc_holding, permanent_location_code: 'PERM-RES', library: 'EARTH-SCI', barcode: '36105130436541'),
         build(:lc_holding, permanent_location_code: 'REFERENCE', library: 'EARTH-SCI', barcode: '36105130436848'),
         build(:lc_holding, permanent_location_code: 'MEDIA', library: 'EARTH-SCI', barcode: '36105130437192')]
      end

      it {
        is_expected.to match_array([
                                     hash_including('barcode' => '36105130436541', 'library' => 'EARTH-SCI', 'permanent_location_code' => 'PERM-RES'),
                                     hash_including('barcode' => '36105130436848', 'library' => 'EARTH-SCI', 'permanent_location_code' => 'REFERENCE'),
                                     hash_including('barcode' => '36105130437192', 'library' => 'EARTH-SCI', 'permanent_location_code' => 'MEDIA')
                                   ])
      }
    end

    context 'with loppable call numbers' do
      let(:holdings) do
        [build(:lc_holding, call_number: 'E184.S75 R47A', enumeration: 'V.1 1980'),
         build(:lc_holding, call_number: 'E184.S75 R47A', enumeration: 'V.2 1980')]
      end

      it {
        is_expected.to match_array([
                                     hash_including('lopped_callnumber' => 'E184.S75 R47A'),
                                     hash_including('lopped_callnumber' => 'E184.S75 R47A')
                                   ])
      }
    end

    context 'when call numbers have SUPPL.' do
      let(:holdings) do
        [build(:lc_holding, call_number: 'CB3 .A6 SUPPL.', enumeration: 'V.31'),
         build(:lc_holding, call_number: 'CB3 .A6 SUPPL.', enumeration: 'V.32')]
      end

      # TODO:  suboptimal - it finds V.31, so it doesn't look for SUPPL. preceding it.
      it {
        is_expected.to match_array([
                                     hash_including('lopped_callnumber' => 'CB3 .A6 SUPPL'),
                                     hash_including('lopped_callnumber' => 'CB3 .A6 SUPPL')
                                   ])
      }
    end

    describe 'item notes' do
      context 'when the notes is title case "Public"' do
        let(:holdings) do
          [
            build(:lc_holding, notes: [{ 'note' => 'Note', 'itemNoteTypeName' => 'Public' }])
          ]
        end

        it 'is included' do
          expect(result[field].map { |x| JSON.parse(x) }.first['note']).to eq '.PUBLIC. Note'
        end
      end
    end

    describe 'full call numbers' do
      let(:holdings) do
        [
          build(:lc_holding, call_number: 'E184.S75 R47A', enumeration: 'V.1 1980'),
          build(:lc_holding, call_number: 'E184.S75 R47A', enumeration: 'V.2 1980')
        ]
      end

      it {
        is_expected.to match_array([
                                     hash_including('callnumber' => 'E184.S75 R47A V.1 1980'),
                                     hash_including('callnumber' => 'E184.S75 R47A V.2 1980')
                                   ])
      }
    end

    describe 'volsort/full shelfkey' do
      context 'LC' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.leader = '00332cas a2200085 a 4500'
            r.append(MARC::ControlField.new('008', '830415c19809999vauuu    a    0    0eng  '))
          end
        end
        let(:holdings) do
          [build(:lc_holding, call_number: 'E184.S75 R47A', enumeration: 'V.1 1980'),
           build(:lc_holding, call_number: 'E184.S75 R47A', enumeration: 'V.2 1980')]
        end
        it {
          is_expected.to match_array([
                                       hash_including('callnumber' => 'E184.S75 R47A V.1 1980',
                                                      'full_shelfkey' => 'lc e   0184.000000 s0.750000 r0.470000a 4}zzzzzy~zzyqrz~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'),
                                       hash_including('callnumber' => 'E184.S75 R47A V.2 1980',
                                                      'full_shelfkey' => 'lc e   0184.000000 s0.750000 r0.470000a 4}zzzzzx~zzyqrz~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
                                     ])
        }
      end

      context 'DEWEY' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.leader = '00332cas a2200085   4500'
            r.append(MARC::ControlField.new('008', '790219d19161918causu         0   a0eng u'))
          end
        end

        let(:holdings) do
          [build(:dewey_holding, call_number: '553.2805 .P187', enumeration: 'V.1-2 1916-1918'),
           build(:dewey_holding, call_number: '553.2805 .P187', enumeration: 'V.1-2 1919-1920')]
        end

        it {
          is_expected.to match_array([
                                       hash_including('callnumber' => '553.2805 .P187 V.1-2 1916-1918',
                                                      'full_shelfkey' => 'dewey 553.28050000 p187 4}zzzzzy~zzzzzx~zzyqyt~zzyqyr~~~~~~~~~~~~~~~~~~~~~'),
                                       hash_including('callnumber' => '553.2805 .P187 V.1-2 1919-1920',
                                                      'full_shelfkey' => 'dewey 553.28050000 p187 4}zzzzzy~zzzzzx~zzyqyq~zzyqxz~~~~~~~~~~~~~~~~~~~~~')
                                     ])
        }
      end
    end
  end

  describe 'bound_with_parent_item_ids_ssim' do
    let(:field) { 'bound_with_parent_item_ids_ssim' }

    context 'with bound with holdings' do
      let(:holdings) { [build(:lc_holding, :bound_with)] }
      it 'contains a bound_with parent' do
        expect(value).to eq ['f947bd93-a1eb-5613-8745-1063f948c461']
      end
    end
  end

  describe 'browse_nearby_struct' do
    let(:field) { 'browse_nearby_struct' }
    subject(:value) { result[field].map { |x| JSON.parse(x) } }

    describe 'shelfkey field data is the same as the field in the item_display_struct' do
      let(:fixture_name) { 'shelfkeyMatchItemDispTests.jsonl' }
      let(:browse_shelfkey) { subject.first.fetch('shelfkey') }
      let(:shelfkey) { result['shelfkey'] }

      let(:holdings) do
        [build(:alphanum_holding, call_number: 'CALIF A125 .A34', enumeration: '2002'),
         build(:alphanum_holding, call_number: 'CALIF A125 .A34', enumeration: '2003')]
      end

      it 'has the same shelfkey in the field as it does in the item_display' do
        expect(browse_shelfkey).to eq 'other calif a000125 .a000034 002002'
        expect(shelfkey).to eq ['other calif a000125 .a000034 002002']
      end
    end

    describe 'forward sort key (shelfkey)' do
      let(:holdings) do
        [build(:lc_holding, call_number: 'E184.S75 R47A', enumeration: 'V.1 1980'),
         build(:lc_holding, call_number: 'E184.S75 R47A', enumeration: 'V.2 1980')]
      end

      it {
        is_expected.to match_array([
                                     hash_including(
                                       'lopped_callnumber' => 'E184.S75 R47A',
                                       'shelfkey' => 'lc e   0184.000000 s0.750000 r0.470000a v.000001 001980'
                                     )
                                   ])
      }
    end

    describe 'reverse shelfkeys' do
      let(:holdings) do
        [build(:lc_holding, call_number: 'E184.S75 R47A', enumeration: 'V.1 1980'),
         build(:lc_holding, call_number: 'E184.S75 R47A', enumeration: 'V.2 1980')]
      end

      it {
        is_expected.to match_array([
                                     hash_including('reverse_shelfkey' => 'en~l~~~zyrv}zzzzzz~7z}suzzzz~8z}vszzzzp~4}zzzzzy~zzyqrz')
                                   ])
      }
    end

    context 'instances with an item and also a MARC 050' do
      let(:holdings) do
        [
          build(:lc_holding, call_number: 'E184.S75 R47A')
        ]
      end

      let(:record) do
        JSON.parse(File.read(file_fixture('a12451243.json'))).dig('parsedRecord', 'content')
      end

      before do
        allow(folio_record).to receive(:electronic_holdings).and_return([{}])
      end

      it 'excludes the MARC 050 data if there already is a browseable item' do
        is_expected.not_to include(hash_including('lopped_callnumber' => 'PR3562 .L385 2014'))
      end
    end

    describe 'call number type' do
      context 'ALPHANUM' do
        let(:holdings) do
          [
            build(:alphanum_holding, call_number: 'YUGOSLAV SERIAL 1973')
          ]
        end

        it 'includes the correct data' do
          expect(result[field].map { |x| JSON.parse(x) }).to match_array([
                                                                           hash_including('scheme' => end_with('ALPHANUM'))
                                                                         ])
        end
      end

      context 'DEWEY' do
        let(:holdings) do
          [
            build(:dewey_holding, call_number: '370.1 .S655')
          ]
        end

        it 'includes the correct data' do
          expect(result[field].map { |x| JSON.parse(x) }).to match_array([
                                                                           hash_including('scheme' => end_with('DEWEY'))
                                                                         ])
        end
      end

      # The Education library has a collection of call numbers w/ a scheme of DEWEY but begin w/ TX
      context 'with a DEWEY call number that begins with TX' do
        let(:holdings) do
          [
            build(:dewey_holding, call_number: 'TX 443.21 A3', permanent_location_code: 'STACKS', library: 'CUBBERLY')
          ]
        end

        # this is potentially incidental since we don't fall back for non-valid DEWEY
        it 'is handled' do
          expect(result[field].map { |x| JSON.parse(x) }).to match_array([hash_including('shelfkey' => 'dewey 443.21000000 a3')])
        end
      end

      context 'LC' do
        let(:holdings) do
          [
            build(:lc_holding, call_number: 'E184.S75 R47A', enumeration: 'V.1 1980')
          ]
        end

        it 'includes the correct data' do
          expect(result[field].map { |x| JSON.parse(x) }).to match_array([
                                                                           hash_including('scheme' => end_with('LC'))
                                                                         ])
        end
      end

      context 'Hoover Archives with call numbers starting with XX' do
        let(:holdings) do
          [
            build(:alphanum_holding, call_number: 'XX066 BOX 11', library: 'HILA')
          ]
        end

        it 'includes the correct data' do
          expect(result[field].map { |x| JSON.parse(x) }).to match_array([
                                                                           hash_including('scheme' => end_with('ALPHANUM'))
                                                                         ])
        end
      end
    end
  end
end
