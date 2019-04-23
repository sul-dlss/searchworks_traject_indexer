RSpec.describe 'Author config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end

  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }
  let(:fixture_name) { 'authorTests.mrc' }
  subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }

  describe 'author_1xx_search' do
    let(:field) { 'author_1xx_search' }

    it 'has all subfields from 100' do
      result = select_by_id('100search')[field]
      expect(result).to eq ['100a 100b 100c 100d 100g 100j 100q 100u']
      expect(results).not_to include hash_including(field => ['100e'])
      expect(results).not_to include hash_including(field => ['none'])
    end

    it 'has all subfields from 110' do
      result = select_by_id('110search')[field]
      expect(result).to eq ['110a 110b 110c 110d 110g 110n 110u']
      expect(results).not_to include hash_including(field => ['110e'])
      expect(results).not_to include hash_including(field => ['110f'])
      expect(results).not_to include hash_including(field => ['110k'])
      expect(results).not_to include hash_including(field => ['none'])
    end

    it 'has all subfields from 111' do
      result = select_by_id('111search')[field]
      expect(result).to eq ['111a 111c 111d 111e 111g 111j 111n 111q 111u']
      expect(results).not_to include hash_including(field => ['111i'])
      expect(results).not_to include hash_including(field => ['none'])
    end

    it 'does not include linked 880 fields' do
      result = select_by_id('987666')[field]
      expect(result).to eq ['Beijing Shi fu nü lian he hui.']
      expect(results).not_to include hash_including(field => ['Beijing Shi fu nü lian he hui.', '北京市妇女联合会.'])
      expect(results).not_to include hash_including(field => ['北京市妇女联合会.'])
    end

    it 'does not include multiple 1XX fields' do
      result = select_by_id('12737620')[field]
      expect(result).to eq ['Institute of Foreign Policy Studies (Kolkata, India),']
    end
  end

  describe 'vern_author_1xx_search' do
    let(:fixture_name) { 'vernacularSearchTests.mrc' }
    let(:field) { 'vern_author_1xx_search' }
    it 'has all subfields from linked 100' do
      result = select_by_id('100VernSearch')[field]
      expect(result).to eq ['vern100a vern100b vern100c vern100d vern100g vern100j vern100q vern100u']
      expect(results).not_to include hash_including(field => ['vern100e'])
      expect(results).not_to include hash_including(field => ['none'])
    end

    it 'has all subfields from linked 110' do
      result = select_by_id('110VernSearch')[field]
      expect(result).to eq ['vern110a vern110b vern110c vern110d vern110g vern110n vern110u']
      expect(results).not_to include hash_including(field => ['vern110e'])
      expect(results).not_to include hash_including(field => ['vern110f'])
      expect(results).not_to include hash_including(field => ['vern110k'])
      expect(results).not_to include hash_including(field => ['none'])
    end

    it 'has all subfields from linked 111' do
      result = select_by_id('111VernSearch')[field]
      expect(result).to eq ['vern111a vern111c vern111d vern111e vern111g vern111j vern111n vern111q vern111u']
      expect(results).not_to include hash_including(field => ['vern111i'])
      expect(results).not_to include hash_including(field => ['none'])
    end
  end

  describe 'author_7xx_search' do
    let(:field) { 'author_7xx_search' }

    it 'has all subfields from 700, 720, and 796' do
      result = select_by_id('7xxPersonSearch')[field]
      expect(result).to eq ['700a 700b 700c 700d 700g 700j 700q 700u', '720a 720e', '796a 796b 796c 796d 796g 796j 796q 796u']
      expect(results).not_to include hash_including(field => ['700e'])
      expect(results).not_to include hash_including(field => ['796e'])
      expect(results).not_to include hash_including(field => ['none'])
    end
  end

  describe 'vern_author_7xx_search' do
    let(:fixture_name) { 'vernacularSearchTests.mrc' }
    let(:field) { 'vern_author_7xx_search' }

    context 'personal name fields' do
      it 'has all subfields from linked 700, 720, and 796' do
        result = select_by_id('7xxVernPersonSearch')[field]
        expect(result).to eq ['vern700a vern700b vern700c vern700d vern700g vern700j vern700q vern700u',
                              'vern720a vern720e',
                              'vern796a vern796b vern796c vern796d vern796g vern796j vern796q vern796u']
        expect(results).not_to include hash_including(field => ['vern700e'])
        expect(results).not_to include hash_including(field => ['vern796e'])
        expect(results).not_to include hash_including(field => ['none'])
      end

      it 'has subfields that overlap with title' do
        result = select_by_id('7xxLowVernSearch')[field][0]
        expect(result).to eq 'vern700g vern700j nope'

        ['7xxLowVernSearch', '7xxVernPersonSearch'].each do |id|
          expect(select_by_id(id)[field].first).to include 'vern700g vern700j'
        end

        expect(select_by_id('79xVernSearch')[field].first).to include 'vern796g vern796j'
      end
    end

    context 'corporate name fields' do
      it 'has all subfields from linked 710 and 797' do
        result = select_by_id('7xxVernCorpSearch')[field]
        expect(result).to eq ['vern710a vern710b vern710c vern710d vern710g vern710n vern710u',
                              'vern797a vern797b vern797c vern797d vern797g vern797n vern797u']
        expect(results).not_to include hash_including(field => ['vern710e'])
        expect(results).not_to include hash_including(field => ['vern710f'])
        expect(results).not_to include hash_including(field => ['vern710k'])
        expect(results).not_to include hash_including(field => ['vern797e'])
        expect(results).not_to include hash_including(field => ['vern797f'])
        expect(results).not_to include hash_including(field => ['vern797k'])
        expect(results).not_to include hash_including(field => ['none'])
      end

      it 'has subfields that overlap with title' do
        result = select_by_id('7xxLowVernSearch')[field][1]
        expect(result).to eq 'vern710d vern710g vern710n'

        result = select_by_id('79xVernSearch')[field][1]
        expect(result).to eq 'vern797d vern797g vern797n'
      end
    end

    context 'meeting name fields' do
      it 'has all subfields from linked 711 and 798' do
        result = select_by_id('7xxVernMeetingSearch')[field]
        expect(result).to eq ['vern711a vern711c vern711d vern711e vern711g vern711j vern711n vern711q vern711u',
                              'vern798a vern798c vern798d vern798e vern798g vern798j vern798n vern798q vern798u']
        expect(results).not_to include hash_including(field => ['vern711i'])
        expect(results).not_to include hash_including(field => ['vern798i'])
        expect(results).not_to include hash_including(field => ['none'])
      end

      it 'has subfields that overlap with title' do
        result = select_by_id('7xxLowVernSearch')[field][2]
        expect(result).to eq 'vern711g nope vern711n'

        result = select_by_id('79xVernSearch')[field][2]
        expect(result).to eq 'vern798e vern798g nope vern798n'
      end
    end
  end

  describe 'author_8xx_search' do
    let(:field) { 'author_8xx_search' }

    it 'has all subfields from 800' do
      result = select_by_id('800search')[field]
      expect(result).to eq ['800a 800b 800c 800d 800e 800g 800j 800q 800u']
    end

    it 'has all subfields from 810' do
      result = select_by_id('810search')[field]
      expect(result).to eq ['810a 810b 810c 810d 810e 810g 810n 810u']
      expect(results).not_to include hash_including(field => ['810f'])
      expect(results).not_to include hash_including(field => ['810k'])
      expect(results).not_to include hash_including(field => ['none'])
    end

    it 'has all subfields from 811' do
      result = select_by_id('811search')[field]
      expect(result).to eq ['811a 811c 811d 811e 811g 811j 811n 811q 811u']
    end
  end

  describe 'vern_author_8xx_search' do
    let(:fixture_name) { 'vernacularSearchTests.mrc' }
    let(:field) { 'vern_author_8xx_search' }

    context 'personal name fields' do
      it 'has all subfields from linked 800' do
        result = select_by_id('800VernSearch')[field]
        expect(result).to eq ['vern800a vern800b vern800c vern800d vern800e vern800g vern800j vern800q vern800u']
      end

      it 'has subfields that overlap with title' do
        result = select_by_id('8xxVernSearch')[field][0]
        expect(result).to eq 'vern800g vern800j nope'

        ['800VernSearch', '8xxVernSearch'].each do |id|
          expect(select_by_id(id)[field].first).to include 'vern800g vern800j'
        end

        expect(select_by_id('8xxVernSearch')[field].first).to include 'vern800g vern800j'
      end
    end

    context 'corporate name fields' do
      it 'has all subfields from linked 810' do
        result = select_by_id('810VernSearch')[field]
        expect(result).to eq ['vern810a vern810b vern810c vern810d vern810e vern810g vern810n vern810u']
        expect(results).not_to include hash_including(field => ['vern810f'])
        expect(results).not_to include hash_including(field => ['vern810k'])
        expect(results).not_to include hash_including(field => ['none'])
      end

      it 'has subfields that overlap with title' do
        result = select_by_id('8xxVernSearch')[field][1]
        expect(result).to eq 'vern810d vern810g vern810n'
      end
    end

    context 'meeting name fields' do
      it 'has all subfields from linked 811' do
        result = select_by_id('811VernSearch')[field]
        expect(result).to eq ['vern811a vern811c vern811d vern811e vern811g vern811j vern811n vern811q vern811u']
      end

      it 'has subfields that overlap with title' do
        result = select_by_id('8xxVernSearch')[field][2]
        expect(result).to eq 'vern811g nope vern811n'
      end
    end
  end

  describe 'author_person_facet' do
    let(:field) { 'author_person_facet' }

    it 'is just the 100xx field' do
      result = select_by_id('100search')[field]
      expect(result).to eq ['100a 100b 100c 100d 100q']
    end

    it 'removes trailing period that isn\'t an initial' do
      result = select_by_id('345228')[field]
      expect(result).to eq ['Bashkov, Vladimir']

      result = select_by_id('690002')[field]
      expect(result).to eq ['Wallin, J. E. Wallace (John Edward Wallace), b. 1876']

      result = select_by_id('4428936')[field]
      expect(result).to eq ['Zagarrio, Vito']

      result = select_by_id('1261173')[field]
      expect(result).to eq ['Johnson, Samuel, 1649-1703']
    end

    it 'leaves in trailing period for B.C. acronym' do
      result = select_by_id('8634')[field]
      expect(result).to eq ['Sallust, 86-34 B.C.']
    end

    it 'leaves in trailing period for author initials' do
      result = select_by_id('harrypotter')[field]
      expect(result).to eq ['Heyman, David', 'Rowling, J. K.']
    end

    it 'leaves in trailing hyphen for birth/death date' do
      result = select_by_id('919006')[field]
      expect(result).to eq ['Oeftering, Michael, 1872-']
    end

    it 'removes trailing comma' do
      result = select_by_id('7651581')[field]
      expect(result).to eq ['Coutinho, Frederico dos Reys']
    end

    it 'removes trailing period for hyphen, comma, period combo' do
      result = select_by_id('700friedman')[field]
      expect(result).to eq ['Friedman, Eli A., 1933-']
    end

    it 'removes trailing period when fuller form of name is in parentheses' do
      result = select_by_id('700sayers')[field]
      expect(result).to eq ['Whimsey, Peter', 'Sayers, Dorothy L. (Dorothy Leigh), 1893-1957']
    end
  end

  describe 'author_other_facet' do
    let(:field) { 'author_other_facet' }

    it 'is just the 110xx field' do
      result = select_by_id('110search')[field]
      expect(result).to eq ['110a 110b 110c 110d 110n']
    end

    it 'removes trailing period that isn\'t an initial' do
      # field 110
      result = select_by_id('110foo')[field]
      expect(result).to eq ['SAFE Association (U.S.). Symposium']
      # field 110
      result = select_by_id('NYPL')[field]
      expect(result).to eq ['New York Public Library']
      # field 110
      result = select_by_id('110710corpname')[field][0]
      expect(result).to eq 'Thelma'
    end

    it 'removes trailing period preceded by 4-digit year' do
      # field 710
      result = select_by_id('110710corpname')[field][1]
      expect(result).to eq 'Roaring Woman, Louise. 2000-2001'
    end

    it 'removes trailing period when preceded by a close parenthesis' do
      # field 111
      result = select_by_id('111faim')[field]
      expect(result).to eq ['FAIM (Forum)']
      # field 111 sub a n d c
      result = select_by_id('5666387')[field]
      expect(result).to eq ['International Jean Sibelius Conference (3rd : 2000 : Helsinki, Finland)']
      # field 710
      result = select_by_id('987666')[field][1]
      expect(result).to eq '(this was a value in a non-latin script)'

      result = select_by_id('710corpname')[field][1]
      expect(result).to eq 'Warner Bros. Pictures (1969- )'

      # field 711
      result = select_by_id('711')[field]
      expect(result).to eq ['European Conference on Computer Vision (2006 : Graz, Austria)']
    end

    it 'leaves in trailing period for abbreviations' do
      # field 710
      result = select_by_id('6280316')[field][1]
      expect(result).to eq 'Julius Bien & Co.'

      result = select_by_id('57136914')[field]
      expect(result).to eq ['NetLibrary, Inc.']
    end

    it 'leaves in trailing period for Dept. abbreviation' do
      pending 'legacy test doesn\'t check for punctuation for Dept.; solrmarc-sw doesn\'t handle it correctly either.'
      # field 710
      result = select_by_id('6280316')[field][0]
      expect(result).to eq 'United States. War Dept.'
    end

    it 'removes leading whitespace' do
      # field 710
      result = select_by_id('710corpname')[field][0]
      expect(result).to eq 'Heyday Films'
    end
  end

  describe 'author_person_display' do
    let(:field) { 'author_person_display' }

    it 'is just the 100xx field' do
      result = select_by_id('100search')[field]
      expect(result).to eq ['100a 100b 100c 100d 100q']
    end

    it 'removes trailing period for field 110a' do
      result = select_by_id('345228')[field]
      expect(result).to eq ['Bashkov, Vladimir']
    end

    it 'retains trailing hyphen for 100ad' do
      result = select_by_id('919006')[field]
      expect(result).to eq ['Oeftering, Michael, 1872-']
    end

    it 'removes trailing comma for 100ae (e is not indexed)' do
      result = select_by_id('7651581')[field]
      expect(result).to eq ['Coutinho, Frederico dos Reys']
    end

    it 'removes trailing period for field 100aqd' do
      result = select_by_id('690002')[field]
      expect(result).to eq ['Wallin, J. E. Wallace (John Edward Wallace), b. 1876']
    end

    it 'removes trailing period for field 100ad' do
      result = select_by_id('1261173')[field]
      expect(result).to eq ['Johnson, Samuel, 1649-1703']
    end

    it 'leaves in trailing period for B.C. acronym' do
      result = select_by_id('8634')[field]
      expect(result).to eq ['Sallust, 86-34 B.C.']
    end

    it '100a with unlinked 880' do
      result = select_by_id('1006')[field]
      expect(result).to eq ['Sox on Fox']
    end
  end

  describe 'vern_author_person_display' do
    let(:fixture_name) { 'vernacularNonSearchTests.mrc' }
    let(:field) { 'vern_author_person_display' }
    it 'has correct vernacular author display' do
      result = select_by_id('trailingPunct')[field]
      expect(result).to eq ['vernacular internal colon : vernacular ending period']
    end
  end

  describe 'author_person_full_display' do
    let(:field) { 'author_person_full_display' }
    it 'has correct display for 100ae' do
      result = select_by_id('7651581')[field]
      expect(result).to eq ['Coutinho, Frederico dos Reys, ed.']
    end

    context 'display fields test file' do
      let(:fixture_name) { 'displayFieldsTests.mrc' }
      it 'has correct display for 100ac' do
        result = select_by_id('1001')[field]
        expect(result).to eq ['Seuss, Dr.']
      end

      it 'has correct display for 100aqd' do
        result = select_by_id('1002')[field]
        expect(result).to eq ['Fowler, T. M. (Thaddeus Mortimer) 1842-1922.']
      end

      it 'has correct display for 100a40' do
        result = select_by_id('1003')[field]
        expect(result).to eq ['Bach, Johann Sebastian.']
      end

      it 'uses only first 100 field for display' do
        result = select_by_id('1004')[field]
        expect(result).to eq ['Fowler, T. M. (Thaddeus Mortimer) 1842-1922.']
      end
    end

    context 'vernacular non search test file' do
      let(:fixture_name) { 'vernacularNonSearchTests.mrc' }
      it 'has correct display for RTL script' do
        result = select_by_id('RtoL2')[field]
        expect(result).to eq ['LTR a : LTR b, LTR c']
      end
    end
  end

  describe 'vern_author_person_full_display' do
    let(:field) { 'vern_author_person_full_display' }
    let(:fixture_name) { 'vernacularNonSearchTests.mrc' }
    it 'has correct display for RTL script' do
      pending 'legacy test doesn\'t run but solrmarc-sw returns incorrect display too'
      # "vern_author_person_display":"vern (RTL?) a (first) : vern (RTL?) b (second), vern (RTL?) c (third)"
      result = select_by_id('RtoL2')[field]
      expect(result).to eq ['vern (RTL?) c (third) ,vern (RTL?) b (second) : vern (RTL?) a (first)']
    end
  end

  describe 'author_corp_display' do
    let(:field) { 'author_corp_display' }
    it 'has correct display for 110a' do
      result = select_by_id('NYPL')[field]
      expect(result).to eq ['New York Public Library.']
    end

    it 'has correct display for 110abbb' do
      result = select_by_id('5511738')[field]
      expect(result).to eq ['United States. Congress. House. Committee on Agriculture. Subcommittee on Department Operations, Oversight, Nutrition, and Forestry.']
    end

    it 'has correct display for 110abn' do
      result = select_by_id('4578538')[field]
      expect(result).to eq ['Stanford University. Stanford Electronics Laboratories. SEL-69-048.']
    end

    context 'display fields test file' do
      let(:fixture_name) { 'displayFieldsTests.mrc' }
      it 'has correct display for 110abndb' do
        result = select_by_id('110')[field]
        expect(result).to eq ['United States. Congress (97th, 2nd session : 1982). House.']
      end
    end
  end

  describe 'vern_author_corp_display' do
    let(:field) { 'vern_author_corp_display' }
    it 'has correct display for linked 110a' do
      result = select_by_id('987666')[field]
      expect(result).to eq ['北京市妇女联合会.']
    end
  end

  describe 'author_meeting_display' do
    let(:field) { 'author_meeting_display' }
    it 'has correct display for 111a' do
      result = select_by_id('111faim')[field]
      expect(result).to eq ['FAIM (Forum).']
    end

    it 'has correct display for 111andc' do
      result = select_by_id('5666387')[field]
      expect(result).to eq ['International Jean Sibelius Conference (3rd : 2000 : Helsinki, Finland)']
    end
  end

  describe 'vern_author_meeting_display' do
    let(:field) { 'vern_author_meeting_display' }
    let(:fixture_name) { 'vernacularNonSearchTests.mrc' }
    it 'has correct display for linked 111a' do
      result = select_by_id('MeetingAuthorVern')[field]
      expect(result).to eq ['vernacular mtg name author']
    end
  end

  describe 'author_sort' do
    let(:field) { 'author_sort' }
    MAX_CODE_POINT = 0x10FFFF.chr(Encoding::UTF_8) + ' '
    context 'has the correct fields:' do
      it '100 then 245' do
        result = select_by_id('345228')[field]
        expect(result).to eq ['Bashkov Vladimir 100a only']
      end

      it '110 then 245' do
        result = select_by_id('110710corpname')[field]
        expect(result).to eq ['Thelma facets from 110 and 710']
      end

      it '111 then 245' do
        result = select_by_id('111faim')[field]
        expect(result).to eq ['FAIM Forum mtg name facet from 111 should be FAIM Forum']
      end

      it 'no 1xx but 240 then 245' do
        result = select_by_id('666')[field]
        expect(result).to eq [MAX_CODE_POINT + 'De incertitudine et vanitate scientiarum German ZZZZ']
      end

      it '100 then 240 then 245' do
        result = select_by_id('100240')[field]
        expect(result).to eq ['Hoos Foos Marvin OGravel Balloon Face 100 and 240']
      end

      it 'no 1xx no 240, 245 only' do
        result = select_by_id('245only')[field]
        expect(result).to eq [MAX_CODE_POINT + '245 no 100 or 240']
      end

      it 'no subfield e from 100' do
        result = select_by_id('7651581')[field]
        expect(result).to eq ['Coutinho Frederico dos Reys ae']
      end

      it 'no subfield e from 110' do
        result = select_by_id('110search')[field]
        expect(result).to eq ['110a 110b 110c 110d 110f 110g 110k 110n none 110u 110 search subfields']
      end

      it 'no subfield j from 111' do
        result = select_by_id('111search')[field]
        expect(result).to eq ['111a none 111c 111d 111e none 111g 111i 111n 111q 111u 111 search subfields']
      end
    end

    context 'ignores non-filing characters' do
      it '0 non-filing in the 240 field' do
        result = select_by_id('2400')[field]
        expect(result).to eq [MAX_CODE_POINT + 'Wacky 240 0 nonfiling']
      end
      it '2 non-filing in the 240 field' do
        result = select_by_id('2402')[field]
        expect(result).to eq [MAX_CODE_POINT + 'Wacky 240 2 nonfiling']
      end
      it '7 non-filing in the 240 field' do
        result = select_by_id('2407')[field]
        expect(result).to eq [MAX_CODE_POINT + 'Tacky 240 7 nonfiling']
      end
      it 'in the 245 field and a 240 field without non-filing characters' do
        result = select_by_id('575946')[field]
        expect(result).to eq [MAX_CODE_POINT + 'De incertitudine et vanitate scientiarum German Ruckzug der biblischen Prophetie von der neueren Geschichte']
      end
      it 'in the 245 field' do
        result = select_by_id('1261174')[field]
        expect(result).to eq [MAX_CODE_POINT + 'second part of the Confutation of the Ballancing letter']
      end
      it 'in the 240 and 245 field' do
        result = select_by_id('892452')[field]
        expect(result).to eq [MAX_CODE_POINT + 'Wacky 240 245 nonfiling']
      end
    end

    context 'handles numeric subfields correctly' do
      it 'in the 100 field' do
        result = select_by_id('1006')[field]
        expect(result).to eq ['Sox on Fox 100 has sub 6']
      end

      it 'in the 240 field' do
        result = select_by_id('0240')[field]
        expect(result).to eq [MAX_CODE_POINT + 'sleep little fishies 240 has sub 0']
      end

      it 'in the 240 field with multiple numeric subfields' do
        result = select_by_id('24025')[field]
        expect(result).to eq [MAX_CODE_POINT + 'la di dah 240 has sub 2 and 5']
      end

      it 'in the 245 field' do
        result = select_by_id('2458')[field]
        expect(result).to eq [MAX_CODE_POINT + '245 has sub 8']
      end
    end

    context 'ignores punctuation correctly:' do
      it 'quotation marks' do
        result = select_by_id('111')[field]
        expect(result).to eq ['ind 0 leading quotes in 100']
      end

      it 'leading hyphens' do
        result = select_by_id('333')[field]
        expect(result).to eq [MAX_CODE_POINT + 'ind 0 leading hyphens in 240']
      end

      it 'leading elipsis' do
        result = select_by_id('444')[field]
        expect(result).to eq [MAX_CODE_POINT + 'ind 0 leading elipsis in 240']
      end

      it 'leading quotation mark and elipsis' do
        result = select_by_id('555')[field]
        expect(result).to eq ['ind 0 leading quote elipsis in 100']
      end

      it 'non-filing characters with leading quotation mark and elipsis' do
        result = select_by_id('777')[field]
        expect(result).to eq [MAX_CODE_POINT + 'ind 4 leading quote elipsis in 240']
      end

      it 'interspersed punctuation across fields' do
        result = select_by_id('888')[field]
        expect(result).to eq ['interspersed punctuation here']
      end

      it 'interspersed punctuation in 100 field' do
        result = select_by_id('999')[field]
        expect(result).to eq ['everything in 100']
      end
    end
  end

  describe 'author_struct' do
    let(:field) { 'author_struct' }
    it 'aggregates data from 100 fields' do
      result = select_by_id('100search')[field].map { |x| JSON.parse(x, symbolize_names: true) }
      expect(result).to include creator: [{
        link: '100a 100b 100c 100d none 100g 100j 100q 100u',
        search: '100a 100b 100c 100d none 100g 100j 100q 100u',
        post_text: '100e'
      }]
    end
    it 'aggregates data from 110 fields' do
      result = select_by_id('110search')[field].map { |x| JSON.parse(x, symbolize_names: true) }
      expect(result).to include corporate_author: [{
        link: '110a 110b 110c 110d 110f 110g 110k 110n none 110u',
        search: '110a 110b 110c 110d 110f 110g 110k 110n none 110u',
        post_text: '110e'
      }]
    end
    it 'aggregates data from 111 fields' do
      result = select_by_id('111search')[field].map { |x| JSON.parse(x, symbolize_names: true) }
      expect(result).to include meeting: [{
        link: '111a none 111c 111d 111e none 111g 111i 111n 111q 111u',
        search: '111a none 111c 111d 111e none 111g 111i 111n 111q 111u',
        post_text: '111e 111j'
      }]
    end

    it 'has aggregates data from 7xx fields' do
      result = select_by_id('7xxPersonSearch')[field].map { |x| JSON.parse(x, symbolize_names: true) }
      expect(result).to include contributors: array_including(
        hash_including(
          link: '700a 700b 700c 700d none 700g 700j 700q 700u',
          search: '"700a 700b 700c 700d none 700g 700j 700q 700u"',
          pre_text: '',
          post_text: '700e'
        )
      )
    end

    context 'with subfield 0 + 1 data' do
      let(:records) { [record] }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '00988nas a2200193z  4500'
          r.append(MARC::DataField.new('100', ' ', ' ',
            MARC::Subfield.new('0', 'http://example.com/authority_100'),
            MARC::Subfield.new('1', 'http://example.com/rwo_100'),
            MARC::Subfield.new('a', '100a')
          ))
          r.append(MARC::DataField.new('110', ' ', ' ',
            MARC::Subfield.new('0', 'http://example.com/authority_110'),
            MARC::Subfield.new('1', 'http://example.com/rwo_110'),
            MARC::Subfield.new('a', '110a')
          ))
          r.append(MARC::DataField.new('111', ' ', ' ',
            MARC::Subfield.new('0', 'http://example.com/authority_111'),
            MARC::Subfield.new('1', 'http://example.com/rwo_111'),
            MARC::Subfield.new('a', '111a')
          ))
          r.append(MARC::DataField.new('700', ' ', ' ',
            MARC::Subfield.new('0', 'http://example.com/authority_700'),
            MARC::Subfield.new('1', 'http://example.com/rwo_700'),
            MARC::Subfield.new('a', '700a')
          ))
        end
      end
      let(:result) { results.first }

      it 'has identifiers' do
        struct = result[field].map { |x| JSON.parse(x, symbolize_names: true) }.first
        expect(struct).to include creator: [{
          link: '100a',
          search: '100a',
          authorities: ['http://example.com/authority_100'],
          rwo: ['http://example.com/rwo_100'],
        }]
        expect(struct).to include corporate_author: [{
          link: '110a',
          search: '110a',
          authorities: ['http://example.com/authority_110'],
          rwo: ['http://example.com/rwo_110'],
        }]
        expect(struct).to include meeting: [{
          link: '111a',
          search: '111a',
          authorities: ['http://example.com/authority_111'],
          rwo: ['http://example.com/rwo_111'],
        }]
        expect(struct).to include contributors: [
          hash_including(
            authorities: ['http://example.com/authority_700'],
            rwo: ['http://example.com/rwo_700'],
          )
        ]
      end
    end
  end
end
