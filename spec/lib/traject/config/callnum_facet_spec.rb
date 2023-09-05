# frozen_string_literal: true

require 'sirsi_holding'

# rubocop:disable Metrics/ParameterLists
def record_with_holdings(call_number:, scheme:, indexer:, home_location: 'STACKS', library: 'GREEN', type: '')
  holdings = [
    build(:holding,
          call_number:,
          home_location:,
          library:,
          scheme:,
          type:,
          barcode: '')
  ]
  yield(holdings) if block_given?
  allow(folio_record).to receive(:sirsi_holdings).and_return(holdings)
  indexer.map_record(folio_record)
end
# rubocop:enable Metrics/ParameterLists

RSpec.describe 'Call Number Facet' do
  let(:result) { indexer.map_record(folio_record) }
  let(:field) { 'callnum_facet_hsim' }
  subject(:value) { result[field] }

  let(:folio_record) do
    FolioRecord.new({
                      'source_record' => source_record,
                      'instance' => {}
                    }, stub_folio_client)
  end

  let(:source_record) do
    [{ 'leader' => '          22        4500', 'fields' => [] }]
  end

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end
  let(:holdings) { [] }

  before do
    allow(folio_record).to receive(:sirsi_holdings).and_return(holdings)
  end

  describe 'call numbers excluded for various reasons' do
    context 'with a skipped location' do
      let(:holdings) { [build(:lc_holding, home_location: 'SHADOW', library: 'ART')] }

      it { is_expected.to be_nil }
    end

    it 'assigns value for valid LC even if it is a shelve by location' do
      SirsiHolding::SHELBY_LOCS.each do |loc|
        # valid LC
        # FIXME: we DO want a value if there is valid LC for shelby location
        # expect(record_with_holdings(call_number: 'M123 .M456', scheme: 'LC', home_location: loc, indexer: indexer)[field]).to eq(
        #   ['LC Classification|M - Music|M - Music']
        # )
        # LC
        expect(record_with_holdings(call_number: 'M123 .M456', home_location: loc, scheme: 'LC',
                                    indexer:)[field]).to be_nil
        # Dewey
        expect(record_with_holdings(call_number: '123.4 .B45', home_location: loc, scheme: 'DEWEY',
                                    indexer:)[field]).to be_nil
      end
    end

    it 'handles missing or lost call numbers (by not including them)' do
      SirsiHolding::LOST_OR_MISSING_LOCS.each do |loc|
        # LC
        expect(record_with_holdings(call_number: 'M123 .M456', home_location: loc, scheme: 'LC',
                                    indexer:)[field]).to be_nil
        # Dewey
        expect(record_with_holdings(call_number: '123.4 .B45', home_location: loc, scheme: 'DEWEY',
                                    indexer:)[field]).to be_nil
      end
    end

    it 'handles ignored call numbers (by not including them)' do
      # LC
      expect(record_with_holdings(call_number: 'INTERNET RESOURCE stuff', scheme: 'LC', indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: 'XX stuff', scheme: 'LC', indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: 'NO CALL NUMBER', scheme: 'LC', indexer:)[field]).to be_nil

      # Dewey
      expect(record_with_holdings(call_number: 'INTERNET RESOURCE stuff', scheme: 'DEWEY',
                                  indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: 'XX stuff', scheme: 'DEWEY', indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: 'NO CALL NUMBER', scheme: 'DEWEY', indexer:)[field]).to be_nil
    end

    it 'handles empty call numbers (by not returning them)' do
      # LC
      expect(record_with_holdings(call_number: nil, scheme: 'LC', indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: '', scheme: 'LC', indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: ' ', scheme: 'LC', indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: '. . ', scheme: 'LC', indexer:)[field]).to be_nil

      # Dewey
      expect(record_with_holdings(call_number: nil, scheme: 'DEWEY', indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: '', scheme: 'DEWEY', indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: ' ', scheme: 'DEWEY', indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: '. . ', scheme: 'DEWEY', indexer:)[field]).to be_nil
    end

    it 'does not return call nubmers typed as Alphanum, and clearly not LC or Dewey' do
      expect(record_with_holdings(call_number: '71 15446 V.1', scheme: 'ALPHANUM', indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: '4488.301 0300 2001 CD-ROM', scheme: 'ALPHANUM',
                                  indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: '8291.209 .A963 V.5 1971/1972', scheme: 'ALPHANUM',
                                  indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: '"NEW BEGINNING" INVESTMENT RESERVE FUND', scheme: 'ALPHANUM',
                                  indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: '"21" BRANDS, INCORPORATED', scheme: 'ALPHANUM',
                                  indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: ' "LA CONSOLIDADA", S.A', scheme: 'ALPHANUM',
                                  indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: '(THE) NWNL COMPANIES, INC.', scheme: 'ALPHANUM',
                                  indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: 'ISHII SPRING 2009', scheme: 'ALPHANUM', indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: 'OYER WINTER 2012', scheme: 'ALPHANUM', indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: "O'REILLY FALL 2006", scheme: 'ALPHANUM', indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: 'XV 852', scheme: 'ALPHANUM', indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: 'YUGOSLAV SERIAL 1963 NO.5-6', scheme: 'ALPHANUM',
                                  indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: 'SUSEL-69048', scheme: 'ALPHANUM', indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: 'MFICHE 3239', scheme: 'ALPHANUM', indexer:)[field]).to be_nil
    end

    it 'does not return call numbers w/ the scheme ASIS' do
      expect(record_with_holdings(call_number: '(ADL4044.1)XX', scheme: 'ASIS', indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: '134776', scheme: 'ASIS', indexer:)[field]).to be_nil
      expect(record_with_holdings(call_number: 'INTERNET RESOURCE', scheme: 'ASIS', indexer:)[field]).to be_nil
    end
  end

  describe 'LC Call Numbers' do
    let(:holdings) { [build(:lc_holding, call_number:)] }

    context 'with one letter call number' do
      context 'with D call' do
        let(:call_number) { 'D764.7 .K72 1990' }
        it { is_expected.to eq ['LC Classification|D - History (General)|D - History (General)'] }
      end

      context 'with F call' do
        let(:call_number) { 'F1356 .M464 2005' }
        it { is_expected.to eq ['LC Classification|F - United States, British, Dutch, French, Latin America (Local History)|F - United States, British, Dutch, French, Latin America (Local History)'] }
      end

      context 'with M call' do
        let(:call_number) { ' M2 .C17 L3 2005' }
        it { is_expected.to eq ['LC Classification|M - Music|M - Music'] }
      end

      context 'with U call' do
        let(:call_number) { 'U897 .C87 Z55 2001' }
        it { is_expected.to eq ['LC Classification|U - Military Science (General)|U - Military Science (General)'] }
      end

      context 'with Z call' do
        let(:call_number) { 'Z3871.Z8' }
        it { is_expected.to eq ['LC Classification|Z - Bibliography, Library Science, Information Resources|Z - Bibliography, Library Science, Information Resources'] }
      end
    end

    context 'with two letter call number' do
      context 'with QE call' do
        let(:call_number) { 'QE538.8 .N36 1975-1977' }
        it { is_expected.to eq ['LC Classification|Q - Science (General)|QE - Geology'] }
      end

      context 'with BX call' do
        let(:call_number) { 'BX4659 .E85 W44' }
        it { is_expected.to eq ['LC Classification|B - Philosophy, Psychology, Religion|BX - Christian Denominations'] }
      end

      context 'with HG call' do
        let(:call_number) { 'HG6046 .V28 1986' }
        it { is_expected.to eq ['LC Classification|H - Social Sciences (General)|HG - Finance'] }
      end
    end

    context 'with three letter call number' do
      context 'with KKX call' do # 6830340
        let(:call_number) { 'KKX500 .S98 2005' }
        it { is_expected.to eq ['LC Classification|K - Law|KKX - Law of Turkey'] }
      end

      context 'with KJV call' do
        let(:call_number) { 'KJV4189 .A67 A15 2014' }
        it { is_expected.to eq ['LC Classification|K - Law|KJV - Law of France'] }
      end
    end

    context 'with a classification that is not available in the map' do
      let(:call_number) { 'KFC1050 .C35 2014' }
      it { is_expected.to eq ['LC Classification|K - Law|KFC - Law of California, Colorado, Connecticut'] }
    end

    context 'with multiple holding records with the same LC class' do
      let(:holdings) do
        [
          build(:lc_holding, call_number: 'ML171 .L38 2005'),
          build(:lc_holding, call_number: 'M2 .C17 L3 2005')
        ]
      end

      it {
        is_expected.to match_array [
          'LC Classification|M - Music|M - Music',
          'LC Classification|M - Music|ML - Literature on Music'
        ]
      }
    end

    context 'with multiple holding records with the different LC classes' do
      let(:holdings) do
        [
          build(:lc_holding, call_number: 'ML171 .L38 2005'),
          build(:lc_holding, call_number: 'QE538.8 .N36 1975-1977')
        ]
      end

      it {
        is_expected.to eq [
          'LC Classification|M - Music|ML - Literature on Music',
          'LC Classification|Q - Science (General)|QE - Geology'
        ]
      }
    end

    context 'with Lane LC call numbers' do
      let(:call_number) { 'Q603 .H47 1960' }

      it { is_expected.to eq ['LC Classification|Q - Science (General)|Q - Science (General)'] }
    end
  end

  describe 'invalid LC call numbers' do
    bad_callnumbers =
      [
        'QE538.8 .NB36 1975-1977', # bad Cutter
        '(V) JN6695 .I28 1999 COPY', # paren start char
        '???',
        # weird callnums
        '158613F868 .C45 N37 2000',
        '5115126059 A17 2004',
        '70 03126',
        # starting with illegal letters
        'INTERNET RESOURCE KF3400 .S36 2009',
        'INTERNET RESOURCE GALE EZPROXY',
        # should be govdoc
        'ICAO DOC 4444/15TH ED',
        'ORNL-6371',
        'X X',
        'XM98-1 NO.1',
        'XX(6661112.1)',
        'YBP1834690',
        # alphanum but have scheme listed as LC (by not including them)
        '1ST AMERICAN BANCORP, INC.',
        '2 B SYSTEM INC.',
        '202 DATA SYSTEMS, INC.',
        # unusual Lane (med school) call numbers
        '1.1',
        '20.44',
        '4.15[C]',
        # Harvard Yenching call numbers
        '6.4C-CZ[BC]',
        '2345 5861 V.3',
        '4362 .S12P2 1965 .C3',
        # weird in process call numbers
        '001AQJ5818',
        # EDI in process
        '427331959',
        # Japanese
        '7926635',
        '7890569-1001',
        '7885324-1001-2',
        # Rare
        '741.5 F',
        '(ADL4044.1)XX',
        # math-cs tech-reports  (home Loc TECH-RPTS)
        '134776',
        '262198'
      ]
    bad_callnumbers.each do |call_number|
      context "when call number is #{call_number}" do
        let(:holdings) { [build(:lc_holding, call_number:)] }

        it { is_expected.to be_nil }
      end
    end
  end

  describe 'dewey call numbers' do
    let(:holdings) { [build(:dewey_holding, call_number:)] }

    context 'with 159.32 .W211' do
      let(:call_number) { '159.32 .W211' }
      it { is_expected.to eq ['Dewey Classification|100s - Philosophy|150s - Psychology'] }
    end

    context 'with 550.6 .U58P NO.1707' do
      let(:call_number) { '550.6 .U58P NO.1707' }
      it { is_expected.to eq ['Dewey Classification|500s - Natural Sciences & Mathematics|550s - Earth Sciences'] }
    end

    context 'with leading zero' do
      let(:call_number) { '062 .B862 V.193' }
      it { is_expected.to eq ['Dewey Classification|000s - Computer Science, Knowledge & Systems|060s - Associations, Organizations & Museums'] }
    end

    context 'without leading zero' do
      let(:call_number) { '62 .B862 V.193' }
      it { is_expected.to eq ['Dewey Classification|000s - Computer Science, Knowledge & Systems|060s - Associations, Organizations & Museums'] }
    end

    context 'with two leading zeros' do
      let(:call_number) { '002 U73' }
      it { is_expected.to eq ['Dewey Classification|000s - Computer Science, Knowledge & Systems|000s - Computer Science, Knowledge & Systems'] }
    end

    context 'without two leading zeros' do
      let(:call_number) { '2 U73' }
      it { is_expected.to eq ['Dewey Classification|000s - Computer Science, Knowledge & Systems|000s - Computer Science, Knowledge & Systems'] }
    end

    context 'with duplicate call numbers' do
      let(:holdings) do
        [
          build(:dewey_holding, call_number: '370.6 .N28 V.113:PT.1'),
          build(:dewey_holding, call_number: '370.6 .N28 V.113:PT.1')
        ]
      end

      it { is_expected.to eq ['Dewey Classification|300s - Social Sciences, Sociology & Anthropology|370s - Education'] }
    end

    context 'with multiple call numbers' do
      let(:holdings) do
        [
          build(:dewey_holding, call_number: '518 .M161'),
          build(:dewey_holding, call_number: '061 .R496 V.39:NO.4')
        ]
      end

      it {
        is_expected.to eq [
          'Dewey Classification|500s - Natural Sciences & Mathematics|510s - Mathematics',
          'Dewey Classification|000s - Computer Science, Knowledge & Systems|060s - Associations, Organizations & Museums'
        ]
      }
    end

    context 'when invalid' do
      let(:call_number) { '180.8 DX25 V.1' }
      it { is_expected.to be_nil }
    end
  end

  context 'with items typed as DEWEYPER' do
    let(:result) { record_with_holdings(call_number:, scheme: 'DEWEYPER', indexer:) }

    let(:call_number) { '550.6 .U58O 92-600' }
    it { is_expected.to eq ['Dewey Classification|500s - Natural Sciences & Mathematics|550s - Earth Sciences'] }
  end

  context 'with both dewey and LC call numbers' do
    let(:holdings) do
      [
        build(:lc_holding, call_number: 'PR5190 .P3 Z48 2011'),
        build(:dewey_holding, call_number: '968.006 .V274 SER.2:NO.42')
      ]
    end

    it {
      is_expected.to eq ['LC Classification|P - Philology, Linguistics (General)|PR - English Literature',
                         'Dewey Classification|900s - History & Geography|960s - History of Africa']
    }
  end

  context 'with call numbers that dewey but listed as LC' do
    let(:holdings) { [build(:lc_holding, call_number:)] }

    let(:call_number) { '180.8 D25 V.1' }
    it { is_expected.to eq ['Dewey Classification|100s - Philosophy|180s - Ancient, Medieval & Eastern Philosophy'] }
  end

  describe 'Gov Doc (call numbers)' do
    let(:folio_record) do
      FolioRecord.new({
                        'source_record' => source_record,
                        'instance' => {}
                      }, folio_client)
    end

    let(:folio_client) { instance_double(FolioClient, instance: {}, items_and_holdings:, statistical_codes: []) }
    let(:items_and_holdings) { {} }
    let(:sirsi_holdings) { [] }

    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(sirsi_holdings)
    end

    context 'with a SUDOC scheme' do
      let(:sirsi_holdings) do
        [
          build(:sudoc_holding, call_number: 'I 19.76:98-600-B')
        ]
      end

      it { is_expected.to eq ['Government Document|Other'] }
    end

    context 'when it has an 086' do
      let(:source_record) do
        [{ 'leader' => '          22        4500', 'fields' => [{ '086' => { 'ind1' => ' ', 'ind2' => ' ', 'subfields' => [] } }] }]
      end

      it { is_expected.to eq ['Government Document|Other'] }
    end

    context 'when the location has searchworksGovDocsClassification' do
      let(:items) do
        [{ 'id' => 'fe7e0573-1812-5957-ba3a-0e41d7717abe',
           'hrid' => 'ai1039075_1_1',
           'notes' => [],
           'status' => 'Available',
           'barcode' => '001AEY7183',
           'request' => nil,
           '_version' => 1,
           'metadata' =>
           { 'createdDate' => '2023-05-06T05:45:36.582Z',
             'updatedDate' => '2023-05-06T05:45:36.582Z',
             'createdByUserId' => '3e2ed889-52f2-45ce-8a30-8767266f07d2',
             'updatedByUserId' => '3e2ed889-52f2-45ce-8a30-8767266f07d2' },
           'formerIds' => [],
           'callNumber' =>
           { 'typeId' => '95467209-6d7b-468b-94df-0f5d7ad2747d', 'typeName' => 'Library of Congress classification', 'callNumber' => 'J301 .K63' },
           'copyNumber' => '1',
           'enumeration' => 'SESS 1924-25 V.30',
           'yearCaption' => [],
           'materialType' => 'book',
           'callNumberType' => { 'id' => '95467209-6d7b-468b-94df-0f5d7ad2747d', 'name' => 'Library of Congress classification', 'source' => 'folio' },
           'materialTypeId' => '1a54b431-2e4f-452d-9cae-9cee66c9a892',
           'numberOfPieces' => '1',
           'courseListingId' => nil,
           'circulationNotes' => [],
           'electronicAccess' => [],
           'holdingsRecordId' => '1ac11924-dc29-51b8-bb40-0316e5cb62ba',
           'itemDamagedStatus' => nil,
           'permanentLoanType' => 'Non-circulating',
           'temporaryLoanType' => nil,
           'statisticalCodeIds' => [],
           'administrativeNotes' => [],
           'effectiveLocationId' => 'cb0275a1-ac7a-4d3b-843a-62e77952f5d2',
           'permanentLoanTypeId' => '52d7b849-b6d8-4fb3-b2ab-a9b0eb41b6fd',
           'permanentLocationId' => 'cb0275a1-ac7a-4d3b-843a-62e77952f5d2',
           'suppressFromDiscovery' => false,
           'effectiveShelvingOrder' => 'J 3301 K63 SESS 41924 225 V 230 11',
           'effectiveCallNumberComponents' => { 'typeId' => '95467209-6d7b-468b-94df-0f5d7ad2747d', 'callNumber' => 'J301 .K63' },
           'location' =>
           { 'effectiveLocation' =>
             { 'id' => 'cb0275a1-ac7a-4d3b-843a-62e77952f5d2',
               'code' => 'GRE-BRIT-DOCS',
               'name' => 'British Government Documents',
               'campus' => { 'id' => 'c365047a-51f2-45ce-8601-e421ca3615c5', 'code' => 'SUL', 'name' => 'Stanford Libraries' },
               'details' => { 'searchworksGovDocsClassification' => 'British' },
               'library' => { 'id' => 'f6b5519e-88d9-413e-924d-9ed96255f72e', 'code' => 'GREEN', 'name' => 'Green Library' },
               'isActive' => true,
               'institution' => { 'id' => '8d433cdd-4e8f-4dc1-aa24-8a4ddb7dc929', 'code' => 'SU', 'name' => 'Stanford University' } },
             'permanentLocation' =>
             { 'id' => 'cb0275a1-ac7a-4d3b-843a-62e77952f5d2',
               'code' => 'GRE-BRIT-DOCS',
               'name' => 'British Government Documents',
               'campus' => { 'id' => 'c365047a-51f2-45ce-8601-e421ca3615c5', 'code' => 'SUL', 'name' => 'Stanford Libraries' },
               'details' => {},
               'library' => { 'id' => 'f6b5519e-88d9-413e-924d-9ed96255f72e', 'code' => 'GREEN', 'name' => 'Green Library' },
               'isActive' => true,
               'institution' => { 'id' => '8d433cdd-4e8f-4dc1-aa24-8a4ddb7dc929', 'code' => 'SU', 'name' => 'Stanford University' } } } }]
      end
      let(:items_and_holdings) do
        { 'items' => items }
      end

      it { is_expected.to eq ['Government Document|British'] }
    end

    context 'when it has an LC and Dewey and SUDOC call numbers' do
      let(:sirsi_holdings) do
        [
          build(:sudoc_holding, call_number: 'I 19.76:98-600-B'),
          build(:holding, scheme: 'DEWEYPER', call_number: '550.6 .U58O 00-600'),
          build(:holding, scheme: 'LCPER', call_number: 'QE538.8 .N36 1985:APR.')
        ]
      end

      it 'handles LC and Dewey and the SUDOC becomes "Government Document|Other"' do
        expect(value).to eq(
          [
            'LC Classification|Q - Science (General)|QE - Geology',
            'Dewey Classification|500s - Natural Sciences & Mathematics|550s - Earth Sciences',
            'Government Document|Other'
          ]
        )
      end

      context 'when it has location details also' do
        let(:items) do
          [{ 'id' => 'fe7e0573-1812-5957-ba3a-0e41d7717abe',
             'hrid' => 'ai1039075_1_1',
             'notes' => [],
             'status' => 'Available',
             'barcode' => '001AEY7183',
             'request' => nil,
             '_version' => 1,
             'metadata' =>
             { 'createdDate' => '2023-05-06T05:45:36.582Z',
               'updatedDate' => '2023-05-06T05:45:36.582Z',
               'createdByUserId' => '3e2ed889-52f2-45ce-8a30-8767266f07d2',
               'updatedByUserId' => '3e2ed889-52f2-45ce-8a30-8767266f07d2' },
             'formerIds' => [],
             'callNumber' =>
             { 'typeId' => '95467209-6d7b-468b-94df-0f5d7ad2747d', 'typeName' => 'Library of Congress classification', 'callNumber' => 'J301 .K63' },
             'copyNumber' => '1',
             'enumeration' => 'SESS 1924-25 V.30',
             'yearCaption' => [],
             'materialType' => 'book',
             'callNumberType' => { 'id' => '95467209-6d7b-468b-94df-0f5d7ad2747d', 'name' => 'Library of Congress classification', 'source' => 'folio' },
             'materialTypeId' => '1a54b431-2e4f-452d-9cae-9cee66c9a892',
             'numberOfPieces' => '1',
             'courseListingId' => nil,
             'circulationNotes' => [],
             'electronicAccess' => [],
             'holdingsRecordId' => '1ac11924-dc29-51b8-bb40-0316e5cb62ba',
             'itemDamagedStatus' => nil,
             'permanentLoanType' => 'Non-circulating',
             'temporaryLoanType' => nil,
             'statisticalCodeIds' => [],
             'administrativeNotes' => [],
             'effectiveLocationId' => 'cb0275a1-ac7a-4d3b-843a-62e77952f5d2',
             'permanentLoanTypeId' => '52d7b849-b6d8-4fb3-b2ab-a9b0eb41b6fd',
             'permanentLocationId' => 'cb0275a1-ac7a-4d3b-843a-62e77952f5d2',
             'suppressFromDiscovery' => false,
             'effectiveShelvingOrder' => 'J 3301 K63 SESS 41924 225 V 230 11',
             'effectiveCallNumberComponents' => { 'typeId' => '95467209-6d7b-468b-94df-0f5d7ad2747d', 'callNumber' => 'J301 .K63' },
             'location' =>
             { 'effectiveLocation' =>
               { 'id' => 'cb0275a1-ac7a-4d3b-843a-62e77952f5d2',
                 'code' => 'GRE-BRIT-DOCS',
                 'name' => 'British Government Documents',
                 'campus' => { 'id' => 'c365047a-51f2-45ce-8601-e421ca3615c5', 'code' => 'SUL', 'name' => 'Stanford Libraries' },
                 'details' => { 'searchworksGovDocsClassification' => 'British' },
                 'library' => { 'id' => 'f6b5519e-88d9-413e-924d-9ed96255f72e', 'code' => 'GREEN', 'name' => 'Green Library' },
                 'isActive' => true,
                 'institution' => { 'id' => '8d433cdd-4e8f-4dc1-aa24-8a4ddb7dc929', 'code' => 'SU', 'name' => 'Stanford University' } },
               'permanentLocation' =>
               { 'id' => 'cb0275a1-ac7a-4d3b-843a-62e77952f5d2',
                 'code' => 'GRE-BRIT-DOCS',
                 'name' => 'British Government Documents',
                 'campus' => { 'id' => 'c365047a-51f2-45ce-8601-e421ca3615c5', 'code' => 'SUL', 'name' => 'Stanford Libraries' },
                 'details' => {},
                 'library' => { 'id' => 'f6b5519e-88d9-413e-924d-9ed96255f72e', 'code' => 'GREEN', 'name' => 'Green Library' },
                 'isActive' => true,
                 'institution' => { 'id' => '8d433cdd-4e8f-4dc1-aa24-8a4ddb7dc929', 'code' => 'SU', 'name' => 'Stanford University' } } } }]
        end
        let(:items_and_holdings) do
          { 'items' => items }
        end

        it 'skips the SUDOC' do
          expect(value).to eq(
            [
              'LC Classification|Q - Science (General)|QE - Geology',
              'Dewey Classification|500s - Natural Sciences & Mathematics|550s - Earth Sciences',
              'Government Document|British'
            ]
          )
        end
      end
    end
  end
end
