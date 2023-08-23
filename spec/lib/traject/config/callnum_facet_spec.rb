# frozen_string_literal: true

require 'sirsi_holding'

# rubocop:disable Metrics/ParameterLists
def record_with_999(call_number:, scheme:, indexer:, home_location: 'STACKS', library: 'GREEN', type: '')
  indexer.map_record(stub_record_from_marc(
                       MARC::Record.new.tap do |r|
                         r.append(
                           MARC::DataField.new(
                             '999',
                             ' ',
                             ' ',
                             MARC::Subfield.new('a', call_number),
                             MARC::Subfield.new('l', home_location),
                             MARC::Subfield.new('m', library),
                             MARC::Subfield.new('t', type),
                             MARC::Subfield.new('w', scheme)
                           )
                         )
                         yield r if block_given?
                       end
                     ))
end
# rubocop:enable Metrics/ParameterLists

RSpec.describe 'Call Number Facet' do
  subject(:result) { indexer.map_record(folio_record) }
  # Legacy
  let(:folio_record) { stub_record_from_marc(marc_record) }

  # The future (when we remove calls to record_with_999)
  # let(:folio_record) do
  #   FolioRecord.new({
  #                     'source_record' => source_record,
  #                     'instance' => {}
  #                   }, stub_folio_client)
  # end

  let(:source_record) do
    [{ 'leader' => '          22        4500', 'fields' => [] }]
  end

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:field) { 'callnum_facet_hsim' }

  describe 'call numbers excluded for various reasons' do
    it 'handles unexpected callnum type (by not including them)' do
      expect(record_with_999(call_number: 'M123 .M234', scheme: 'ALPHANUM', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: 'M123 .M234', scheme: 'HARVYENCH', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: 'M123 .M234', scheme: 'OTHER', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: 'M123 .M234', scheme: 'THESIS', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: 'M123 .M234', scheme: 'XX', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: 'M123 .M234', scheme: 'ASIS', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: 'M123 .M234', scheme: 'AUTO', indexer:)[field]).to be_nil
    end

    it 'handles skipped items (by not including them)' do
      # skipped location
      expect(record_with_999(call_number: 'M123 .M234', home_location: 'BENDER-S', scheme: 'LC',
                             indexer:)[field]).to be_nil
      # skipped type
      expect(record_with_999(call_number: 'M123 .M234', type: 'EDI-REMOVE', scheme: 'LC',
                             indexer:)[field]).to be_nil
    end

    it 'handles weird LC callnum from Lane-Med (by not including them)' do
      # invalid LC from Lane
      expect(record_with_999(call_number: 'notLC', scheme: 'LC', library: 'LANE-MED',
                             indexer:)[field]).to be_nil

      # valid LC from Lane
      expect(record_with_999(call_number: 'M123 .M456', scheme: 'LC', indexer:)[field]).to eq(
        ['LC Classification|M - Music|M - Music']
      )

      #  invalid LC not from Lane
      expect(record_with_999(call_number: 'notLC', scheme: 'LC', indexer:)[field]).to be_nil
    end

    it 'assigns value for valid LC even if it is a shelve by location' do
      SirsiHolding::SHELBY_LOCS.each do |loc|
        # valid LC
        # FIXME: we DO want a value if there is valid LC for shelby location
        # expect(record_with_999(call_number: 'M123 .M456', scheme: 'LC', home_location: loc, indexer: indexer)[field]).to eq(
        #   ['LC Classification|M - Music|M - Music']
        # )

        # invalid LC
        expect(record_with_999(call_number: 'not valid!', scheme: 'LC', home_location: loc,
                               indexer:)[field]).to be_nil
        # invalid Dewey
        expect(record_with_999(call_number: 'not valid!', scheme: 'DEWEY', home_location: loc,
                               indexer:)[field]).to be_nil
        # Hopkins weird Shelby
        expect(record_with_999(call_number: ' 1976', scheme: 'LCPER', home_location: loc,
                               indexer:)[field]).to be_nil
        expect(record_with_999(call_number: '1976', scheme: 'LCPER', home_location: loc,
                               indexer:)[field]).to be_nil
      end
    end

    it 'handles missing or lost call numbers (by not including them)' do
      SirsiHolding::LOST_OR_MISSING_LOCS.each do |loc|
        # valid LC
        expect(record_with_999(call_number: 'M123 .M456', home_location: loc, scheme: 'LC',
                               indexer:)[field]).to be_nil
        # invalid LC
        expect(record_with_999(call_number: 'not valid!', home_location: loc, scheme: 'LC',
                               indexer:)[field]).to be_nil
        # valid Dewey
        expect(record_with_999(call_number: '123.4 .B45', home_location: loc, scheme: 'DEWEY',
                               indexer:)[field]).to be_nil
        # invalid Dewey
        expect(record_with_999(call_number: 'not valid!', home_location: loc, scheme: 'DEWEY',
                               indexer:)[field]).to be_nil
      end
    end

    it 'handles ignored call numbers (by not including them)' do
      # LC
      expect(record_with_999(call_number: 'INTERNET RESOURCE stuff', scheme: 'LC', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: 'XX stuff', scheme: 'LC', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: 'NO CALL NUMBER', scheme: 'LC', indexer:)[field]).to be_nil

      # Dewey
      expect(record_with_999(call_number: 'INTERNET RESOURCE stuff', scheme: 'DEWEY',
                             indexer:)[field]).to be_nil
      expect(record_with_999(call_number: 'XX stuff', scheme: 'DEWEY', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: 'NO CALL NUMBER', scheme: 'DEWEY', indexer:)[field]).to be_nil
    end

    it 'handles empty call numbers (by not returning them)' do
      # LC
      expect(record_with_999(call_number: nil, scheme: 'LC', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: '', scheme: 'LC', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: ' ', scheme: 'LC', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: '. . ', scheme: 'LC', indexer:)[field]).to be_nil

      # Dewey
      expect(record_with_999(call_number: nil, scheme: 'DEWEY', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: '', scheme: 'DEWEY', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: ' ', scheme: 'DEWEY', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: '. . ', scheme: 'DEWEY', indexer:)[field]).to be_nil
    end

    it 'does not return call nubmers typed as Alphanum, and clearly not LC or Dewey' do
      expect(record_with_999(call_number: '71 15446 V.1', scheme: 'ALPHANUM', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: '4488.301 0300 2001 CD-ROM', scheme: 'ALPHANUM',
                             indexer:)[field]).to be_nil
      expect(record_with_999(call_number: '8291.209 .A963 V.5 1971/1972', scheme: 'ALPHANUM',
                             indexer:)[field]).to be_nil
      expect(record_with_999(call_number: '"NEW BEGINNING" INVESTMENT RESERVE FUND', scheme: 'ALPHANUM',
                             indexer:)[field]).to be_nil
      expect(record_with_999(call_number: '"21" BRANDS, INCORPORATED', scheme: 'ALPHANUM',
                             indexer:)[field]).to be_nil
      expect(record_with_999(call_number: ' "LA CONSOLIDADA", S.A', scheme: 'ALPHANUM',
                             indexer:)[field]).to be_nil
      expect(record_with_999(call_number: '(THE) NWNL COMPANIES, INC.', scheme: 'ALPHANUM',
                             indexer:)[field]).to be_nil
      expect(record_with_999(call_number: 'ISHII SPRING 2009', scheme: 'ALPHANUM', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: 'OYER WINTER 2012', scheme: 'ALPHANUM', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: "O'REILLY FALL 2006", scheme: 'ALPHANUM', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: 'XV 852', scheme: 'ALPHANUM', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: 'YUGOSLAV SERIAL 1963 NO.5-6', scheme: 'ALPHANUM',
                             indexer:)[field]).to be_nil
      expect(record_with_999(call_number: 'SUSEL-69048', scheme: 'ALPHANUM', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: 'MFICHE 3239', scheme: 'ALPHANUM', indexer:)[field]).to be_nil
    end

    it 'does not return call numbers w/ the scheme ASIS' do
      expect(record_with_999(call_number: '(ADL4044.1)XX', scheme: 'ASIS', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: '134776', scheme: 'ASIS', indexer:)[field]).to be_nil
      expect(record_with_999(call_number: 'INTERNET RESOURCE', scheme: 'ASIS', indexer:)[field]).to be_nil
    end
  end

  describe 'LC Call Numbers' do
    let(:result) { record_with_999(call_number:, scheme: 'LC', indexer:) }
    subject(:value) { result[field] }

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
      let(:result) do
        record_with_999(call_number: 'ML171 .L38 2005', scheme: 'LC', indexer:) do |marc_record|
          marc_record.append(
            MARC::DataField.new(
              '999',
              ' ',
              ' ',
              MARC::Subfield.new('a', 'M2 .C17 L3 2005'),
              MARC::Subfield.new('w', 'LC')
            )
          )
        end
      end
      it {
        is_expected.to match_array [
          'LC Classification|M - Music|M - Music',
          'LC Classification|M - Music|ML - Literature on Music'
        ]
      }
    end

    context 'with multiple holding records with the different LC classes' do
      let(:result) do
        record_with_999(call_number: 'ML171 .L38 2005', scheme: 'LC', indexer:) do |marc_record|
          marc_record.append(
            MARC::DataField.new(
              '999',
              ' ',
              ' ',
              MARC::Subfield.new('a', 'QE538.8 .N36 1975-1977'),
              MARC::Subfield.new('w', 'LC')
            )
          )
        end
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
    subject(:value) { result[field] }
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
        '2061 4246 NO.5-6 1936-1937',
        '4362 .S12P2 1965 .C3',
        '4861.1 3700 1989:NO.4-6',
        '4488.301 0300 2005 CD-ROM',
        # weird in process call numbers
        '001AQJ5818',
        '(XX.4300523)',
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
        let(:result) { record_with_999(call_number:, scheme: 'LC', indexer:) }
        it { is_expected.to be_nil }
      end
    end
  end

  describe 'dewey call numbers' do
    it 'has the correct data' do
      expect(record_with_999(call_number: '159.32 .W211', scheme: 'DEWEY', indexer:)[field]).to eq(
        ['Dewey Classification|100s - Philosophy|150s - Psychology']
      )

      expect(record_with_999(call_number: '550.6 .U58P NO.1707', scheme: 'DEWEY', indexer:)[field]).to eq(
        ['Dewey Classification|500s - Natural Sciences & Mathematics|550s - Earth Sciences']
      )
    end

    it 'has the correct data for dewey call numbers w/o leading zeros' do
      expect(record_with_999(call_number: '062 .B862 V.193', scheme: 'DEWEY', indexer:)[field]).to eq(
        ['Dewey Classification|000s - Computer Science, Knowledge & Systems|060s - Associations, Organizations & Museums']
      )

      expect(record_with_999(call_number: '62 .B862 V.193', scheme: 'DEWEY', indexer:)[field]).to eq(
        ['Dewey Classification|000s - Computer Science, Knowledge & Systems|060s - Associations, Organizations & Museums']
      )

      expect(record_with_999(call_number: '002 U73', scheme: 'DEWEY', indexer:)[field]).to eq(
        ['Dewey Classification|000s - Computer Science, Knowledge & Systems|000s - Computer Science, Knowledge & Systems']
      )

      expect(record_with_999(call_number: '2 U73', scheme: 'DEWEY', indexer:)[field]).to eq(
        ['Dewey Classification|000s - Computer Science, Knowledge & Systems|000s - Computer Science, Knowledge & Systems']
      )
    end

    it 'only includes one call number if there are duplicates' do
      doc = record_with_999(call_number: '370.6 .N28 V.113:PT.1', scheme: 'DEWEY', indexer:)

      expect(doc[field]).to eq(
        ['Dewey Classification|300s - Social Sciences, Sociology & Anthropology|370s - Education']
      )

      doc = record_with_999(call_number: '370.6 .N28 V.113:PT.1', scheme: 'DEWEY', indexer:) do |marc_record|
        marc_record.append(
          MARC::DataField.new(
            '999',
            ' ',
            ' ',
            MARC::Subfield.new('a', '370.6 .N28 V.113:PT.1'),
            MARC::Subfield.new('w', 'DEWEY')
          )
        )
      end

      expect(doc[field]).to eq(
        ['Dewey Classification|300s - Social Sciences, Sociology & Anthropology|370s - Education']
      )
    end

    it 'includes multiple call numbers from the same record' do
      doc = record_with_999(call_number: '518 .M161', scheme: 'DEWEY', indexer:)

      expect(doc[field]).to eq(
        ['Dewey Classification|500s - Natural Sciences & Mathematics|510s - Mathematics']
      )

      doc = record_with_999(call_number: '518 .M161', scheme: 'DEWEY', indexer:) do |marc_record|
        marc_record.append(
          MARC::DataField.new(
            '999',
            ' ',
            ' ',
            MARC::Subfield.new('a', '061 .R496 V.39:NO.4'),
            MARC::Subfield.new('w', 'DEWEY')
          )
        )
      end

      expect(doc[field]).to eq(
        [
          'Dewey Classification|500s - Natural Sciences & Mathematics|510s - Mathematics',
          'Dewey Classification|000s - Computer Science, Knowledge & Systems|060s - Associations, Organizations & Museums'
        ]
      )
    end

    it 'includes both dewey and LC call numbers when present' do
      doc = record_with_999(call_number: 'PR5190 .P3 Z48 2011', scheme: 'LC', indexer:) do |marc_record|
        marc_record.append(
          MARC::DataField.new(
            '999',
            ' ',
            ' ',
            MARC::Subfield.new('a', '968.006 .V274 SER.2:NO.42'),
            MARC::Subfield.new('w', 'DEWEY')
          )
        )
      end
      expect(doc[field]).to eq(
        [
          'LC Classification|P - Philology, Linguistics (General)|PR - English Literature',
          'Dewey Classification|900s - History & Geography|960s - History of Africa'
        ]
      )

      doc = record_with_999(call_number: 'QE539.2 .P34 O77 2005', scheme: 'LC', indexer:) do |marc_record|
        marc_record.append(
          MARC::DataField.new(
            '999',
            ' ',
            ' ',
            MARC::Subfield.new('a', '550.6 .U58P NO.1707'),
            MARC::Subfield.new('w', 'DEWEY')
          )
        )
      end
      expect(doc[field]).to eq(
        [
          'LC Classification|Q - Science (General)|QE - Geology',
          'Dewey Classification|500s - Natural Sciences & Mathematics|550s - Earth Sciences'
        ]
      )
    end

    it 'inlcudes items typed as DEWEYPER' do
      expect(record_with_999(call_number: '550.6 .U58O 92-600', scheme: 'DEWEYPER', indexer:)[field]).to eq(
        ['Dewey Classification|500s - Natural Sciences & Mathematics|550s - Earth Sciences']
      )
    end

    it 'handles call numbers that dewey but listed as LC' do
      expect(record_with_999(call_number: '180.8 D25 V.1', scheme: 'LC', indexer:)[field]).to eq(
        ['Dewey Classification|100s - Philosophy|180s - Ancient, Medieval & Eastern Philosophy']
      )

      expect(record_with_999(call_number: '219.7 K193L V.5', scheme: 'LC', indexer:)[field]).to eq(
        ['Dewey Classification|200s - Religion|210s - Philosophy & Theory of Religion']
      )

      expect(record_with_999(call_number: '3.37 D621', scheme: 'LC', indexer:)[field]).to eq(
        ['Dewey Classification|000s - Computer Science, Knowledge & Systems|000s - Computer Science, Knowledge & Systems']
      )
    end
  end

  describe 'invalid DEWEY call numbers' do
    it 'are not included' do
      expect(record_with_999(call_number: '180.8 DX25 V.1', scheme: 'LC', indexer:)[field]).to be_nil
    end
  end

  describe 'Gov Doc (call numbers)' do
    subject(:value) { result[field] }
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
          SirsiHolding.new(
            call_number: 'I 19.76:98-600-B',
            home_location: '',
            library: 'GREEN',
            scheme: 'SUDOC',
            type: '',
            barcode: ''
          )
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
          SirsiHolding.new(
            call_number: 'I 19.76:98-600-B',
            home_location: '',
            library: 'GREEN',
            scheme: 'SUDOC',
            type: '',
            barcode: ''
          ),
          SirsiHolding.new(
            call_number: '550.6 .U58O 00-600',
            home_location: '',
            library: 'GREEN',
            scheme: 'DEWEYPER',
            type: '',
            barcode: ''
          ),
          SirsiHolding.new(
            call_number: 'QE538.8 .N36 1985:APR.',
            home_location: '',
            library: 'GREEN',
            scheme: 'LCPER',
            # type: '',
            barcode: ''
          )
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
