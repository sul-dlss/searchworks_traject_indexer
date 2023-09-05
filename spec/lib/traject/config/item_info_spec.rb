# frozen_string_literal: true

RSpec.describe 'ItemInfo config' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:records) { MARC::JSONLReader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }
  let(:folio_records) { records.map { |rec| marc_to_folio_with_stubbed_holdings(rec) } }
  let(:folio_record) { marc_to_folio(record) }
  let(:results) { folio_records.map { |rec| indexer.map_record(rec) }.to_a }
  subject(:result) { indexer.map_record(folio_record) }

  describe 'barcode_search' do
    let(:field) { 'barcode_search' }
    let(:record) { MARC::Record.new }
    subject { result[field] }

    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(holdings)
    end

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
    let(:record) { MARC::Record.new }
    subject { result[field] }
    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(holdings)
    end

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

    context 'with HOPKINS' do
      let(:holdings) { [build(:lc_holding, library: 'HOPKINS')] }

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

    context 'with MEDIA-MTXT' do
      let(:holdings) { [build(:lc_holding, library: 'MEDIA-MTXT')] }

      it { is_expected.to eq ['Media Center'] }
    end

    context 'with RUMSEYMAP' do
      let(:holdings) { [build(:lc_holding, library: 'RUMSEYMAP')] }

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

    context 'with HOOVER' do
      let(:holdings) { [build(:lc_holding, library: 'HOOVER')] }

      it { is_expected.to eq ['Hoover Institution Library & Archives'] }
    end

    context 'with multiple holdings' do
      let(:holdings) { [build(:lc_holding, library: 'GREEN'), build(:lc_holding, library: 'SAL')] }

      it { is_expected.to eq ['Green', 'SAL1&2 (on-campus storage)'] }
    end
  end

  describe 'building_location_facet_ssim' do
    let(:field) { 'building_location_facet_ssim' }
    let(:record) { MARC::Record.new }
    subject { result[field] }

    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(holdings)
    end

    context 'with ARS/STACKS' do
      let(:holdings) { [build(:lc_holding, library: 'ARS', home_location: 'STACKS', type: 'STKS-MONO')] }

      it { is_expected.to include 'ARS/STACKS', 'ARS/STACKS/type/STKS-MONO', 'ARS/*/type/STKS-MONO' }
    end

    context 'with GREEN/STACKS' do
      let(:holdings) { [build(:lc_holding, library: 'GREEN', home_location: 'STACKS', type: 'STKS-MONO')] }

      it { is_expected.to include 'GREEN/STACKS', 'GREEN/STACKS/type/STKS-MONO', 'GREEN/*/type/STKS-MONO' }
    end
  end

  describe 'item_display_struct' do
    let(:field) { 'item_display_struct' }
    subject(:value) { result[field].map { |x| JSON.parse(x) } }

    context 'when an item is on-order' do
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

      it 'omits the on-order placeholder' do
        expect(result[field]).to be_nil
      end
    end

    describe 'field is populated correctly, focusing on building/library' do
      let(:record) { MARC::Record.new }

      before do
        allow(folio_record).to receive(:sirsi_holdings).and_return(holdings)
      end

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

      context 'when library is HOOVER' do
        let(:holdings) { [build(:lc_holding, library: 'HOOVER')] }

        it { is_expected.to match_array([hash_including('library' => 'HOOVER')]) }
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

      context 'when library is LANE-MED' do
        let(:holdings) { [build(:lc_holding, barcode: '36105082101390', call_number: 'Z3871.Z8 V.22 1945', library: 'LANE-MED')] }

        it { is_expected.to match_array([hash_including('barcode' => '36105082101390', 'library' => 'LANE-MED', 'callnumber' => 'Z3871.Z8 V.22 1945')]) }
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
        let(:holdings) { [build(:lc_holding, home_location: 'STACKS')] }

        it { is_expected.to match_array([hash_including('home_location' => 'STACKS')]) }
      end

      context 'when location is ASK@LANE' do
        let(:holdings) { [build(:lc_holding, home_location: 'ASK@LANE')] }

        it { is_expected.to match_array([hash_including('home_location' => 'ASK@LANE')]) }
      end

      context 'when there are multiple holdings with different locations' do
        let(:holdings) { [build(:lc_holding, home_location: 'STACKS'), build(:lc_holding, home_location: 'BENDER')] }

        it { is_expected.to match_array([hash_including('home_location' => 'STACKS'), hash_including('home_location' => 'BENDER')]) }
      end

      context 'with an on order location' do
        let(:holdings) do
          [build(:lc_holding, barcode: '36105007402873', home_location: 'ON-ORDER', call_number: 'E184.S75 R47A V.1 1980'),
           build(:lc_holding)]
        end

        it {
          is_expected.to match_array([
                                       hash_including('barcode' => '36105007402873', 'library' => 'GREEN', 'home_location' => 'ON-ORDER', 'callnumber' => 'E184.S75 R47A V.1 1980'),
                                       hash_including('barcode' => 'barcode')
                                     ])
        }
      end
      context 'with an reserve location' do
        let(:holdings) do
          [build(:lc_holding, barcode: '36105046693508', home_location: 'BRAN-RESV', library: 'EARTH-SCI')]
        end

        it {
          is_expected.to match_array([
                                       hash_including('barcode' => '36105046693508', 'library' => 'EARTH-SCI', 'home_location' => 'BRAN-RESV')
                                     ])
        }
      end

      context 'with multiple items in the same library / location and with a different callnum' do
        let(:holdings) do
          [build(:lc_holding, barcode: '36105003934432', home_location: 'STACKS', call_number: 'PR3724.T3'),
           build(:lc_holding, barcode: '36105003934424', home_location: 'STACKS', call_number: 'PR3724.T3 A2 V.1'),
           build(:lc_holding, barcode: '36105048104132', home_location: 'STACKS', call_number: 'PR3724.T3 A2 V.2')]
        end

        it {
          is_expected.to match_array([
                                       hash_including('barcode' => '36105003934432', 'library' => 'GREEN', 'home_location' => 'STACKS'),
                                       hash_including('barcode' => '36105003934424', 'library' => 'GREEN', 'home_location' => 'STACKS'),
                                       hash_including('barcode' => '36105048104132', 'library' => 'GREEN', 'home_location' => 'STACKS')
                                     ])
        }
      end
    end

    describe 'displays home location' do
      let(:fixture_name) { 'buildingTests.jsonl' }

      it 'CHECKEDOUT as current location, STACKS as home location' do
        expect(select_by_id('575946')[field].map { |x| JSON.parse(x) }).to match_array([
                                                                                         hash_including('barcode' => '36105035087092', 'library' => 'GREEN', 'home_location' => 'STACKS', 'current_location' => 'CHECKEDOUT'),
                                                                                         hash_including('barcode' => '36105035087093', 'library' => 'GREEN', 'home_location' => 'STACKS', 'current_location' => 'CHECKEDOUT')
                                                                                       ])
      end

      it 'WITHDRAWN as current location implies item is skipped' do
        expect(select_by_id('3277173')[field]).to be_nil
      end
    end

    describe 'location implies item is shelved by title' do
      let(:record) { MARC::Record.new }
      subject { result[field] }

      before do
        allow(folio_record).to receive(:sirsi_holdings).and_return(holdings)
      end

      context 'with SHELBYTITL' do
        let(:holdings) { [build(:lc_holding, call_number: 'PQ9661 .P31 C6 VOL 1 1946', barcode: '36105129694373', library: 'SCIENCE', home_location: 'SHELBYTITL', type: 'STKS-MONO')] }
        let(:field) { 'item_display_struct' }
        subject { result[field].map { |x| JSON.parse(x) } }
        it {
          is_expected.to match_array([
                                       hash_including('barcode' => '36105129694373', 'library' => 'SCIENCE', 'home_location' => 'SHELBYTITL',
                                                      'callnumber' => 'Shelved by title VOL 1 1946')
                                     ])
        }
      end

      context 'with SHELBYSER' do
        let(:holdings) { [build(:lc_holding, call_number: 'PQ9661 .P31 C6 VOL 1 1946', barcode: '36105129694374', library: 'SCIENCE', home_location: 'SHELBYSER', type: 'STKS-MONO')] }

        let(:field) { 'item_display_struct' }
        subject { result[field].map { |x| JSON.parse(x) } }
        it {
          is_expected.to match_array([
                                       hash_including('barcode' => '36105129694374', 'library' => 'SCIENCE', 'home_location' => 'SHELBYSER',
                                                      'callnumber' => 'Shelved by Series title VOL 1 1946')
                                     ])
        }
      end
    end

    describe 'holding record variations' do
      before do
        allow(folio_record).to receive(:sirsi_holdings).and_return(holdings)
      end

      let(:record) { MARC::Record.new }

      context 'with a NEWS-STKS location' do
        let(:holdings) do
          [
            build(:lc_holding, call_number: 'PQ9661 .P31 C6 VOL 1 1946', barcode: '36105111222333', library: 'BUSINESS', home_location: 'NEWS-STKS')
          ]
        end

        it 'is shelved by title' do
          expect(result[field].map { |x| JSON.parse(x) }).to match_array([
                                                                           hash_including('barcode' => '36105111222333', 'library' => 'BUSINESS', 'home_location' => 'NEWS-STKS', 'callnumber' => 'Shelved by title VOL 1 1946',
                                                                                          'scheme' => 'LC')
                                                                         ])
        end
      end

      context 'with a NEWS-STKS location and an ALPHANUM call number' do
        let(:holdings) do
          [
            build(:alphanum_holding, call_number: 'BUS54594-11 V.3 1986 MAY-AUG.', barcode: '20504037816', library: 'BUSINESS', home_location: 'NEWS-STKS')
          ]
        end

        it 'is shelved by title' do
          expect(result[field].map { |x| JSON.parse(x) }).to match_array([
                                                                           hash_including('barcode' => '20504037816', 'library' => 'BUSINESS', 'home_location' => 'NEWS-STKS', 'callnumber' => 'Shelved by title V.3 1986 MAY-AUG.',
                                                                                          'scheme' => 'ALPHANUM')
                                                                         ])
        end
      end

      context 'with a NEWS-STKS location when it is not in BUSINESS' do
        let(:holdings) do
          [
            build(:lc_holding, call_number: 'E184.S75 R47A V.1 1980', barcode: '36105444555666', home_location: 'NEWS-STKS')
          ]
        end

        it 'does nothing special ' do
          expect(result[field].map { |x| JSON.parse(x) }).to match_array([
                                                                           hash_including('barcode' => '36105444555666', 'library' => 'GREEN', 'home_location' => 'NEWS-STKS', 'callnumber' => 'E184.S75 R47A V.1 1980', 'scheme' => 'LC')
                                                                         ])
        end
      end

      context 'volume includes an O.S. (old series) designation' do
        let(:holdings) do
          [
            build(:lc_holding, call_number: '551.46 .I55 O.S:V.1 1909/1910', home_location: 'SHELBYTITL')
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
            build(:lc_holding, call_number: '551.46 .I55 N.S:V.1 1909/1910', home_location: 'SHELBYTITL')
          ]
        end

        it 'retains the N.S. designation before the volume number' do
          expect(result[field].map { |x| JSON.parse(x) }).to match_array([
                                                                           hash_including('callnumber' => end_with('N.S:V.1 1909/1910'))
                                                                         ])
        end
      end
    end

    describe 'locations are not displayed' do
      let(:fixture_name) { 'locationTests.jsonl' }

      it 'do not return an item_display' do
        expect(select_by_id('575946')[field]).to be_nil
        expect(select_by_id('1033119')[field]).to be_nil

        # INPROCESS - keep it
        expect(select_by_id('7651581')[field].map { |x| JSON.parse(x) }).to match_array([
                                                                                          hash_including('barcode' => '36105129694373', 'library' => 'SAL3', 'home_location' => 'INPROCESS')
                                                                                        ])
      end
    end

    describe 'when location is to be left "as is"  (no translation in map, but don\'t skip)' do
      let(:fixture_name) { 'mediaLocTests.jsonl' }

      it 'has the correct data' do
        expect(select_by_id('7652182')[field].map { |x| JSON.parse(x) }).to match_array([
                                                                                          hash_including('barcode' => '36105130436541', 'library' => 'EARTH-SCI', 'home_location' => 'PERM-RES'),
                                                                                          hash_including('barcode' => '36105130436848', 'library' => 'EARTH-SCI', 'home_location' => 'REFERENCE'),
                                                                                          hash_including('barcode' => '36105130437192', 'library' => 'EARTH-SCI', 'home_location' => 'MEDIA')
                                                                                        ])
      end
    end

    describe 'lopped call numbers' do
      let(:fixture_name) { 'itemDisplayTests.jsonl' }

      it 'has the right data' do
        expect(select_by_id('460947000')[field].map { |x| JSON.parse(x) }).to match_array([
                                                                                            hash_including('lopped_callnumber' => 'E184.S75 R47A ...'),
                                                                                            hash_including('lopped_callnumber' => 'E184.S75 R47A ...')
                                                                                          ])

        # TODO:  suboptimal - it finds V.31, so it doesn't look for SUPPL. preceding it.
        expect(select_by_id('575946')[field].map { |x| JSON.parse(x) }).to match_array([
                                                                                         hash_including('lopped_callnumber' => 'CB3 .A6 SUPPL. ...'),
                                                                                         hash_including('lopped_callnumber' => 'CB3 .A6 SUPPL. ...')
                                                                                       ])

        expect(select_by_id('690002000')[field].map { |x| JSON.parse(x) }).to match_array([
                                                                                            hash_including('lopped_callnumber' => '159.32 .W211')
                                                                                          ])

        expect(select_by_id('2557826')[field].map { |x| JSON.parse(x) }).to match_array([
                                                                                          hash_including('lopped_callnumber' => 'E 1.28:COO-4274-1')
                                                                                        ])

        expect(select_by_id('460947')[field].map { |x| JSON.parse(x) }).to match_array([
                                                                                         hash_including('lopped_callnumber' => 'E184.S75 R47A ...'),
                                                                                         hash_including('lopped_callnumber' => 'E184.S75 R47A ...')
                                                                                       ])

        expect(select_by_id('446688')[field].map { |x| JSON.parse(x) }).to match_array([
                                                                                         hash_including('lopped_callnumber' => '666.27 .F22')
                                                                                       ])

        expect(select_by_id('4578538')[field].map { |x| JSON.parse(x) }).to match_array([
                                                                                          hash_including('lopped_callnumber' => 'SUSEL-69048')
                                                                                        ])

        expect(select_by_id('1261173')[field].map { |x| JSON.parse(x) }).to match_array([
                                                                                          hash_including('lopped_callnumber' => 'MFILM N.S. 1350 REEL 230 NO. 3741')
                                                                                        ])

        expect(select_by_id('1234673')[field].map { |x| JSON.parse(x) }).to match_array([
                                                                                          hash_including('lopped_callnumber' => 'MCD Brendel Plays Beethoven\'s Eroica variations')
                                                                                        ])

        expect(select_by_id('3941911')[field].map { |x| JSON.parse(x) }).to match_array([
                                                                                          hash_including('lopped_callnumber' => 'PS3557 .O5829 K3 1998'),
                                                                                          hash_including('lopped_callnumber' => 'PS3557 .O5829 K3 1998')
                                                                                        ])

        expect(select_by_id('111')[field].map { |x| JSON.parse(x) }).to match_array([
                                                                                      hash_including('lopped_callnumber' => 'PR3724.T3 A2 ...'),
                                                                                      hash_including('lopped_callnumber' => 'PR3724.T3 A2 ...'),
                                                                                      hash_including('lopped_callnumber' => 'PR3724.T3 A2 ...')
                                                                                    ])

        expect(select_by_id('222')[field].map { |x| JSON.parse(x) }).to match_array([
                                                                                      hash_including('lopped_callnumber' => 'PR3724.T3 V2'),
                                                                                      hash_including('lopped_callnumber' => 'PR3724.T3 V2')
                                                                                    ])

        expect(select_by_id('4823592')[field].map { |x| JSON.parse(x) }).to match_array([
                                                                                          hash_including('lopped_callnumber' => 'Y 4.G 74/7:G 21/10')
                                                                                        ])
      end
    end
    describe 'forward sort key (shelfkey)' do
      let(:fixture_name) { 'buildingTests.jsonl' }

      it 'has the shelfkey for the lopped call number' do
        expect(select_by_id('460947')[field].map { |x| JSON.parse(x) }.first).to include(
          'shelfkey' => 'lc e   0184.000000 s0.750000 r0.470000a ...'
        )
      end
    end

    describe 'public note' do
      before do
        allow(folio_record).to receive(:sirsi_holdings).and_return(holdings)
      end

      let(:record) { MARC::Record.new }

      context 'when the public note is upper case ".PUBLIC."' do
        let(:holdings) do
          [
            build(:lc_holding, call_number: 'AB123.45 .M67', public_note: '.PUBLIC. Note')
          ]
        end

        it 'is included' do
          expect(result[field].map { |x| JSON.parse(x) }.first['note']).to eq '.PUBLIC. Note'
        end
      end

      context 'when the public note is lower case ".public."' do
        let(:holdings) do
          [
            build(:lc_holding, call_number: 'AB123.45 .M67', public_note: '.public. Note')
          ]
        end

        it 'is included' do
          expect(result[field].map { |x| JSON.parse(x) }.first['note']).to eq '.public. Note'
        end
      end

      context 'when the public note is mixed case' do
        let(:holdings) do
          [
            build(:lc_holding, call_number: 'AB123.45 .M67', public_note: '.PuBlIc. Note')
          ]
        end

        it 'is included' do
          expect(result[field].map { |x| JSON.parse(x) }.first['note']).to eq '.PuBlIc. Note'
        end
      end
    end

    describe 'reverse shelfkeys' do
      let(:fixture_name) { 'buildingTests.jsonl' }

      it 'has the reversed shelfkey for the lopped call number' do
        expect(select_by_id('460947')[field].map { |x| JSON.parse(x) }.first).to include(
          'barcode' => '36105007402873', 'library' => 'SCIENCE', 'home_location' => 'STACKS', 'type' => 'STKS-MONO',
          'lopped_callnumber' => 'E184.S75 R47A ...', 'shelfkey' => 'lc e   0184.000000 s0.750000 r0.470000a ...', 'reverse_shelfkey' => 'en~l~~~zyrv}zzzzzz~7z}suzzzz~8z}vszzzzp~}}}~~~~~~~',
          'callnumber' => 'E184.S75 R47A V.1 1980', 'full_shelfkey' => 'lc e   0184.000000 s0.750000 r0.470000a 4}zzzzzy~zzyqrz~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~', 'scheme' => 'LC'
        )
      end
    end

    describe 'full call numbers' do
      let(:fixture_name) { 'buildingTests.jsonl' }

      it 'are populated' do
        expect(select_by_id('460947')[field].map { |x| JSON.parse(x) }).to match_array([
                                                                                         hash_including('callnumber' => 'E184.S75 R47A V.1 1980'),
                                                                                         hash_including('callnumber' => 'E184.S75 R47A V.2 1980')
                                                                                       ])
      end
    end

    describe 'call number type' do
      before do
        allow(folio_record).to receive(:sirsi_holdings).and_return(holdings)
      end

      let(:record) { MARC::Record.new }
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

      context 'LC' do
        let(:holdings) do
          [
            build(:lc_holding, call_number: 'E184.S75 R47A V.1 1980')
          ]
        end

        it 'includes the correct data' do
          expect(result[field].map { |x| JSON.parse(x) }).to match_array([
                                                                           hash_including('scheme' => end_with('LC'))
                                                                         ])
        end
      end

      context 'SUDOC' do
        let(:holdings) do
          [
            build(:sudoc_holding, call_number: 'E 1.28:COO-4274-1')
          ]
        end

        it 'includes the correct data' do
          expect(result[field].map { |x| JSON.parse(x) }).to match_array([
                                                                           hash_including('scheme' => end_with('SUDOC'))
                                                                         ])
        end
      end

      context 'OTHER' do
        let(:holdings) do
          [
            build(:other_holding, call_number: '71 15446')
          ]
        end

        it 'includes the correct data' do
          expect(result[field].map { |x| JSON.parse(x) }).to match_array([
                                                                           hash_including('scheme' => end_with('OTHER'))
                                                                         ])
        end
      end

      context 'XX' do
        let(:holdings) do
          [
            build(:holding, scheme: 'XX', call_number: 'XX(3195846.2579)')
          ]
        end

        it 'includes the correct data' do
          expect(result[field].map { |x| JSON.parse(x) }).to match_array([
                                                                           hash_including('scheme' => end_with('OTHER'))
                                                                         ])
        end
      end

      context 'Hoover Archives with call numbers starting with XX' do
        let(:holdings) do
          [
            build(:alphanum_holding, call_number: 'XX066 BOX 11', library: 'HV-ARCHIVE')
          ]
        end

        it 'includes the correct data' do
          expect(result[field].map { |x| JSON.parse(x) }).to match_array([
                                                                           hash_including('scheme' => end_with('ALPHANUM'))
                                                                         ])
        end
      end

      context 'when the call number is "INTERNET RESOURCE"' do
        let(:holdings) do
          [
            build(:other_holding, :internet_holding)
          ]
        end

        it 'includes the correct data' do
          expect(result[field].map { |x| JSON.parse(x) }).to match_array([
                                                                           hash_including('scheme' => end_with('OTHER'))
                                                                         ])
        end
      end

      context 'with an callnumber "X X"' do
        let(:holdings) do
          [
            build(:other_holding, call_number: 'X X')
          ]
        end

        it 'includes the correct data' do
          expect(result[field].map { |x| JSON.parse(x) }).to match_array([
                                                                           hash_including('scheme' => end_with('OTHER'))
                                                                         ])
        end
      end
    end

    describe 'volsort/full shelfkey' do
      context 'LC' do
        let(:fixture_name) { 'buildingTests.jsonl' }

        it 'is included' do
          # Note that the previous shelfkey had "r0.470000 a" instead of "r0.470000a"
          expect(select_by_id('460947')[field].map { |x| JSON.parse(x) }).to match_array([
                                                                                           hash_including('callnumber' => 'E184.S75 R47A V.1 1980',
                                                                                                          'full_shelfkey' => 'lc e   0184.000000 s0.750000 r0.470000a 4}zzzzzy~zzyqrz~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'),
                                                                                           hash_including('callnumber' => 'E184.S75 R47A V.2 1980',
                                                                                                          'full_shelfkey' => 'lc e   0184.000000 s0.750000 r0.470000a 4}zzzzzx~zzyqrz~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
                                                                                         ])
        end
      end

      context 'DEWEY' do
        let(:fixture_name) { 'shelfkeyMatchItemDispTests.jsonl' }

        it 'is included' do
          expect(select_by_id('373245')[field].map { |x| JSON.parse(x) }).to match_array([
                                                                                           hash_including('callnumber' => '553.2805 .P187 V.1-2 1916-1918',
                                                                                                          'full_shelfkey' => 'dewey 553.28050000 p187 4}zzzzzy~zzzzzx~zzyqyt~zzyqyr~~~~~~~~~~~~~~~~~~~~~'),
                                                                                           hash_including('callnumber' => '553.2805 .P187 V.1-2 1919-1920',
                                                                                                          'full_shelfkey' => 'dewey 553.28050000 p187 4}zzzzzy~zzzzzx~zzyqyq~zzyqxz~~~~~~~~~~~~~~~~~~~~~')
                                                                                         ])
        end

        # The Education library has a collection of call numbers w/ a scheme of DEWEY but begin w/ TX
        context 'with a DEWEY call number that begins with TX' do
          let(:holdings) do
            [
              build(:dewey_holding, call_number: 'TX 443.21 A3', home_location: 'STACKS', library: 'CUBBERLY')
            ]
          end

          before do
            allow(folio_record).to receive(:sirsi_holdings).and_return(holdings)
          end

          # this is potentially incidental since we don't fall back for non-valid DEWEY
          it 'is handled' do
            expect(result[field].map { |x| JSON.parse(x) }).to match_array([
                                                                             hash_including('shelfkey' => 'dewey 443.21000000 a3')
                                                                           ])
          end
        end
      end
    end

    describe 'shefkey field data is the same as the field in the item_display_struct' do
      let(:fixture_name) { 'shelfkeyMatchItemDispTests.jsonl' }

      it 'has the same shelfkey in the field as it does in the item_display' do
        item_display_key = JSON.parse(select_by_id('5788269')[field].first).fetch('shelfkey')
        expect(item_display_key).to eq 'other calif a000125 .a000034 ...'
        expect(select_by_id('5788269')['shelfkey']).to eq ['other calif a000125 .a000034 ...']

        item_display_key = JSON.parse(select_by_id('409752')[field].first).fetch('shelfkey')
        expect(item_display_key).to eq 'other calif a000125 .b000009 ...'
        expect(select_by_id('409752')['shelfkey']).to eq ['other calif a000125 .b000009 ...']

        item_display_key = JSON.parse(select_by_id('373245')[field].first).fetch('shelfkey')
        expect(item_display_key).to eq 'dewey 553.28050000 p187 ...'
        expect(select_by_id('373245')['shelfkey']).to eq ['dewey 553.28050000 p187 ...']

        item_display_key = JSON.parse(select_by_id('373759')[field].first).fetch('shelfkey')
        expect(item_display_key).to eq 'dewey 553.28050000 p494 ...'
        expect(select_by_id('373759')['shelfkey']).to eq ['dewey 553.28050000 p494 ...']
      end
    end
  end
end
