RSpec.describe 'Title spec' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end
  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:fixture_name) { 'titleTests.mrc' }
  let(:record) { records.first }

  describe 'title_245a_search' do
    let(:field) { 'title_245a_search' }
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    it 'has the correct titles' do
      result = select_by_id('245allSubs')[field]
      expect(result).to eq ['245a']

      expect(results).not_to include hash_including(field => ['electronic'])
      expect(results).not_to include hash_including(field => ['john'])
      expect(results).not_to include hash_including(field => ['handbook'])

      result = select_by_id('2xx')[field]
      expect(result).to eq ['2xx fields']
    end
    context 'linked fields' do
      let(:fixture_name) { 'vernacularSearchTests.mrc' }
      it 'are not included' do
        expect(select_by_id('2xxVernSearch')[field]).not_to eq ['vern245a']
        expect(select_by_id('2xxVernSearch')[field]).to eq ['2xx title search fields for vernacular, except for 240 -- all subfields']
      end
    end
  end
  describe 'vern_title_245a_search' do
    let(:fixture_name) { 'vernacularSearchTests.mrc' }
    let(:field) { 'vern_title_245a_search' }
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    it 'has the correct titles' do
      expect(select_by_id('2xxVernSearch')[field].first).to match(/vern245a/)
      expect(results).not_to include hash_including(field => ['vern245b'])
      expect(results).not_to include hash_including(field => ['vern245p'])
    end
    it 'does not have 2nd vernacular 245 field' do
      expect(select_by_id('2xxVernSearch')[field]).not_to eq ['vern245a', '2nd vern245a']
    end
  end
  describe 'title_245_search' do
    let(:field) { 'title_245_search' }
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    it 'has the correct titles' do
      result = select_by_id('245allSubs')[field]
      expect(result).to eq [
        '245a 245b 245p1 245s 245k1 245f 245n1 245g 245p2 245k2 245n2'
      ]

      result = select_by_id('245pNotn')[field]
      expect(result.first).to include 'handbook'

      result = select_by_id('245pThenn')[field]
      expect(result.first).to include 'Verzeichnis'

      result = select_by_id('245nAndp')[field]
      expect(result.first).to include 'humanities'
    end
    context 'linked fields' do
      let(:fixture_name) { 'vernacularSearchTests.mrc' }
      it 'are not included' do
        expect(select_by_id('2xxVernSearch')[field]).to eq ['2xx title search fields for vernacular, except for 240 -- all subfields']
      end
    end
  end
  describe 'vern_title_245_search' do
    let(:fixture_name) { 'vernacularSearchTests.mrc' }
    let(:field) { 'vern_title_245_search' }
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    it 'has the correct titles' do
      expect(select_by_id('2xxVernSearch')[field])
        .to eq ['vern245a vern245b vern245f vern245g vern245k vern245n vern245p vern245s']
      expect(results).not_to include hash_including(field => ['nope'])
    end
    it 'does not have 2nd vernacular 245 field' do
      expect(select_by_id('2xxVernSearch')[field])
        .not_to eq ['vern245a vern245b vern245f vern245g vern245k vern245n vern245p vern245s',
                    '2nd vern245a']
    end
  end
  describe 'title_uniform_search' do
    let(:field) { 'title_uniform_search' }
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    it 'has the correct titles' do
      expect(select_by_id('130240')[field]).to eq ['Hoos Foos']
      expect(select_by_id('130')[field]).to eq ['The Snimm.']

      expect(results).not_to include hash_including(field => ['balloon'])
      expect(results).not_to include hash_including(field => ['130'])
    end
    context 'linked fields' do
      let(:fixture_name) { 'vernacularSearchTests.mrc' }
      it '130 are not included' do
        expect(select_by_id('2xxVernSearch')[field]).not_to eq ['2nd 130a',
                                                                'vern130a',
                                                                'vern130d',
                                                                'vern130f',
                                                                'vern130g',
                                                                'vern130k',
                                                                'vern130l',
                                                                'vern130m',
                                                                'vern130n',
                                                                'vern130o',
                                                                'vern130p',
                                                                'vern130r',
                                                                'vern130s',
                                                                'vern130t']
        expect(select_by_id('2xxVernSearch')[field]).to eq ['130a']
      end
      it '240 are not included' do
        expect(select_by_id('240VernSearch')[field]).to eq ['240a']
        expect(select_by_id('240VernSearch')[field]).not_to eq ['vern240a',
                                                                'vern240d',
                                                                'vern240f',
                                                                'vern240g',
                                                                'vern240k',
                                                                'vern240l',
                                                                'vern240m',
                                                                'vern240n',
                                                                'vern240o',
                                                                'vern240p',
                                                                'vern240r',
                                                                'vern240s']
      end
    end
  end
  describe 'vern_title_uniform_search' do
    let(:fixture_name) { 'vernacularSearchTests.mrc' }
    let(:field) { 'vern_title_uniform_search' }
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    it 'has the correct titles' do
      expect(select_by_id('2xxVernSearch')[field].first)
        .to eq 'vern130a vern130d vern130f vern130g vern130k vern130l vern130m'\
          ' vern130n vern130o vern130p vern130r vern130s vern130t'
      expect(select_by_id('240VernSearch')[field].first)
        .to eq 'vern240a vern240d vern240f vern240g vern240k vern240l vern240m'\
          ' vern240n vern240o vern240p vern240r vern240s'
      expect(results).not_to include hash_including(field => ['nope'])
    end
  end
  describe 'title_variant_search' do
    let(:field) { 'title_variant_search' }
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    it 'has the correct titles' do
      expect(select_by_id('2xx')[field][0]).to eq '210a 210b'
      expect(select_by_id('2xx')[field][1]).to eq '222a 222b'
      expect(select_by_id('2xx')[field][2]).to eq '242a 242b 242n 242p'
      expect(select_by_id('2xx')[field][3]).to eq '243a 243d 243f 243g 243k '\
        '243l 243m 243n 243o 243p 243r 243s'
      expect(select_by_id('2xx')[field][4]).to eq '246a 246b 246f 246g 246n 246p'
      expect(select_by_id('2xx')[field][5]).to eq '247a 247b 247f 247g 247n 247p'

      expect(results).not_to include hash_including(field => ['nope'])
    end
  end
  describe 'vern_title_variant_search' do
    let(:fixture_name) { 'vernacularSearchTests.mrc' }
    let(:field) { 'vern_title_variant_search' }
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    it 'has the correct titles' do
      expect(select_by_id('2xxVernSearch')[field][0]).to eq 'vern210a vern210b'
      expect(select_by_id('2xxVernSearch')[field][1]).to eq 'vern222a vern222b'
      expect(select_by_id('2xxVernSearch')[field][2]).to eq 'vern242a vern242b'\
        ' vern242n vern242p'
      expect(select_by_id('2xxVernSearch')[field][3]).to eq 'vern243a vern243d'\
        ' vern243f vern243g vern243k vern243l vern243m vern243n vern243o'\
        ' vern243p vern243r vern243s'
      expect(select_by_id('2xxVernSearch')[field][4]).to eq 'vern246a vern246b'\
        ' vern246f vern246g vern246n vern246p'
      expect(select_by_id('2xxVernSearch')[field][5]).to eq 'vern247a vern247b'\
        ' vern247f vern247g vern247n vern247p'

      expect(results).not_to include hash_including(field => ['nope'])
      expect(results).not_to include hash_including(field => ['vern243'])
    end
  end
  describe 'title_related_search' do
    let(:field) { 'title_related_search' }
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    it 'has the correct titles' do
      expect(select_by_id('505')[field]).to eq ['505t']
      expect(results).not_to include hash_including(field => ['nope'])

      expect(select_by_id('700')[field][0]).to eq '700f 700g 700k 700l 700m 70'\
        '0n 700o 700p 700r 700s 700t'

      expect(select_by_id('710')[field][0]).to eq '710d 710f 710g 710k 710l 71'\
        '0m 710n 710o 710p 710r 710s 710t'

      expect(select_by_id('711')[field][0]).to eq '711f 711g 711k 711l 711n 71'\
        '1p 711s 711t'

      expect(select_by_id('730')[field][0]).to eq '730a 730d 730f 730g 730k 73'\
        '0l 730m 730n 730o 730p 730r 730s 730t'

      expect(select_by_id('740')[field][0]).to eq '740a 740n 740p'

      expect(select_by_id('246aAnd740')[field][0]).to eq '740 subfield a'

      expect(select_by_id('76x')[field]).to eq [
        '760s 760t', '762s 762t', '765s 765t', '767s 767t'
      ]

      expect(select_by_id('77x')[field]).to eq [
        '770s 770t', '772s 772t', '773s 773t', '774s 774t', '775s 775t',
        '776s 776t', '777s 777t'
      ]

      expect(select_by_id('78x')[field]).to eq [
        '780s 780t', '785s 785t', '786s 786t', '787s 787t'
      ]

      ['780tNota', '780aAndt', '780tNota'].each do |id|
        expect(select_by_id(id)[field].first).to include '780 subfield t'
      end

      ['785tNota', '785aAndt'].each do |id|
        expect(select_by_id(id)[field].first).to include '785 subfield t'
      end

      ['780tNota', '785tNota'].each do |id|
        expect(select_by_id(id)[field].first).to include 'only'
      end

      expect(select_by_id('785aNott')[field]).to be_nil
    end
  end
  describe 'vern_title_related_search' do
    let(:field) { 'vern_title_related_search' }
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    context 'with summaryTests' do
      let(:fixture_name) { 'summaryTests.mrc' }
      it 'has the correct titles' do
        expect(select_by_id('505')[field]).to eq ['vern505t']
        expect(results).not_to include hash_including(field => ['nope'])
      end
    end
    context 'with vernacularSearchTests.mrc' do
      let(:fixture_name) { 'vernacularSearchTests.mrc' }
      it 'has the correct titles' do
        expect(select_by_id('7xxLowVernSearch')[field][0]).to eq 'vern700f ver'\
          'n700g vern700k vern700l vern700m vern700n vern700o vern700p vern700'\
          'r vern700s vern700t'

        ['7xxLowVernSearch', '7xxVernPersonSearch'].each do |id|
          expect(select_by_id(id)[field].first).to include 'vern700g'
        end

        expect(results).not_to include hash_including(field => ['vern700j'])
        expect(results).not_to include hash_including(field => ['nope'])

        expect(select_by_id('7xxLowVernSearch')[field][1]).to eq 'vern710d ver'\
          'n710f vern710g vern710k vern710l vern710m vern710n vern710o vern710'\
          'p vern710r vern710s vern710t'

        expect(select_by_id('7xxVernCorpSearch')[field][0]).to eq 'vern710d ve'\
          'rn710f vern710g vern710k vern710n'

        expect(select_by_id('7xxLowVernSearch')[field][2]).to eq 'vern711f ver'\
          'n711g vern711k vern711l vern711n vern711p vern711s vern711t'

        expect(select_by_id('7xxLowVernSearch')[field][3]).to eq 'vern730a ver'\
          'n730d vern730f vern730g vern730k vern730l vern730m vern730n vern730'\
          'o vern730p vern730r vern730s vern730t'

        expect(select_by_id('7xxLowVernSearch')[field][4]).to eq 'vern740a ver'\
          'n740n vern740p'

        expect(select_by_id('76xVernSearch')[field][0]).to eq 'vern760s vern760t'
        expect(select_by_id('76xVernSearch')[field][1]).to eq 'vern762s vern762t'
        expect(select_by_id('76xVernSearch')[field][2]).to eq 'vern765s vern765t'
        expect(select_by_id('76xVernSearch')[field][3]).to eq 'vern767s vern767t'

        expect(select_by_id('78xVernSearch')[field][0]).to eq 'vern780s vern780t'
        expect(select_by_id('78xVernSearch')[field][1]).to eq 'vern785s vern785t'
        expect(select_by_id('78xVernSearch')[field][2]).to eq 'vern786s vern786t'
        expect(select_by_id('78xVernSearch')[field][3]).to eq 'vern787s vern787t'

        expect(select_by_id('79xVernSearch')[field][0]).to eq 'vern796f vern79'\
          '6g vern796k vern796l vern796m vern796n vern796o vern796p vern796r v'\
          'ern796s vern796t'

        expect(select_by_id('79xVernSearch')[field].first).to include 'vern796g'
        expect(results).not_to include hash_including(field => ['vern796j'])

        expect(select_by_id('79xVernSearch')[field][0]).to eq 'vern796f vern79'\
          '6g vern796k vern796l vern796m vern796n vern796o vern796p vern796r v'\
          'ern796s vern796t'

        expect(select_by_id('79xVernSearch')[field][1]).to eq 'vern797d vern79'\
          '7f vern797g vern797k vern797l vern797m vern797n vern797o vern797p v'\
          'ern797r vern797s vern797t'

        ['7xxVernCorpSearch'].each do |id|
          expect(select_by_id(id)[field]).to include(/vern797d/)
        end

        expect(select_by_id('79xVernSearch')[field][2]).to eq 'vern798f vern79'\
          '8g vern798k vern798l vern798n vern798p vern798s vern798t'

        ['7xxVernMeetingSearch'].each do |id|
          expect(select_by_id(id)[field]).to include(/vern798g/)
          expect(select_by_id(id)[field]).to include(/vern798n/)
        end

        expect(select_by_id('79xVernSearch')[field][3]).to eq 'vern799a vern79'\
          '9d vern799f vern799g vern799k vern799l vern799m vern799n vern799o v'\
          'ern799p vern799r vern799s vern799t'

        expect(results).not_to include hash_including(field => ['nope'])
        pending
        expect(select_by_id('7xxVernPersonSearch')[field].first).to include 'vern796g'
      end
    end
  end
  describe 'title_245a_display' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    let(:field) { 'title_245a_display' }
    it 'has the correct titles' do
      expect(select_by_id('245NoNorP')[field]).to eq ['245 no subfield n or p']
      expect(select_by_id('245nAndp')[field]).to eq ['245 n and p']
      expect(select_by_id('245multpn')[field]).to eq ['245 multiple p, n']
    end
    context 'trailing punctuation' do
      let(:fixture_name) { 'displayFieldsTests.mrc' }
      it 'has the correct titles' do
        expect(select_by_id('2451')[field]).to eq ['Heritage Books archives']
        expect(select_by_id('2452')[field]).to eq ['Ton meionoteton eunoia']
        expect(select_by_id('14161')[field]).to eq ['The study of man.']
      end
    end
  end
  describe 'vern_title_245a_display' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    let(:fixture_name) { 'vernacularNonSearchTests.mrc' }
    let(:field) { 'vern_title_245a_display' }
    it 'has the correct titles' do
      expect(select_by_id('allVern')[field]).to eq ['vernacular title 245']
      expect(select_by_id('trailingPunct')[field]).to eq ['vernacular ends in slash']
    end
  end
  describe 'title_245c_display' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    let(:field) { 'title_245c_display' }
    it 'has the correct titles' do
      expect(select_by_id('245NoNorP')[field]).to eq ['by John Sandford']
    end
    context 'trailing punctuation' do
      let(:fixture_name) { 'displayFieldsTests.mrc' }
      it 'has the correct titles' do
        expect(select_by_id('2451')[field]).to eq ['Laverne Galeener-Moore']
        expect(select_by_id('2453')[field]).to eq ['...']
      end
    end
  end
  describe 'vern_title_245c_display' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    let(:fixture_name) { 'vernacularNonSearchTests.mrc' }
    let(:field) { 'vern_title_245c_display' }
    it 'has the correct titles' do
      expect(select_by_id('RtoL')[field]).to eq ['crocodile for is c']
    end
    context 'trailing punctuation' do
      it 'has the correct titles' do
        expect(select_by_id('7070581')[field]).to eq ['王建革著.']
      end
    end
  end
  describe 'title_display' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    let(:field) { 'title_display' }
    it 'has the correct titles' do
      expect(select_by_id('245NoNorP')[field]).to eq ['245 no subfield n or p [electronic resource]']
      expect(select_by_id('245pNotn')[field]).to eq ['245 p but no n. subfield b Student handbook']
      expect(select_by_id('245nAndp')[field]).to eq ['245 n and p: A, The humanities and social sciences']
      expect(select_by_id('245multpn')[field]).to eq ['245 multiple p, n first p subfield first n subfield second p subfield second n subfield']
      expect(select_by_id('245nNotp')[field]).to eq ['245 n but no p Part one.']
    end
    context 'trailing punctuation' do
      let(:fixture_name) { 'displayFieldsTests.mrc' }
      it 'has the correct titles' do
        expect(select_by_id('2451')[field]).to eq ['Heritage Books archives. Underwood biographical dictionary. Volumes 1 & 2 revised [electronic resource]']
        expect(select_by_id('2452')[field]).to eq ['Ton meionoteton eunoia : mythistorema']
        expect(select_by_id('2453')[field]).to eq ['Proceedings']
        expect(select_by_id('14161')[field]).to eq ['The study of man.']
      end
    end
    context 'non-filing' do
      it 'has the correct titles' do
        expect(select_by_id('115472')[field]).to eq ['India and the European Economic Community']
        expect(select_by_id('7117119')[field]).to eq ['HOUSING CARE AND SUPPORT PUTTING GOOD IDEAS INTO PRACTICE']
        expect(select_by_id('1962398')[field]).to eq ['A guide to resources in United States libraries']
        expect(select_by_id('4428936')[field]).to eq ['Il cinema della transizione']
        expect(select_by_id('1261173')[field]).to eq ['The second part of the Confutation of the Ballancing letter']
        expect(select_by_id('575946')[field]).to eq ['Der Ruckzug der biblischen Prophetie von der neueren Geschichte']
        expect(select_by_id('666')[field]).to eq ['ZZZZ']

        expect(select_by_id('2400')[field]).to eq ['240 0 non-filing']
        expect(select_by_id('2402')[field]).to eq ['240 2 non-filing']
        expect(select_by_id('2407')[field]).to eq ['240 7 non-filing']
        expect(select_by_id('130')[field]).to eq ['130 4 non-filing']
        expect(select_by_id('130240')[field]).to eq ['130 and 240']

        expect(select_by_id('2458')[field]).to eq ['245 has sub 8']
      end
    end
  end
  describe 'vern_title_display' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    let(:fixture_name) { 'vernacularNonSearchTests.mrc' }
    let(:field) { 'vern_title_display' }
    it 'has the correct titles' do
      expect(select_by_id('trailingPunct')[field]).to eq ['vernacular ends in slash']
    end
  end
  describe 'title_full_display' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    let(:field) { 'title_full_display' }
    it 'has the correct titles' do
      expect(select_by_id('245NoNorP')[field]).to eq ['245 no subfield n or p [electronic resource] / by John Sandford.']
      expect(select_by_id('245nNotp')[field]).to eq ['245 n but no p Part one.']
      expect(select_by_id('245pNotn')[field]).to eq ['245 p but no n. subfield b Student handbook.']
      expect(select_by_id('245nAndp')[field]).to eq ['245 n and p: A, The humanities and social sciences.']
      expect(select_by_id('245multpn')[field]).to eq ['245 multiple p, n first p subfield first n subfield second p subfield second n subfield']
    end
    context 'display field tests' do
      let(:fixture_name) { 'displayFieldsTests.mrc' }
      it 'has the correct titles' do
        expect(select_by_id('2451')[field]).to eq ['Heritage Books archives. Underwood biographical dictionary. Volumes 1 & 2 revised [electronic resource] / Laverne Galeener-Moore.']
        expect(select_by_id('2452')[field]).to eq ['Ton meionoteton eunoia : mythistorema / Spyrou Gkrintzou.']
        expect(select_by_id('2453')[field]).to eq ['Proceedings / ...']
      end
    end
    context 'vernacular tests' do
      let(:fixture_name) { 'vernacularNonSearchTests.mrc' }
      it 'has the correct titles' do
        expect(select_by_id('hebrew1')[field]).to include 'Alef bet shel Yahadut.'
        expect(select_by_id('RtoL')[field]).to include 'a is for alligator / c is for crocodile, 1980'
      end
    end
  end
  describe 'vern_title_full_display' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    let(:fixture_name) { 'vernacularNonSearchTests.mrc' }
    let(:field) { 'vern_title_full_display' }
    it 'has the correct titles' do
      skip 'No tests in solrmarc-sw actually run / pass'
    end
  end
  describe 'title_uniform_display' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    let(:field) { 'title_uniform_display' }
    it 'has the correct titles' do
      # no 240 or 130
      expect(select_by_id('115472')[field]).to be_nil
      expect(select_by_id('7117119')[field]).to be_nil
      expect(select_by_id('1962398')[field]).to be_nil
      expect(select_by_id('4428936')[field]).to be_nil
      expect(select_by_id('1261173')[field]).to be_nil

      # 240 only
      expect(select_by_id('575946')[field]).to eq ['De incertitudine et vanitate scientiarum. German']
      expect(select_by_id('666')[field]).to eq ['De incertitudine et vanitate scientiarum. German']
      expect(select_by_id('2400')[field]).to eq ['Wacky']
      expect(select_by_id('2402')[field]).to eq ['A Wacky']
      expect(select_by_id('2407')[field]).to eq ['A Wacky Tacky']

      # uniform title 130 if exists, 240 if not
      expect(select_by_id('130')[field]).to eq ['The Snimm.']
      expect(select_by_id('130240')[field]).to eq ['Hoos Foos']

      # numeric subfields
      expect(select_by_id('1306')[field]).to eq ['Sox on Fox']
      expect(select_by_id('0240')[field]).to eq ['sleep little fishies']
      expect(select_by_id('24025')[field]).to eq ['la di dah']
    end
    context 'display field tests' do
      let(:fixture_name) { 'displayFieldsTests.mrc' }
      it 'has the correct titles' do
        expect(select_by_id('2401')[field]).to eq ['Variations, piano, 4 hands, K. 501, G major']
        expect(select_by_id('2402')[field]).to eq ['Treaties, etc. Poland, 1948 Mar. 2. Protocols, etc., 1951 Mar. 6']
        expect(select_by_id('130')[field]).to eq ['Bible. O.T. Five Scrolls. Hebrew. Biblioteca apostolica vaticana. Manuscript. Urbiniti Hebraicus 1. 1980.']
        expect(select_by_id('11332244')[field]).to eq ['Bodkin Van Horn']
      end
    end
  end
  describe 'vern_title_uniform_display' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    let(:fixture_name) { 'vernacularNonSearchTests.mrc' }
    let(:field) { 'vern_title_uniform_display' }
    it 'has the correct titles' do
      expect(select_by_id('130only')[field]).to eq ['vernacular main entry uniform title']
      expect(select_by_id('240only')[field]).to eq ['vernacular uniform title']
    end
    context 'unmatched 800' do
      let(:fixture_name) { 'unmatched880sTests.mrc' }
      it 'has the correct titles' do
        expect(select_by_id('4')[field]).to eq ['vern130a']
        expect(select_by_id('5')[field]).to eq ['vern240a']
      end
    end
  end
  describe 'title_sort' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    let(:field) { 'title_sort' }
    it 'has the correct titles' do
      # 130 (with non-filing)
      expect(select_by_id('130')[field]).to eq ['Snimm 130 4 nonfiling']
      expect(select_by_id('1306')[field]).to eq ['Sox on Fox 130 has sub 6']
      expect(select_by_id('888')[field]).to eq ['interspersed punctuation here']

      # 240
      expect(select_by_id('0240')[field]).to eq ['240 has sub 0']
      expect(select_by_id('24025')[field]).to eq ['240 has sub 2 and 5']

      # 130 and 240
      expect(select_by_id('130240')[field]).to eq ['Hoos Foos 130 and 240']
    end
  end

  describe 'uniform_title_display_struct' do
    subject(:result) { indexer.map_record(record) }
    let(:field) { 'uniform_title_display_struct' }
    let(:record) { MARC::XMLReader.new(StringIO.new(marcxml)).to_a.first }
    let(:parsed_field) { result[field].map { |x| JSON.parse(x, symbolize_names: true) } }

    context 'with a $h' do
      let(:marcxml) do
        <<-xml
          <record>
            <datafield tag="240" ind1=" " ind2=" ">
              <subfield code="a">Instrumental music</subfield>
              <subfield code="b">Selections</subfield>
              <subfield code="h">[print/digital].</subfield>
            </datafield>
          </record>
        xml
      end

      it 'does not link $h' do
        expect(parsed_field.first[:fields].length).to eq 1
        expect(parsed_field.first[:fields].first[:field]).to include link_text: 'Instrumental music Selections',
                                                                      post_text: '[print/digital].'
      end
    end

    context 'with subfields with certain punctuation' do
      let(:marcxml) do
        <<-xml
          <record>
            <datafield tag="240" ind1=" " ind2=" ">
              <subfield code="a">Instrumental music.</subfield>
              <subfield code="b">Selections</subfield>
            </datafield>
          </record>
        xml
      end

      it 'does not link subfields after a certain punctuation' do
        expect(parsed_field.first[:fields].length).to eq 1
        expect(parsed_field.first[:fields].first[:field]).to include link_text: 'Instrumental music.',
                                                                      post_text: 'Selections'
      end
    end

    context 'with subfield 0 + 1 data' do
      subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
      let(:records) { [record] }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '00988nas a2200193z  4500'
          r.append(MARC::DataField.new('130', ' ', ' ',
            MARC::Subfield.new('0', 'http://example.com/authority_130'),
            MARC::Subfield.new('1', 'http://example.com/rwo_130'),
            MARC::Subfield.new('a', '130a')
          ))
          r.append(MARC::DataField.new('240', ' ', ' ',
            MARC::Subfield.new('0', 'http://example.com/authority_240'),
            MARC::Subfield.new('1', 'http://example.com/rwo_240'),
            MARC::Subfield.new('a', '240a')
          ))
        end
      end
      let(:result) { results.first }
      let(:field) { 'uniform_title_display_struct' }

      it 'has identifiers' do
        struct = result[field].map { |x| JSON.parse(x, symbolize_names: true) }.first
        expect(struct).to include fields: [
          hash_including(
            authorities: ['http://example.com/authority_130'],
            rwo: ['http://example.com/rwo_130'],
          )
        ]

        expect(result['uniform_title_authorities_ssim']).to eq [
          'http://example.com/authority_130', 'http://example.com/rwo_130',
          'http://example.com/authority_240', 'http://example.com/rwo_240'
        ]
      end
    end
  end
end
