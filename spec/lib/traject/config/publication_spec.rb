# frozen_string_literal: true

RSpec.describe 'Publication config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/marc_config.rb')
    end
  end

  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }
  let(:fixture_name) { 'publicationTests.mrc' }
  subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }

  describe 'pub_search' do
    let(:field) { 'pub_search' }

    it 'has the right data' do
      expect(select_by_id('260aunknown')[field]).to eq ['Insight Press']
      expect(select_by_id('260bunknown')[field]).to eq ['Victoria, B.C.']

      # 		// 260ab
      expect(select_by_id('260ababc')[field]).to eq ['Paris : Gauthier-Villars ; Chicago : University of Chicago Press']
      expect(select_by_id('260abbc')[field]).to eq ['Washington, D.C. : first b : second b U.S. G.P.O.']
      expect(select_by_id('260ab3')[field]).to eq ['London : Vogue']
      expect(select_by_id('260crightbracket')[field]).to eq ['i.e. Bruxelles : Moens']
    end

    it 'skips 260a s.l, 260b s.n.' do
      expect(select_by_id('260abunknown')[field]).to eq nil

      # 260a contains s.l. (unknown - sin location, presumably)
      expect(select_by_id('260aunknown')[field]).to eq ['Insight Press']
      expect(select_by_id('260abaslbc')[field]).to eq ['[Philadelphia] : Some name another name']
      #
      # 260b contains s.n. (unknown - sin name, presumably)
      expect(select_by_id('260bunknown')[field]).to eq ['Victoria, B.C.']
    end

    context 'with a record with a 264' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('a', '264a')))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('b', '264b')))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('c', '264c')))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('a', '264a'),
                                       MARC::Subfield.new('b', '264b')))
        end
      end

      it 'maps all the data' do
        expect(result[field]).to eq ['264a', '264b', '264a 264b']
      end
    end

    context 'with a record with a 260 and a 264' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('a', '264a')))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('b', '264b')))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('c', '264c')))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('a', '264a'),
                                       MARC::Subfield.new('b', '264b')))
          r.append(MARC::DataField.new('260', ' ', ' ',
                                       MARC::Subfield.new('a', '260a')))
        end
      end

      it 'maps all the data' do
        expect(result[field]).to eq ['264a', '264b', '264a 264b', '260a']
      end
    end

    context 'with unknown-ish phrases' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('a', '[Place of publication not identified] :'),
                                       MARC::Subfield.new('b', 'b1')))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('a', '[Place of Production not identified] :'),
                                       MARC::Subfield.new('b', 'b2')))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('a', 'Place of manufacture Not Identified'),
                                       MARC::Subfield.new('b', 'b3')))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('a', '[Place of distribution not identified]')))
        end
      end

      it 'maps all the data' do
        expect(result[field]).to eq %w[b1 b2 b3]
      end
    end

    context 'with unknown-ish phrases' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('a', 'a1'),
                                       MARC::Subfield.new('b', '[publisher not identified], ')))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('a', 'a2'),
                                       MARC::Subfield.new('b', '[Producer not identified]')))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('a', 'a3'),
                                       MARC::Subfield.new('b', 'Manufacturer Not Identified')))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('b', '[distributor not identified]')))
        end
      end

      it 'maps all the data' do
        expect(result[field]).to eq %w[a1 a2 a3]
      end
    end
  end

  describe 'vern_pub_search' do
    let(:field) { 'vern_pub_search' }

    it 'has the right data' do
      expect(select_by_id('vern260abc')[field]).to eq ['vern260a : vern260b,']
      expect(select_by_id('vern260abcg')[field]).to eq ['vern260a : vern260b,']
    end

    context 'with some linked fields' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('a', '264a'),
                                       MARC::Subfield.new('6', '880-01')))
          r.append(MARC::DataField.new('880', ' ', ' ',
                                       MARC::Subfield.new('6', '264-01'),
                                       MARC::Subfield.new('a', '880a for 264'),
                                       MARC::Subfield.new('b', '880b for 264'),
                                       MARC::Subfield.new('c', '880c for 264')))
        end
      end

      it 'maps all the data' do
        expect(result[field]).to eq ['880a for 264 880b for 264']
      end
    end
  end

  describe 'pub_country' do
    let(:field) { 'pub_country' }

    it 'maps the right data' do
      expect(select_by_id('008mdu')[field]).to eq ['Maryland, United States']
      expect(select_by_id('008ja')[field]).to eq ['Japan']
    end

    it 'skips these codes' do
      expect(select_by_id('008vp')[field]).to eq nil # "Various places"
      expect(select_by_id('008xx')[field]).to eq nil # "No place, unknown, or undetermined"
    end
  end

  describe 'pub_date' do
    let(:field) { 'pub_date' }
    let(:fixture_name) { 'pubDateTests.mrc' }

    context 'with unknown dates' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('c', '[Date of publication not identified] :')))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('c', '[Date of Production not identified]')))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('c', 'Date of manufacture Not Identified')))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('c', '[Date of distribution not identified]')))
        end
      end

      it 'maps all the data' do
        expect(result[field]).to eq nil
      end
    end

    it 'is ignores dates later than the current year + 10' do
      expect(results).not_to include(hash_including(field => include('9999')))
      expect(results).not_to include(hash_including(field => include('6666')))
      expect(results).not_to include(hash_including(field => include('22nd century')))
      expect(results).not_to include(hash_including(field => include('23rd century')))
      expect(results).not_to include(hash_including(field => include('24th century')))
      expect(results).not_to include(hash_including(field => include('8610s')))
    end

    context 'with dates greater than the current year + 10' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('c', '9999')))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('c', '6666')))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('c', '22nd century')))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('c', '8610s')))
        end
      end

      it 'ignores all the bad data' do
        expect(result[field]).to eq nil
      end
    end

    it 'is ignores dates before 500 A.D.' do
      expect(results).not_to include(hash_including(field => include('0000')))
      expect(results).not_to include(hash_including(field => include('0019')))
      expect(results).not_to include(hash_including(field => include('0059')))
      expect(results).not_to include(hash_including(field => include('0197')))
      expect(results).not_to include(hash_including(field => include('204')))
    end

    context 'with dates greater than the current year + 10' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('c', '0000')))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('c', '0036')))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('c', '0197')))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('c', '0204')))
        end
      end

      it 'ignores all the bad data' do
        expect(result[field]).to eq nil
      end
    end

    it 'corrects invalid dates in the 008 by checking values in 260c' do
      expect(select_by_id('pubDate0059')[field]).to eq ['2005']
      expect(select_by_id('pubDate0197-1')[field]).to eq ['1970']
      expect(select_by_id('pubDate0197-2')[field]).to eq ['1970']
      expect(select_by_id('pubDate0500')[field]).to eq ['0500']
      expect(select_by_id('pubDate0801')[field]).to eq ['0801']
      expect(select_by_id('pubDate0960')[field]).to eq ['0960']
      expect(select_by_id('pubDate0963')[field]).to eq ['0963']
      expect(select_by_id('pubDate0204')[field]).to eq ['2004']
      expect(select_by_id('410024')[field]).to be_nil
    end

    {
      '2002' => '2002',
      '©2002' => '2002',
      'Ⓟ1983 ' => '1983',
      '[2011]' => '2011',
      '[1940?]' => '1940'
    }.each do |data_264c, expected|
      context 'with a year in the 264' do
        subject(:result) { indexer.map_record(record) }
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(MARC::DataField.new('264', ' ', ' ',
                                         MARC::Subfield.new('c', data_264c)))
          end
        end

        specify { expect(result[field]).to eq [expected] }
      end
    end

    {
      # FIXME: (from solrmarc): 'copyright 2005' => '2005',
      ['[2011]', '©2009'] => '2011',
      ['2012.', '©2009'] => '2012',
      '197?' => '1970',
      '[197?]' => '1970',
      %w[1560 1564] => '1560'
    }.each do |data_264c, expected|
      context 'with a garbage value in the 008, and year in the 264' do
        subject(:result) { indexer.map_record(record) }
        let(:record) do
          MARC::Record.new.tap do |r|
            Array(data_264c).each do |v|
              r.append(MARC::ControlField.new('008', '       0000'))
              r.append(MARC::DataField.new('264', ' ', ' ',
                                           MARC::Subfield.new('c', v)))
            end
          end
        end

        specify { expect(result[field]).to eq [expected] }
      end
    end

    context 'with garbage in both the 008 and 264c' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::ControlField.new('008', '       0000'))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('c', '0019')))
        end
      end

      specify { expect(result[field]).to eq nil }
    end

    context 'with both 260 and 264' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::ControlField.new('008', '       0000'))
          r.append(MARC::DataField.new('264', ' ', ' ',
                                       MARC::Subfield.new('c', '1260')))
          r.append(MARC::DataField.new('264', ' ', '1',
                                       MARC::Subfield.new('c', '1264')))
        end
      end

      it 'takes 264c if 2nd indicator is 1' do
        expect(result[field]).to eq ['1264']
      end
    end

    describe 'pub_date' do
      let(:fixture_name) { 'pubDateTests.mrc' }

      it 'maps the right data' do
        expect(select_by_id('firstDateOnly008')[field]).to eq ['2000']
        expect(select_by_id('bothDates008')[field]).to eq ['1964']
        expect(select_by_id('contRes')[field]).to eq ['1984']
        expect(select_by_id('pubDate195u')[field]).to eq ['1950s']
        expect(select_by_id('pubDate00uu')[field]).to eq ['1st century']
        expect(select_by_id('pubDate01uu')[field]).to eq ['2nd century']
        expect(select_by_id('pubDate02uu')[field]).to eq ['3rd century']
        expect(select_by_id('pubDate03uu')[field]).to eq ['4th century']
        expect(select_by_id('pubDate08uu')[field]).to eq ['9th century']
        expect(select_by_id('pubDate09uu')[field]).to eq ['10th century']
        expect(select_by_id('pubDate10uu')[field]).to eq ['11th century']
        expect(select_by_id('pubDate11uu')[field]).to eq ['12th century']
        expect(select_by_id('pubDate12uu')[field]).to eq ['13th century']
        expect(select_by_id('pubDate13uu')[field]).to eq ['14th century']
        expect(select_by_id('pubDate16uu')[field]).to eq ['17th century']
        expect(select_by_id('pubDate19uu')[field]).to eq ['20th century']
        expect(select_by_id('pubDate20uu')[field]).to eq ['21st century']

        #  No pub date when unknown
        expect(select_by_id('bothDatesBlank')[field]).to be_nil
        expect(select_by_id('pubDateuuuu')[field]).to be_nil
        # xuuu is unassigned
        expect(select_by_id('pubDate1uuu')[field]).to be_nil

        # future dates are ignored
        expect(select_by_id('pubDate21uu')[field]).to be_nil # ignored, not "22nd century"
        expect(select_by_id('pubDate22uu')[field]).to be_nil # ignored, not "23rd century"
        expect(select_by_id('pubDate23uu')[field]).to be_nil # ignored, not "24th century"
        expect(select_by_id('pubDate9999')[field]).to be_nil # ignored, not 9999
        expect(select_by_id('pubDate99uu')[field]).to be_nil # ignored, not "100th century'
        expect(select_by_id('pubDate6666')[field]).to be_nil # ignored, not 6666
        expect(select_by_id('pubDate861u')[field]).to be_nil # ignored, not 8610s
      end
    end
  end

  describe 'pub_year_tisim' do
    let(:fixture_name) { 'pubDateTests.mrc' }
    let(:field) { 'pub_year_tisim' }

    {
      [{ '260' => { 'subfields' => [{ 'c' => '1973' }] } }] => '1973',
      [{ '260' => { 'subfields' => [{ 'c' => '[1973]' }] } }] => '1973',
      [{ '260' => { 'subfields' => [{ 'c' => '1973]' }] } }] => '1973',
      [{ '260' => { 'subfields' => [{ 'c' => '[1973?]' }] } }] => '1973',
      [{ '260' => { 'subfields' => [{ 'c' => '[196-?]' }] } }] => '1960',
      [{ '260' => { 'subfields' => [{ 'c' => 'c1975.' }] } }] => '1975',
      [{ '260' => { 'subfields' => [{ 'c' => '[c1973]' }] } }] => '1973',
      [{ '260' => { 'subfields' => [{ 'c' => 'c1973]' }] } }] => '1973',
      [{ '260' => { 'subfields' => [{ 'c' => '1973 [i.e. 1974]' }] } }] => '1974',
      [{ '260' => { 'subfields' => [{ 'c' => '1971[i.e.1972]' }] } }] => '1972',
      [{ '260' => { 'subfields' => [{ 'c' => '1973 [i.e.1974]' }] } }] => '1974',
      [{ '260' => { 'subfields' => [{ 'c' => '1967 [i. e. 1968]' }] } }] => '1968'
    }.each do |fields, expected|
      context 'with a single value in a 260c' do
        let(:record) { MARC::Record.new_from_hash('leader' => '', 'fields' => fields) }
        subject(:result) { indexer.map_record(record) }

        it 'populates correctly' do
          expect(result[field]).to eq [expected]
        end
      end
    end

    context 'without a 008 or 260c usable value' do
      let(:fields) { [{ '250' => { 'subfields' => [{ 'c' => '[19--]' }] } }] }
      let(:record) { MARC::Record.new_from_hash('leader' => '', 'fields' => fields) }
      subject(:result) { indexer.map_record(record) }

      it 'is not populated' do
        expect(result[field]).to be_nil
      end
    end

    it 'maps the right data' do
      expect(select_by_id('pubDate195u')[field].uniq).to match_array ('1950'..'1982').to_a
      expect(select_by_id('bothDates008')[field]).to eq ['1964']
      expect(select_by_id('s195u')[field]).to eq ['1950']
      expect(select_by_id('pubDate0059')[field]).to eq ['2005']
      expect(select_by_id('j2005')[field]).to eq ['2005']
      expect(select_by_id('contRes')[field].uniq).to match_array ('1984'..Time.now.year.to_s).to_a
      expect(select_by_id('pubDate0197-1')[field]).to eq ['1970']
      expect(select_by_id('pubDate0197-2')[field]).to eq ['1970']

      # future dates are ignored/skipped
      expect(results).not_to include(hash_including(field => include('6666')))
      expect(results).not_to include(hash_including(field => include('8610')))
      expect(results).not_to include(hash_including(field => include('9999')))

      # dates before 500 are ignored/skipped
      expect(results).not_to include(hash_including(field => include('0000')))
      expect(results).not_to include(hash_including(field => include('0019')))
    end
  end

  describe 'imprint_display' do
    let(:field) { 'imprint_display' }

    context 'with both 250 + 260' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('250', ' ', ' ',
                                       MARC::Subfield.new('a', 'Special ed.')))
          r.append(MARC::DataField.new('260', ' ', ' ',
                                       MARC::Subfield.new('a', 'London :'),
                                       MARC::Subfield.new('b', 'William Heinemann,'),
                                       MARC::Subfield.new('c', '2012')))
        end
      end

      it 'displays the right value' do
        expect(result[field]).to eq ['Special ed. - London : William Heinemann, 2012']
      end
    end

    context 'with 250 alone' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('250', ' ', ' ',
                                       MARC::Subfield.new('a', 'Canadian ed. ='),
                                       MARC::Subfield.new('b', 'Éd. canadienne.')))
        end
      end

      it 'displays the right value' do
        expect(result[field]).to eq ['Canadian ed. = Éd. canadienne.']
      end
    end

    context 'with 250a alone' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('250', ' ', ' ',
                                       MARC::Subfield.new('a', 'Rev. as of Jan. 1, 1958.')))
        end
      end

      it 'displays the right value' do
        expect(result[field]).to eq ['Rev. as of Jan. 1, 1958.']
      end
    end

    context 'with both 250 + 260' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('250', ' ', ' ',
                                       MARC::Subfield.new('a', '3rd draft /'),
                                       MARC::Subfield.new('b', 'edited by Paul Watson.')))
          r.append(MARC::DataField.new('260', ' ', ' ',
                                       MARC::Subfield.new('a', 'London')))
        end
      end

      it 'displays the right value' do
        expect(result[field]).to eq ['3rd draft / edited by Paul Watson. - London']
      end
    end

    context 'with 250 linked' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('250', ' ', ' ',
                                       MARC::Subfield.new('6', '880-04'),
                                       MARC::Subfield.new('a', 'Di 1 ban.')))
          r.append(MARC::DataField.new('880', ' ', ' ',
                                       MARC::Subfield.new('6', '250-04'),
                                       MARC::Subfield.new('a', '第1版.')))
        end
      end

      it 'displays the right value' do
        expect(result[field]).to eq ['Di 1 ban. 第1版.']
      end
    end

    context 'with 260 linked' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('260', ' ', ' ',
                                       MARC::Subfield.new('6', '880-03'),
                                       MARC::Subfield.new('a', 'Or Yehudah :'),
                                       MARC::Subfield.new('b', 'Kineret :'),
                                       MARC::Subfield.new('b', 'Zemorah-Bitan,'),
                                       MARC::Subfield.new('c', 'c2013.')))
          r.append(MARC::DataField.new('880', ' ', ' ',
                                       MARC::Subfield.new('6', '260-03//r'),
                                       MARC::Subfield.new('a', 'אור יהודה :'),
                                       MARC::Subfield.new('b', 'כנרת :'),
                                       MARC::Subfield.new('b', 'זמורה־ביתן,'),
                                       MARC::Subfield.new('c', 'c2013.')))
        end
      end

      it 'displays the right value' do
        expect(result[field]).to eq ['Or Yehudah : Kineret : Zemorah-Bitan, c2013. אור יהודה : כנרת : זמורה־ביתן, c2013.']
      end
    end

    context 'with 260 linked (CJK)' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('260', ' ', ' ',
                                       MARC::Subfield.new('6', '880-02'),
                                       MARC::Subfield.new('a', '[Taibei] :'),
                                       MARC::Subfield.new('b', ' Gai hui,'),
                                       MARC::Subfield.new('c', 'Minguo 69 [1980]')))
          r.append(MARC::DataField.new('880', ' ', ' ',
                                       MARC::Subfield.new('6', '260-02'),
                                       MARC::Subfield.new('a', '[台北] :'),
                                       MARC::Subfield.new('b', '該會,'),
                                       MARC::Subfield.new('c', '民國69 [1980]')))
        end
      end

      it 'displays the right value' do
        expect(result[field]).to eq ['[Taibei] : Gai hui, Minguo 69 [1980] [台北] : 該會, 民國69 [1980]']
      end
    end

    context 'with 250 + 260 both linked' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('250', ' ', ' ',
                                       MARC::Subfield.new('6', '880-04'),
                                       MARC::Subfield.new('a', 'Di 1 ban.')))
          r.append(MARC::DataField.new('260', ' ', ' ',
                                       MARC::Subfield.new('6', '880-05'),
                                       MARC::Subfield.new('a', 'Shanghai Shi :'),
                                       MARC::Subfield.new('b', 'Shanghai shu dian chu ban she,'),
                                       MARC::Subfield.new('c', '2013.')))
          r.append(MARC::DataField.new('880', ' ', ' ',
                                       MARC::Subfield.new('6', '250-04'),
                                       MARC::Subfield.new('a', '第1版.')))
          r.append(MARC::DataField.new('880', ' ', ' ',
                                       MARC::Subfield.new('6', '260-05'),
                                       MARC::Subfield.new('a', '上海市 :'),
                                       MARC::Subfield.new('b', '上海书店出版社,'),
                                       MARC::Subfield.new('c', '2013.')))
        end
      end

      it 'displays the right value' do
        expect(result[field]).to eq ['Di 1 ban. 第1版. - Shanghai Shi : Shanghai shu dian chu ban she, 2013. 上海市 : 上海书店出版社, 2013.']
      end
    end

    context 'with a 264' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('250', ' ', ' ',
                                       MARC::Subfield.new('a', '3rd draft /'),
                                       MARC::Subfield.new('b', 'edited by Paul Watson.')))
          r.append(MARC::DataField.new('260', ' ', ' ',
                                       MARC::Subfield.new('a', 'London')))
          r.append(MARC::DataField.new('264', ' ', '3',
                                       MARC::Subfield.new('a', 'Cambridge'),
                                       MARC::Subfield.new('b', 'Kinset Printing Company')))
        end
      end

      it 'displays the right value' do
        expect(result[field]).to eq ['3rd draft / edited by Paul Watson. - London - Cambridge Kinset Printing Company']
      end
    end

    context 'with a 264 that is just a copyright or other date' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('250', ' ', ' ',
                                       MARC::Subfield.new('a', '3rd draft /'),
                                       MARC::Subfield.new('b', 'edited by Paul Watson.')))
          r.append(MARC::DataField.new('260', ' ', ' ',
                                       MARC::Subfield.new('a', 'London')))
          r.append(MARC::DataField.new('264', ' ', '4',
                                       MARC::Subfield.new('c', '2002')))
        end
      end
      it 'omits the 264 value' do
        expect(result[field]).to eq ['3rd draft / edited by Paul Watson. - London']
      end
    end
  end

  describe 'pub_date_sort' do
    let(:fixture_name) { 'pubDateTests.mrc' }
    let(:field) { 'pub_date_sort' }

    specify do
      expect(select_by_id('pubDate00uu')[field]).to eq ['00--']
      expect(select_by_id('pubDate01uu')[field]).to eq ['01--']
      expect(select_by_id('pubDate02uu')[field]).to eq ['02--']
      expect(select_by_id('pubDate03uu')[field]).to eq ['03--']
      expect(select_by_id('pubDate0500')[field]).to eq ['0500']
      expect(select_by_id('pubDate08uu')[field]).to eq ['08--']
      expect(select_by_id('pubDate0801')[field]).to eq ['0801']
      expect(select_by_id('pubDate09uu')[field]).to eq ['09--']
      expect(select_by_id('pubDate0960')[field]).to eq ['0960']
      expect(select_by_id('pubDate0963')[field]).to eq ['0963']
      expect(select_by_id('pubDate10uu')[field]).to eq ['10--']
      expect(select_by_id('pubDate11uu')[field]).to eq ['11--']
      expect(select_by_id('pubDate12uu')[field]).to eq ['12--']
      expect(select_by_id('pubDate13uu')[field]).to eq ['13--']
      expect(select_by_id('pubDate16uu')[field]).to eq ['16--']
      expect(select_by_id('p19uu')[field]).to eq ['19--']
      expect(select_by_id('pubDate19uu')[field]).to eq ['19--']
      expect(select_by_id('r1900')[field]).to eq ['1900']
      expect(select_by_id('s190u')[field]).to eq ['1900']
      expect(select_by_id('pubDate195u')[field]).to eq ['1950']
      expect(select_by_id('s195u')[field]).to eq ['1950']
      expect(select_by_id('g1958')[field]).to eq ['1958']
      expect(select_by_id('w1959')[field]).to eq ['1959']
      expect(select_by_id('bothDates008')[field]).to eq ['1964']
      expect(select_by_id('contRes')[field]).to eq ['1984']
      expect(select_by_id('y1989')[field]).to eq ['1989']
      expect(select_by_id('b199u')[field]).to eq ['1990']
      expect(select_by_id('k1990')[field]).to eq ['1990']
      expect(select_by_id('m1991')[field]).to eq ['1991']
      expect(select_by_id('e1997')[field]).to eq ['1997']
      expect(select_by_id('c1998')[field]).to eq ['1998']
      expect(select_by_id('w1999')[field]).to eq ['1999']
      expect(select_by_id('o20uu')[field]).to eq ['20--']
      expect(select_by_id('pubDate20uu')[field]).to eq ['20--']
      expect(select_by_id('f2000')[field]).to eq ['2000']
      expect(select_by_id('firstDateOnly008')[field]).to eq ['2000']
      expect(select_by_id('x200u')[field]).to eq ['2000']
      expect(select_by_id('q2001')[field]).to eq ['2001']
      expect(select_by_id('z2006')[field]).to eq ['2006']
      expect(select_by_id('v2007')[field]).to eq ['2007']
      expect(select_by_id('b2008')[field]).to eq ['2008']
      expect(select_by_id('z2009')[field]).to eq ['2009']
      expect(select_by_id('zpubDate2010')[field]).to eq ['2010']
    end

    context 'with garbage in the 008' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::ControlField.new('008', '800124d1uuu99uuru'))
        end
      end

      specify { expect(result[field]).to eq nil }
    end
  end
end
