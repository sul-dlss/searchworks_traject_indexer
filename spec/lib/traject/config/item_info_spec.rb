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
    let(:fixture_name) { 'locationTests.jsonl' }

    let(:field) { 'barcode_search' }

    it 'has data' do
      # Single barcode
      result = select_by_id('115472')[field]
      expect(result).to eq ['36105033811451']
      # many barcodes
      result = select_by_id('1033119')[field]
      expect(result).to eq %w[36105037439663 36105001623284]
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

  describe 'item_display' do
    let(:field) { 'item_display' }

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

      it { expect(result[field]).to match_array([match('-|- GREEN -|-'), match('-|- ART -|-')]) }
      it { expect(result['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([hash_including('library' => 'GREEN'), hash_including('library' => 'ART')]) }
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
        expect(result['item_display_struct']).to be_nil
      end
    end
    describe 'field is populated correctly, focusing on building/library' do
      let(:fixture_name) { 'buildingTests.jsonl' }

      it 'APPLIEDPHY ignored for building facet, but not here' do
        expect(select_by_id('115472')[field].length).to eq 1
        expect(select_by_id('115472')[field].first).to include('-|- APPLIEDPHY -|-')
        expect(select_by_id('115472')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                         hash_including('barcode' => '36105033811451', 'library' => 'APPLIEDPHY')
                                                                                                       ])
      end

      it 'inlcudes various libraries' do
        sample_libs_and_ids = {
          ART: '345228',
          CLASSICS: '1147269',
          ENG: '1849258',
          'GOV-DOCS': '2099904',
          GREEN: '1261173',
          HOOVER: '3743949',
          SAL3: '690002',
          SCIENCE: '460947',
          'SPEC-COLL': '4258089'
        }

        sample_libs_and_ids.each do |library, id|
          expect(select_by_id(id)[field].length).to be >= 1
          expect(select_by_id(id)[field]).to be_any do |field|
            field.include?("-|- #{library} -|-")
          end
          expect(select_by_id(id)['item_display_struct'].map { |x| JSON.parse(x) }).to be_any do |field|
            field['library'] == library.to_s
          end
        end
      end

      it 'handles multiple items in single record, diff buildings' do
        expect(select_by_id('1033119')[field].length).to eq 2

        expect(select_by_id('1033119')[field].first).to match(
          /^36105037439663 -\|- GREEN -\|- .*BX4659\.E85 W44/
        )

        expect(select_by_id('1033119')[field].last).to match(
          /^36105001623284 -\|- SAL -\|- .*BX4659 \.E85 W44 1982/
        )

        expect(select_by_id('1033119')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                          hash_including('barcode' => '36105037439663', 'library' => 'GREEN', 'callnumber' => 'BX4659.E85 W44'),
                                                                                                          hash_including('barcode' => '36105001623284', 'library' => 'SAL', 'callnumber' => 'BX4659 .E85 W44 1982')
                                                                                                        ])
      end

      it 'handles same build, same loc, same callnum, one in another building' do
        expect(select_by_id('2328381')[field].length).to eq 3

        expect(select_by_id('2328381')[field][0]).to match(
          /^36105003934432 -\|- SAL -\|- .*PR3724\.T3/
        )
        expect(select_by_id('2328381')[field][1]).to match(
          /^36105003934424 -\|- SAL -\|- .*PR3724\.T3/
        )

        expect(select_by_id('2328381')[field][2]).to match(
          /^36105048104132 -\|- SAL3 -\|- .*827\.5 \.S97TG/
        )

        expect(select_by_id('2328381')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                          hash_including('barcode' => '36105003934432', 'library' => 'SAL', 'callnumber' => 'PR3724.T3'),
                                                                                                          hash_including('barcode' => '36105003934424', 'library' => 'SAL', 'callnumber' => 'PR3724.T3'),
                                                                                                          hash_including('barcode' => '36105048104132', 'library' => 'SAL3', 'callnumber' => '827.5 .S97TG')
                                                                                                        ])
      end

      describe 'with item display fixture' do
        let(:fixture_name) { 'itemDisplayTests.jsonl' }

        it 'handles materials in LANE' do
          expect(select_by_id('6661112')[field].length).to eq 1
          expect(select_by_id('6661112')[field].first).to match(
            /^36105082101390 -\|- LANE-MED -\|- .*Z3871\.Z8 V\.22 1945/
          )
          expect(select_by_id('6661112')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                            hash_including('barcode' => '36105082101390', 'library' => 'LANE-MED', 'callnumber' => 'Z3871.Z8 V.22 1945')
                                                                                                          ])
        end

        it 'handles mult items same build, diff loc' do
          expect(select_by_id('2328381')[field].length).to eq 3

          expect(select_by_id('2328381')[field][0]).to match(
            /^36105003934432 -\|- GREEN -\|- .*PR3724\.T3/
          )
          expect(select_by_id('2328381')[field][1]).to match(
            /^36105003934424 -\|- GREEN -\|- .*PR3724\.T3/
          )

          expect(select_by_id('2328381')[field][2]).to match(
            /^36105048104132 -\|- GRN-REF -\|- .*827\.5 \.S97TG/
          )

          expect(select_by_id('2328381')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                            hash_including('barcode' => '36105003934432', 'library' => 'GREEN', 'callnumber' => 'PR3724.T3'),
                                                                                                            hash_including('barcode' => '36105003934424', 'library' => 'GREEN', 'callnumber' => 'PR3724.T3 A2'),
                                                                                                            hash_including('barcode' => '36105048104132', 'library' => 'GRN-REF', 'callnumber' => '827.5 .S97TG')
                                                                                                          ])
        end
      end

      describe 'field is populated correctly, focusing on locations' do
        it 'includes valious locations' do
          sample_ids_and_locs = {
            '229800': %w[STACKS],
            '3941911': %w[STACKS BENDER],
            '6676531': %w[JAPANESE],
            '1261173': %w[MEDIA-MTXT],
            '7233951': %w[ASK@LANE],
            '1962398': %w[SAL-PAGE],
            '2913114': %w[SAL-PAGE],
            '7651581': %w[INPROCESS],
            '2557826': %w[FED-DOCS]
          }

          sample_ids_and_locs.each do |id, locations|
            data = select_by_id(id.to_s)[field]
            expect(data.length).to be >= 1
            locations.each do |location|
              expect(data).to be_any do |field|
                field.include?("-|- #{location} -|-")
              end
            end
            expect(select_by_id(id.to_s)['item_display_struct'].map { |x| JSON.parse(x) }).to be_any do |field|
              locations.include?(field['home_location'])
            end
          end
        end

        it 'handles one withdrawn location, one valid properly' do
          data = select_by_id('2214009')[field]
          # 36105033336798 is WITHDRAWN and should not be returned
          expect(data.length).to eq 1
          expect(data.first).to match(/^36105033336780 -\|- SAL3 -\|- STACKS/)
        end

        context 'with a different fixture' do
          let(:fixture_name) { 'itemDisplayTests.jsonl' }

          it 'handles on order locations' do
            data = select_by_id('460947')[field]
            expect(data.length).to eq 2
            expect(data.first).to match(
              /^36105007402873 -\|- GREEN -\|- ON-ORDER .* E184\.S75 R47A V\.1 1980/
            )
            expect(select_by_id('460947')['item_display_struct'].map { |x| JSON.parse(x) }.first).to include(
              'barcode' => '36105007402873', 'library' => 'GREEN', 'home_location' => 'ON-ORDER', 'callnumber' => 'E184.S75 R47A V.1 1980'
            )
          end

          it 'handles reserve locations' do
            expect(select_by_id('690002')[field].length).to eq 1
            expect(select_by_id('690002')[field].first).to match(
              /^36105046693508 -\|- EARTH-SCI -\|- BRAN-RESV/
            )

            expect(select_by_id('690002')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                             hash_including('barcode' => '36105046693508', 'library' => 'EARTH-SCI', 'home_location' => 'BRAN-RESV')
                                                                                                           ])
          end

          it 'handles mult items same build, diff loc' do
            expect(select_by_id('2328381')[field].length).to eq 3
            expect(select_by_id('2328381')[field][0]).to match(
              /^36105003934432 -\|- GREEN -\|- STACKS/
            )

            expect(select_by_id('2328381')[field][1]).to match(
              /^36105003934424 -\|- GREEN -\|- BINDERY/
            )

            expect(select_by_id('2328381')[field][2]).to match(
              /^36105048104132 -\|- GRN-REF -\|- STACKS/
            )

            expect(select_by_id('2328381')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                              hash_including('barcode' => '36105003934432', 'library' => 'GREEN', 'home_location' => 'STACKS'),
                                                                                                              hash_including('barcode' => '36105003934424', 'library' => 'GREEN', 'home_location' => 'BINDERY'),
                                                                                                              hash_including('barcode' => '36105048104132', 'library' => 'GRN-REF', 'home_location' => 'STACKS')
                                                                                                            ])
          end

          it 'hanldes multiple items for single bib with same library / location, diff callnum' do
            expect(select_by_id('666')[field].length).to eq 3
            expect(select_by_id('666')[field][0]).to match(
              /^36105003934432 -\|- GREEN -\|- STACKS/
            )

            expect(select_by_id('666')[field][1]).to match(
              /^36105003934424 -\|- GREEN -\|- STACKS/
            )

            expect(select_by_id('666')[field][2]).to match(
              /^36105048104132 -\|- GREEN -\|- STACKS/
            )

            expect(select_by_id('666')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                          hash_including('barcode' => '36105003934432', 'library' => 'GREEN', 'home_location' => 'STACKS'),
                                                                                                          hash_including('barcode' => '36105003934424', 'library' => 'GREEN', 'home_location' => 'STACKS'),
                                                                                                          hash_including('barcode' => '36105048104132', 'library' => 'GREEN', 'home_location' => 'STACKS')
                                                                                                        ])
          end
        end
      end
    end

    describe 'displays home location' do
      let(:fixture_name) { 'buildingTests.jsonl' }

      it 'CHECKEDOUT as current location, STACKS as home location' do
        expect(select_by_id('575946')[field].length).to eq 2
        expect(select_by_id('575946')[field].first).to match(
          /^36105035087092 -\|- GREEN -\|- STACKS -\|- CHECKEDOUT -/
        )

        expect(select_by_id('575946')[field].last).to match(
          /^36105035087093 -\|- GREEN -\|- STACKS -\|- CHECKEDOUT -/
        )

        expect(select_by_id('575946')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                         hash_including('barcode' => '36105035087092', 'library' => 'GREEN', 'home_location' => 'STACKS', 'current_location' => 'CHECKEDOUT'),
                                                                                                         hash_including('barcode' => '36105035087093', 'library' => 'GREEN', 'home_location' => 'STACKS', 'current_location' => 'CHECKEDOUT')
                                                                                                       ])
      end

      it 'WITHDRAWN as current location implies item is skipped' do
        expect(select_by_id('3277173')[field]).to be_nil
        expect(select_by_id('3277173')['item_display_struct']).to be_nil
      end
    end

    describe 'location implies item is shelved by title' do
      let(:fixture_name) { 'callNumberLCSortTests.jsonl' }

      it 'handles SHELBYTITL' do
        expect(select_by_id('1111')[field].length).to eq 1
        expect(select_by_id('1111')[field].first).to match(
          /^36105129694373 -\|- SCIENCE -\|- SHELBYTITL .* Shelved by title VOL 1 1946/
        )
        expect(select_by_id('1111')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                       hash_including('barcode' => '36105129694373', 'library' => 'SCIENCE', 'home_location' => 'SHELBYTITL',
                                                                                                                      'callnumber' => 'Shelved by title VOL 1 1946')
                                                                                                     ])
      end

      it 'handles SHELBYSER' do
        expect(select_by_id('2211')[field].length).to eq 1
        expect(select_by_id('2211')[field].first).to match(
          /^36105129694374 -\|- SCIENCE -\|- SHELBYSER .* Shelved by Series title VOL 1 1946/
        )
        expect(select_by_id('2211')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                       hash_including('barcode' => '36105129694374', 'library' => 'SCIENCE', 'home_location' => 'SHELBYSER',
                                                                                                                      'callnumber' => 'Shelved by Series title VOL 1 1946')
                                                                                                     ])
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
          expect(result[field].first.split(' -|- ')).to contain_exactly(
            '36105111222333',
            'BUSINESS',
            'NEWS-STKS',
            '',
            '',
            'Shelved by title',
            'shelved by title',
            /~~~/,
            'Shelved by title VOL 1 1946',
            /shelved by title/,
            '',
            'LC'
          )
          expect(result['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
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
          expect(result[field].first.split(' -|- ')).to contain_exactly(
            '20504037816',
            'BUSINESS',
            'NEWS-STKS',
            '',
            '',
            'Shelved by title',
            'shelved by title',
            /~~~/,
            'Shelved by title V.3 1986 MAY-AUG.',
            /shelved by title/,
            '',
            'ALPHANUM'
          )
          expect(result['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
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
          expect(result[field].first.split(' -|- ')).to contain_exactly(
            '36105444555666',
            'GREEN',
            'NEWS-STKS',
            '',
            '',
            'E184.S75 R47A V.1 1980',
            /^lc/,
            /~~~/,
            'E184.S75 R47A V.1 1980',
            /^lc/,
            '',
            'LC'
          )
          expect(result['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
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
          expect(result[field].first.split(' -|- ')[8]).to include('O.S:V.1 1909/1910')
          expect(result['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
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
          expect(result[field].first.split(' -|- ')[8]).to include('N.S:V.1 1909/1910')
          expect(result['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
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
        expect(select_by_id('575946')['item_display_struct']).to be_nil
        expect(select_by_id('1033119')['item_display_struct']).to be_nil

        # INPROCESS - keep it
        expect(select_by_id('7651581')[field].length).to eq 1
        expect(select_by_id('7651581')[field].first).to match(
          /^36105129694373 -\|- SAL3 -\|- INPROCESS/
        )
        expect(select_by_id('7651581')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                          hash_including('barcode' => '36105129694373', 'library' => 'SAL3', 'home_location' => 'INPROCESS')
                                                                                                        ])
      end
    end

    describe 'when location is to be left "as is"  (no translation in map, but don\'t skip)' do
      let(:fixture_name) { 'mediaLocTests.jsonl' }

      it 'has the correct data' do
        expect(select_by_id('7652182')[field].length).to eq 3
        expect(select_by_id('7652182')[field][0]).to match(
          /^36105130436541 -\|- EARTH-SCI -\|- PERM-RES/
        )
        expect(select_by_id('7652182')[field][1]).to match(
          /^36105130436848 -\|- EARTH-SCI -\|- REFERENCE/
        )
        expect(select_by_id('7652182')[field][2]).to match(
          /^36105130437192 -\|- EARTH-SCI -\|- MEDIA/
        )
        expect(select_by_id('7652182')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                          hash_including('barcode' => '36105130436541', 'library' => 'EARTH-SCI', 'home_location' => 'PERM-RES'),
                                                                                                          hash_including('barcode' => '36105130436848', 'library' => 'EARTH-SCI', 'home_location' => 'REFERENCE'),
                                                                                                          hash_including('barcode' => '36105130437192', 'library' => 'EARTH-SCI', 'home_location' => 'MEDIA')
                                                                                                        ])
      end
    end

    # rubocop:disable Layout/LineLength
    describe 'lopped call numbers' do
      let(:fixture_name) { 'itemDisplayTests.jsonl' }

      it 'has the right data' do
        item_display = select_by_id('460947000')[field]
        expect(item_display).to eq [
          '36105007402873 -|- SCIENCE -|- STACKS -|-  -|- STKS-MONO -|- E184.S75 R47A ... -|- lc e   0184.000000 s0.750000 r0.470000a ... -|- en~l~~~zyrv}zzzzzz~7z}suzzzz~8z}vszzzzp~}}}~~~~~~~ -|- E184.S75 R47A V.1 1980 -|- lc e   0184.000000 s0.750000 r0.470000a 4}zzzzzy~zzyqrz~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ -|-  -|- LC',
          '36105007402874 -|- SCIENCE -|- STACKS -|-  -|- STKS-MONO -|- E184.S75 R47A ... -|- lc e   0184.000000 s0.750000 r0.470000a ... -|- en~l~~~zyrv}zzzzzz~7z}suzzzz~8z}vszzzzp~}}}~~~~~~~ -|- E184.S75 R47A V.2 1980 -|- lc e   0184.000000 s0.750000 r0.470000a 4}zzzzzx~zzyqrz~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ -|-  -|- LC'
        ]

        expect(select_by_id('460947000')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                            hash_including('lopped_callnumber' => 'E184.S75 R47A ...'),
                                                                                                            hash_including('lopped_callnumber' => 'E184.S75 R47A ...')
                                                                                                          ])

        # TODO:  suboptimal - it finds V.31, so it doesn't look for SUPPL. preceding it.
        item_display = select_by_id('575946')[field]
        expect(item_display).to eq [
          '36105035087092 -|- GREEN -|- STACKS -|- CHECKEDOUT -|- STKS-MONO -|- CB3 .A6 SUPPL. ... -|- lc cb  0003.000000 a0.600000 suppl. ... -|- en~no~~zzzw}zzzzzz~pz}tzzzzz~75aae}~}}}~~~~~~~~~~~ -|- CB3 .A6 SUPPL. V.31 -|- lc cb  0003.000000 a0.600000 suppl. v.000031 -|-  -|- LC',
          '36105035087093 -|- GREEN -|- STACKS -|- CHECKEDOUT -|- STKS-MONO -|- CB3 .A6 SUPPL. ... -|- lc cb  0003.000000 a0.600000 suppl. ... -|- en~no~~zzzw}zzzzzz~pz}tzzzzz~75aae}~}}}~~~~~~~~~~~ -|- CB3 .A6 SUPPL. V.32 -|- lc cb  0003.000000 a0.600000 suppl. v.000032 -|-  -|- LC'
        ]
        expect(select_by_id('575946')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                         hash_including('lopped_callnumber' => 'CB3 .A6 SUPPL. ...'),
                                                                                                         hash_including('lopped_callnumber' => 'CB3 .A6 SUPPL. ...')
                                                                                                       ])

        item_display = select_by_id('690002000')[field]
        expect(item_display).to eq [
          '36105046693508 -|- SAL3 -|- STACKS -|-  -|- STKS-MONO -|- 159.32 .W211 -|- dewey 159.32000000 w211 -|- ml3l1~yuq}wxzzzzzz~3xyy~~~~~~~~~~~~~~~~~~~~~~~~~~~ -|- 159.32 .W211 -|- dewey 159.32000000 w211 -|-  -|- DEWEY'
        ]
        expect(select_by_id('690002000')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                            hash_including('lopped_callnumber' => '159.32 .W211')
                                                                                                          ])

        item_display = select_by_id('2557826')[field]
        expect(item_display).to eq [
          '001AMR5851 -|- GREEN -|- FED-DOCS -|-  -|- GOVSTKS -|- E 1.28:COO-4274-1 -|- sudoc e 000001.000028:coo-004274-000001 -|- 75mbn~l~zzzzzy}zzzzxr~nbb~zzvxsv~zzzzzy~~~~~~~~~~~ -|- E 1.28:COO-4274-1 -|- sudoc e 000001.000028:coo-004274-000001 -|-  -|- SUDOC'
        ]
        expect(select_by_id('2557826')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                          hash_including('lopped_callnumber' => 'E 1.28:COO-4274-1')
                                                                                                        ])

        item_display = select_by_id('460947')[field]
        expect(item_display).to eq [
          '36105007402873 -|- GREEN -|- ON-ORDER -|-  -|- STKS-MONO -|- E184.S75 R47A ... -|- lc e   0184.000000 s0.750000 r0.470000a ... -|- en~l~~~zyrv}zzzzzz~7z}suzzzz~8z}vszzzzp~}}}~~~~~~~ -|- E184.S75 R47A V.1 1980 -|- lc e   0184.000000 s0.750000 r0.470000a 4}zzzzzy~zzyqrz~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ -|-  -|- LC',
          '36105007402872 -|- GREEN -|- ON-ORDER -|-  -|- STKS-MONO -|- E184.S75 R47A ... -|- lc e   0184.000000 s0.750000 r0.470000a ... -|- en~l~~~zyrv}zzzzzz~7z}suzzzz~8z}vszzzzp~}}}~~~~~~~ -|- E184.S75 R47A V.2 1980 -|- lc e   0184.000000 s0.750000 r0.470000a 4}zzzzzx~zzyqrz~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ -|-  -|- LC'
        ]
        expect(select_by_id('460947')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                         hash_including('lopped_callnumber' => 'E184.S75 R47A ...'),
                                                                                                         hash_including('lopped_callnumber' => 'E184.S75 R47A ...')
                                                                                                       ])

        item_display = select_by_id('446688')[field]
        expect(item_display).to eq [
          '36105007402873 -|- GREEN -|- STACKS -|-  -|- STKS-MONO -|- 666.27 .F22 -|- dewey 666.27000000 f22 -|- ml3l1~ttt}xszzzzzz~kxx~~~~~~~~~~~~~~~~~~~~~~~~~~~~ -|- 666.27 .F22 -|- dewey 666.27000000 f22 -|-  -|- DEWEY'
        ]
        expect(select_by_id('446688')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                         hash_including('lopped_callnumber' => '666.27 .F22')
                                                                                                       ])

        item_display = select_by_id('4578538')[field]
        expect(item_display).to eq [
          '36105046377987 -|- SAL3 -|- STACKS -|-  -|- STKS-MONO -|- SUSEL-69048 -|- other susel-069048 -|- b6il8~757le~ztqzvr~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ -|- SUSEL-69048 -|- other susel-069048 -|-  -|- ALPHANUM'
        ]
        expect(select_by_id('4578538')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                          hash_including('lopped_callnumber' => 'SUSEL-69048')
                                                                                                        ])

        item_display = select_by_id('1261173')[field]
        expect(item_display).to eq [
          '001AFX2969 -|- GREEN -|- MEDIA-MTXT -|-  -|- NH-MICR -|- MFILM N.S. 1350 REEL 230 NO. 3741 -|- other mfilm n.s. 001350 reel 000230 no. 003741 -|- b6il8~dkhed~c}7}~zzywuz~8lle~zzzxwz~cb}~zzwsvy~~~~ -|- MFILM N.S. 1350 REEL 230 NO. 3741 -|- other mfilm n.s. 001350 reel 000230 no. 003741 -|-  -|- ALPHANUM'
        ]
        expect(select_by_id('1261173')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                          hash_including('lopped_callnumber' => 'MFILM N.S. 1350 REEL 230 NO. 3741')
                                                                                                        ])

        item_display = select_by_id('1234673')[field]
        expect(item_display).to eq [
          '001AFX2969 -|- GREEN -|- MEDIA-MTXT -|-  -|- NH-MICR -|- MCD Brendel Plays Beethoven\'s Eroica variations -|- other mcd brendel plays beethoven\'s eroica variations -|- b6il8~dnm~o8lcmle~aep17~oll6ib4lc~7~l8bhnp~4p8hp6hbc7 -|- MCD Brendel Plays Beethoven\'s Eroica variations -|- other mcd brendel plays beethoven\'s eroica variations -|-  -|- ALPHANUM'
        ]
        expect(select_by_id('1234673')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                          hash_including('lopped_callnumber' => 'MCD Brendel Plays Beethoven\'s Eroica variations')
                                                                                                        ])

        item_display = select_by_id('3941911')[field]
        expect(item_display).to eq [
          '36105025373064 -|- GREEN -|- BENDER -|-  -|- NONCIRC -|- PS3557 .O5829 K3 1998 -|- lc ps  3557.000000 o0.582900 k0.300000 001998 -|- en~a7~~wuus}zzzzzz~bz}urxqzz~fz}wzzzzz~zzyqqr~~~~~ -|- PS3557 .O5829 K3 1998 -|- lc ps  3557.000000 o0.582900 k0.300000 001998 -|-  -|- LC',
          '36105019748495 -|- GREEN -|- BENDER -|-  -|- STKS-MONO -|- PS3557 .O5829 K3 1998 -|- lc ps  3557.000000 o0.582900 k0.300000 001998 -|- en~a7~~wuus}zzzzzz~bz}urxqzz~fz}wzzzzz~zzyqqr~~~~~ -|- PS3557 .O5829 K3 1998 -|- lc ps  3557.000000 o0.582900 k0.300000 001998 -|-  -|- LC'
        ]
        expect(select_by_id('3941911')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                          hash_including('lopped_callnumber' => 'PS3557 .O5829 K3 1998'),
                                                                                                          hash_including('lopped_callnumber' => 'PS3557 .O5829 K3 1998')
                                                                                                        ])

        item_display = select_by_id('111')[field]
        expect(item_display).to eq [
          '36105003934432 -|- GREEN -|- STACKS -|-  -|- STKS-MONO -|- PR3724.T3 A2 ... -|- lc pr  3724.000000 t0.300000 a0.200000 ... -|- en~a8~~wsxv}zzzzzz~6z}wzzzzz~pz}xzzzzz~}}}~~~~~~~~ -|- PR3724.T3 A2 V.12 -|- lc pr  3724.000000 t0.300000 a0.200000 v.000012 -|-  -|- LC',
          '36105003934424 -|- GREEN -|- STACKS -|-  -|- STKS-MONO -|- PR3724.T3 A2 ... -|- lc pr  3724.000000 t0.300000 a0.200000 ... -|- en~a8~~wsxv}zzzzzz~6z}wzzzzz~pz}xzzzzz~}}}~~~~~~~~ -|- PR3724.T3 A2 V.1 -|- lc pr  3724.000000 t0.300000 a0.200000 v.000001 -|-  -|- LC',
          '36105048104132 -|- GREEN -|- STACKS -|-  -|- STKS-MONO -|- PR3724.T3 A2 ... -|- lc pr  3724.000000 t0.300000 a0.200000 ... -|- en~a8~~wsxv}zzzzzz~6z}wzzzzz~pz}xzzzzz~}}}~~~~~~~~ -|- PR3724.T3 A2 V.2 -|- lc pr  3724.000000 t0.300000 a0.200000 v.000002 -|-  -|- LC'
        ]
        expect(select_by_id('111')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                      hash_including('lopped_callnumber' => 'PR3724.T3 A2 ...'),
                                                                                                      hash_including('lopped_callnumber' => 'PR3724.T3 A2 ...'),
                                                                                                      hash_including('lopped_callnumber' => 'PR3724.T3 A2 ...')
                                                                                                    ])

        item_display = select_by_id('222')[field]
        expect(item_display).to eq [
          '36105003934432 -|- GREEN -|- STACKS -|-  -|- STKS-MONO -|- PR3724.T3 V2 -|- lc pr  3724.000000 t0.300000 v0.200000 -|- en~a8~~wsxv}zzzzzz~6z}wzzzzz~4z}xzzzzz~~~~~~~~~~~~ -|- PR3724.T3 V2 -|- lc pr  3724.000000 t0.300000 v0.200000 -|-  -|- LC',
          '36105003934424 -|- SAL -|- STACKS -|-  -|- STKS-MONO -|- PR3724.T3 V2 -|- lc pr  3724.000000 t0.300000 v0.200000 -|- en~a8~~wsxv}zzzzzz~6z}wzzzzz~4z}xzzzzz~~~~~~~~~~~~ -|- PR3724.T3 V2 -|- lc pr  3724.000000 t0.300000 v0.200000 -|-  -|- LC'
        ]
        expect(select_by_id('222')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                      hash_including('lopped_callnumber' => 'PR3724.T3 V2'),
                                                                                                      hash_including('lopped_callnumber' => 'PR3724.T3 V2')
                                                                                                    ])

        item_display = select_by_id('4823592')[field]
        expect(item_display).to eq [
          '36105063104488 -|- LAW -|- BASEMENT -|-  -|- LAW-STKS -|- Y 4.G 74/7:G 21/10 -|- other y 000004.g 000074/000007:g 000021/000010 -|- b6il8~1~zzzzzv}j~zzzzsv~zzzzzs~j~zzzzxy~zzzzyz~~~~ -|- Y 4.G 74/7:G 21/10 -|- other y 000004.g 000074/000007:g 000021/000010 -|-  -|- OTHER'
        ]
        expect(select_by_id('4823592')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                                          hash_including('lopped_callnumber' => 'Y 4.G 74/7:G 21/10')
                                                                                                        ])
      end
    end
    # rubocop:enable Layout/LineLength

    describe 'forward sort key (shelfkey)' do
      let(:fixture_name) { 'buildingTests.jsonl' }

      it 'has the shelfkey for the lopped call number' do
        item_display = select_by_id('460947')[field].first.split('-|-').map(&:strip)
        expect(item_display).to eq [
          '36105007402873', 'SCIENCE', 'STACKS', '', 'STKS-MONO',
          'E184.S75 R47A ...', 'lc e   0184.000000 s0.750000 r0.470000a ...',
          'en~l~~~zyrv}zzzzzz~7z}suzzzz~8z}vszzzzp~}}}~~~~~~~', 'E184.S75 R47A V.1 1980',
          'lc e   0184.000000 s0.750000 r0.470000a 4}zzzzzy~zzyqrz~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~',
          '', 'LC'
        ]
        expect(select_by_id('460947')['item_display_struct'].map { |x| JSON.parse(x) }.first).to include(
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
          expect(result[field].length).to eq 1
          expect(result[field].first).to include('-|- .PUBLIC. Note -|-')
          expect(result['item_display_struct'].map { |x| JSON.parse(x) }.first['note']).to eq '.PUBLIC. Note'
        end
      end

      context 'when the public note is lower case ".public."' do
        let(:holdings) do
          [
            build(:lc_holding, call_number: 'AB123.45 .M67', public_note: '.public. Note')
          ]
        end

        it 'is included' do
          expect(result[field].length).to eq 1
          expect(result[field].first).to include('-|- .public. Note -|-')
          expect(result['item_display_struct'].map { |x| JSON.parse(x) }.first['note']).to eq '.public. Note'
        end
      end

      context 'when the public note is mixed case' do
        let(:holdings) do
          [
            build(:lc_holding, call_number: 'AB123.45 .M67', public_note: '.PuBlIc. Note')
          ]
        end

        it 'is included' do
          expect(result[field].length).to eq 1
          expect(result[field].first).to include('-|- .PuBlIc. Note -|-')
          expect(result['item_display_struct'].map { |x| JSON.parse(x) }.first['note']).to eq '.PuBlIc. Note'
        end
      end
    end

    describe 'reverse shelfkeys' do
      let(:fixture_name) { 'buildingTests.jsonl' }

      it 'has the reversed shelfkey for the lopped call number' do
        item_display = select_by_id('460947')[field].first.split('-|-').map(&:strip)
        expect(item_display).to eq [
          '36105007402873', 'SCIENCE', 'STACKS', '', 'STKS-MONO',
          'E184.S75 R47A ...', 'lc e   0184.000000 s0.750000 r0.470000a ...', 'en~l~~~zyrv}zzzzzz~7z}suzzzz~8z}vszzzzp~}}}~~~~~~~',
          'E184.S75 R47A V.1 1980', 'lc e   0184.000000 s0.750000 r0.470000a 4}zzzzzy~zzyqrz~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~', '', 'LC'
        ]
        expect(select_by_id('460947')['item_display_struct'].map { |x| JSON.parse(x) }.first).to include(
          'barcode' => '36105007402873', 'library' => 'SCIENCE', 'home_location' => 'STACKS', 'type' => 'STKS-MONO',
          'lopped_callnumber' => 'E184.S75 R47A ...', 'shelfkey' => 'lc e   0184.000000 s0.750000 r0.470000a ...', 'reverse_shelfkey' => 'en~l~~~zyrv}zzzzzz~7z}suzzzz~8z}vszzzzp~}}}~~~~~~~',
          'callnumber' => 'E184.S75 R47A V.1 1980', 'full_shelfkey' => 'lc e   0184.000000 s0.750000 r0.470000a 4}zzzzzy~zzyqrz~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~', 'scheme' => 'LC'
        )
      end
    end

    describe 'full call numbers' do
      let(:fixture_name) { 'buildingTests.jsonl' }

      it 'are populated' do
        expect(select_by_id('460947')[field].length).to eq 2
        expect(select_by_id('460947')[field].first).to include('-|- E184.S75 R47A V.1 1980 -|-')
        expect(select_by_id('460947')[field].last).to include('-|- E184.S75 R47A V.2 1980 -|-')

        expect(select_by_id('460947')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
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
          expect(result[field].first).to end_with('-|- ALPHANUM')
          expect(result['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
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
          expect(result[field].first).to end_with('-|- DEWEY')
          expect(result['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
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
          expect(result[field].first).to end_with('-|- LC')
          expect(result['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
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
          expect(result[field].first).to end_with('-|- SUDOC')
          expect(result['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
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
          expect(result[field].first).to end_with('-|- OTHER')
          expect(result['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
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
          expect(result[field].first).to end_with('-|- OTHER')
          expect(result['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
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
          expect(result[field].first).to end_with('-|- ALPHANUM')
          expect(result['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
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
          expect(result[field].first).to end_with('-|- OTHER')
          expect(result['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
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
          expect(result[field].first).to end_with('-|- OTHER')
          expect(result['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                           hash_including('scheme' => end_with('OTHER'))
                                                                                         ])
        end
      end
    end

    describe 'volsort/full shelfkey' do
      context 'LC' do
        let(:fixture_name) { 'buildingTests.jsonl' }

        it 'is included' do
          expect(select_by_id('460947')[field].length).to eq 2
          expect(select_by_id('460947')[field].first).to include(
            '-|- E184.S75 R47A V.1 1980 -|-'
          )

          # Note that the previous shelfkey had "r0.470000 a" instead of "r0.470000a"
          expect(select_by_id('460947')[field].first).to include(
            '-|- lc e   0184.000000 s0.750000 r0.470000a 4}zzzzzy~zzyqrz~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ -|-'
          )

          expect(select_by_id('460947')[field].last).to include(
            '-|- E184.S75 R47A V.2 1980 -|-'
          )
          expect(select_by_id('460947')[field].last).to include(
            '-|- lc e   0184.000000 s0.750000 r0.470000a 4}zzzzzx~zzyqrz~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ -|-'
          )

          expect(select_by_id('460947')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
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
          expect(select_by_id('373245')[field].length).to eq 2
          expect(select_by_id('373245')[field].first).to include(
            '-|- 553.2805 .P187 V.1-2 1916-1918 -|-'
          )
          expect(select_by_id('373245')[field].first).to include(
            '-|- dewey 553.28050000 p187 4}zzzzzy~zzzzzx~zzyqyt~zzyqyr~~~~~~~~~~~~~~~~~~~~~ -|-'
          )

          expect(select_by_id('373245')[field].last).to include(
            '-|- 553.2805 .P187 V.1-2 1919-1920 -|-'
          )
          expect(select_by_id('373245')[field].last).to include(
            '-|- dewey 553.28050000 p187 4}zzzzzy~zzzzzx~zzyqyq~zzyqxz~~~~~~~~~~~~~~~~~~~~~ -|-'
          )

          expect(select_by_id('373245')['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
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
          it 'are handled' do
            expect(result['item_display'].first).to include('-|- dewey 443.21000000 a3 -|-')
            expect(result['item_display_struct'].map { |x| JSON.parse(x) }).to match_array([
                                                                                             hash_including('shelfkey' => 'dewey 443.21000000 a3')
                                                                                           ])
          end
        end
      end
    end

    describe 'shefkey field data is the same as the field in the item_display' do
      let(:fixture_name) { 'shelfkeyMatchItemDispTests.jsonl' }

      it 'has the same shelfkey in the field as it does in the item_display' do
        item_display = select_by_id('5788269')[field].first.split('-|-').map(&:strip)
        expect(item_display).to eq [
          '36105122888543', 'GREEN', 'CALIF-DOCS', '', 'GOVSTKS', 'CALIF A125 .A34 ...', 'other calif a000125 .a000034 ...',
          'b6il8~npehk~pzzzyxu~}pzzzzwv~~~~~~~~~~~~~~~~~~~~~~', 'CALIF A125 .A34 2002', 'other calif a000125 .a000034 002002', '', 'ALPHANUM'
        ]
        expect(select_by_id('5788269')['shelfkey']).to eq ['other calif a000125 .a000034 ...']

        item_display = select_by_id('409752')[field].first.split('-|-').map(&:strip)
        expect(item_display).to eq [
          '409752-2001', 'GREEN', 'CALIF-DOCS', '', 'GOVSTKS', 'CALIF A125 .B9 ...', 'other calif a000125 .b000009 ...',
          'b6il8~npehk~pzzzyxu~}ozzzzzq~~~~~~~~~~~~~~~~~~~~~~', 'CALIF A125 .B9', 'other calif a000125 .b000009', '', 'ALPHANUM'
        ]
        expect(select_by_id('409752')['shelfkey']).to eq ['other calif a000125 .b000009 ...']

        item_display = select_by_id('373245')[field].first.split('-|-').map(&:strip)
        expect(item_display).to eq [
          '36105027549075', 'SAL3', 'STACKS', '', 'STKS-PERI',
          '553.2805 .P187 ...', 'dewey 553.28050000 p187 ...', 'ml3l1~uuw}xrzuzzzz~ayrs~}}}~~~~~~~~~~~~~~~~~~~~~~~',
          '553.2805 .P187 V.1-2 1916-1918', 'dewey 553.28050000 p187 4}zzzzzy~zzzzzx~zzyqyt~zzyqyr~~~~~~~~~~~~~~~~~~~~~', '', 'DEWEY'
        ]
        expect(select_by_id('373245')['shelfkey']).to eq ['dewey 553.28050000 p187 ...']

        item_display = select_by_id('373759')[field].first.split('-|-').map(&:strip)
        expect(item_display).to eq [
          '36105027313985', 'SAL3', 'STACKS', '', 'STKS-PERI', '553.2805 .P494 ...', 'dewey 553.28050000 p494 ...',
          'ml3l1~uuw}xrzuzzzz~avqv~}}}~~~~~~~~~~~~~~~~~~~~~~~', '553.2805 .P494 V.11 1924:JAN.-JUNE',
          'dewey 553.28050000 p494 4}zzzzyy~zzyqxv~gpc}~g5cl~~~~~~~~~~~~~~~~~~~~~~~~~', '', 'DEWEY'
        ]
        expect(select_by_id('373759')['shelfkey']).to eq ['dewey 553.28050000 p494 ...']
      end
    end
  end
end
