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
      result = select_by_id('987666')[field][2]
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
end
