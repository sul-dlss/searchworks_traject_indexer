RSpec.describe 'Publication config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
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
      expect(select_by_id('260ababc')[field]).to eq ["Paris : Gauthier-Villars ; Chicago : University of Chicago Press"]
      expect(select_by_id('260abbc')[field]).to eq ["Washington, D.C. : first b : second b U.S. G.P.O."]
      expect(select_by_id('260ab3')[field]).to eq ["London : Vogue"]
      expect(select_by_id('260crightbracket')[field]).to eq ["i.e. Bruxelles : Moens"]
    end

    it 'skips 260a s.l, 260b s.n.' do
      expect(select_by_id('260abunknown')[field]).to eq nil

      # 260a contains s.l. (unknown - sin location, presumably)
  		expect(select_by_id('260aunknown')[field]).to eq ["Insight Press"]
  		expect(select_by_id('260abaslbc')[field]).to eq ["[Philadelphia] : Some name another name"]
      #
      # 260b contains s.n. (unknown - sin name, presumably)
  		expect(select_by_id('260bunknown')[field]).to eq ["Victoria, B.C."]
    end

    context 'with a record with a 264' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('a', '264a')
          ))
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('b', '264b')
          ))
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('c', '264c')
          ))
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('a', '264a'),
            MARC::Subfield.new('b', '264b')
          ))
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
            MARC::Subfield.new('a', '264a')
          ))
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('b', '264b')
          ))
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('c', '264c')
          ))
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('a', '264a'),
            MARC::Subfield.new('b', '264b')
          ))
          r.append(MARC::DataField.new('260', ' ', ' ',
            MARC::Subfield.new('a', '260a')
          ))
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
            MARC::Subfield.new('b', 'b1')
          ))
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('a', '[Place of Production not identified] :'),
            MARC::Subfield.new('b', 'b2')
          ))
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('a', 'Place of manufacture Not Identified'),
            MARC::Subfield.new('b', 'b3')
          ))
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('a', '[Place of distribution not identified]')
          ))
        end
      end

      it 'maps all the data' do
        expect(result[field]).to eq ['b1', 'b2', 'b3']
      end
    end

    context 'with unknown-ish phrases' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('a', 'a1'),
            MARC::Subfield.new('b', '[publisher not identified], ')
          ))
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('a', 'a2'),
            MARC::Subfield.new('b', '[Producer not identified]')
          ))
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('a', 'a3'),
            MARC::Subfield.new('b', 'Manufacturer Not Identified')
          ))
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('b', '[distributor not identified]')
          ))
        end
      end

      it 'maps all the data' do
        expect(result[field]).to eq ['a1', 'a2', 'a3']
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
            MARC::Subfield.new('6', '880-01')
          ))
          r.append(MARC::DataField.new('880', ' ', ' ',
            MARC::Subfield.new('6', '264-01'),
            MARC::Subfield.new('a', '880a for 264'),
            MARC::Subfield.new('b', '880b for 264'),
            MARC::Subfield.new('c', '880c for 264')
          ))
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
            MARC::Subfield.new('c', '[Date of publication not identified] :')
          ))
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('c', '[Date of Production not identified]')
          ))
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('c', 'Date of manufacture Not Identified')
          ))
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('c', '[Date of distribution not identified]')
          ))
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
            MARC::Subfield.new('c', '9999')
          ))
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('c', '6666')
          ))
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('c', '22nd century')
          ))
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('c', '8610s')
          ))
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
            MARC::Subfield.new('c', '0000')
          ))
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('c', '0036')
          ))
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('c', '0197')
          ))
          r.append(MARC::DataField.new('264', ' ', ' ',
            MARC::Subfield.new('c', '0204')
          ))
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
      '[1940?]' => '1940',
    }.each do |data_264c, expected|
      context 'with a year in the 264' do
        subject(:result) { indexer.map_record(record) }
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(MARC::DataField.new('264', ' ', ' ',
              MARC::Subfield.new('c', data_264c)
            ))
          end
        end

        specify { expect(result[field]).to eq [expected] }
      end
    end

    {
      # FIXME (from solrmarc): 'copyright 2005' => '2005',
      ['[2011]', '©2009'] => '2011',
      ['2012.', '©2009'] => '2012',
      '197?' => '1970',
      '[197?]' => '1970',
      ['1560', '1564'] => '1560'
    }.each do |data_264c, expected|
      context 'with a garbage value in the 008, and year in the 264' do
        subject(:result) { indexer.map_record(record) }
        let(:record) do
          MARC::Record.new.tap do |r|
            Array(data_264c).each do |v|
              r.append(MARC::ControlField.new('008', '       0000'))
              r.append(MARC::DataField.new('264', ' ', ' ',
                MARC::Subfield.new('c', v)
              ))
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
            MARC::Subfield.new('c', '0019')
          ))
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
            MARC::Subfield.new('c', '1260')
          ))
          r.append(MARC::DataField.new('264', ' ', '1',
            MARC::Subfield.new('c', '1264')
          ))
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
#
#
#
# 	/**
# 	 * functional test: assure date slider pub_year_tisim field is populated correctly from single value in single 260c
# 	 */
# @Test
# 	public void test260SingleValueInDateSlider()
# 	{
# 		String solrFldName = "pub_year_tisim";
# 	    assertSingleSolrFldValFromMarcSubfld("260", 'c', "1973", solrFldName, "1973");
# 	    assertSingleSolrFldValFromMarcSubfld("260", 'c', "[1973]", solrFldName, "1973");
# 	    assertSingleSolrFldValFromMarcSubfld("260", 'c', "1973]", solrFldName, "1973");
# 	    assertSingleSolrFldValFromMarcSubfld("260", 'c', "[1973?]", solrFldName, "1973");
# 	    assertSingleSolrFldValFromMarcSubfld("260", 'c', "[196-?]", solrFldName, "1960");
# //	    assertSingleSolrFldValFromMarcSubfld("260", 'c', "March 1987.", solrFldName, "1987");
# 	    // copyright year
# 	    assertSingleSolrFldValFromMarcSubfld("260", 'c', "c1975.", solrFldName, "1975");
# 	    assertSingleSolrFldValFromMarcSubfld("260", 'c', "[c1973]", solrFldName, "1973");
# 	    assertSingleSolrFldValFromMarcSubfld("260", 'c', "c1973]", solrFldName, "1973");
# 		// with corrected date
# 	    assertSingleSolrFldValFromMarcSubfld("260", 'c', "1973 [i.e. 1974]", solrFldName, "1974");
# 	    assertSingleSolrFldValFromMarcSubfld("260", 'c', "1971[i.e.1972]", solrFldName, "1972");
# 	    assertSingleSolrFldValFromMarcSubfld("260", 'c', "1973 [i.e.1974]", solrFldName, "1974");
# 	    assertSingleSolrFldValFromMarcSubfld("260", 'c', "1967 [i. e. 1968]", solrFldName, "1968");
# 	}
#
# 	/**
# 	 * functional test: assure date slider pub_year_tisim field is not populated when no 008 or 260c usable value
# 	 */
# @Test
# 	public void test260NoValueInDateSlider()
# 	{
# 		String solrFldName = "pub_year_tisim";
# 	    assertNoSolrFldFromMarcSubfld("260", 'c', "[19--]", solrFldName);
# 	}
#
#
# 	/**
# 	 * integration test: pub_year_tisim
# 	 */
# @Test
# 	public final void testPubDateForSlider()
# 			throws ParserConfigurationException, IOException, SAXException, SolrServerException
# 	{
# 		createFreshIx("pubDateTests.mrc");
# 		String fldName = "pub_year_tisim";
# 		Set<String> docIds = new HashSet<String>();
#
# //		assertSingleResult("zpubDate2010", fldName, "2010");
#
# 		// multiple dates
# 		assertSingleResult("pubDate195u", fldName, "1957");
# 		assertSingleResult("pubDate195u", fldName, "1982");
# 		docIds.add("pubDate195u");
# 		docIds.add("bothDates008");
# 		assertSearchResults(fldName, "1964", docIds);
# 		docIds.remove("bothDates008");
# 		docIds.add("s195u");
# 		assertSearchResults(fldName, "1950", docIds);
#
# 		// future dates are ignored/skipped
# 		assertZeroResults(fldName, "6666");
# 		assertZeroResults(fldName, "8610");
# 		assertZeroResults(fldName, "9999");
#
# 		// dates before 500 are ignored/skipped
# 		assertZeroResults(fldName, "0000");
# 		assertZeroResults(fldName, "0019");
#
# 		// corrected values
# 		docIds.clear();
# 		docIds.add("pubDate0059");
# 		docIds.add("j2005");
# 		docIds.add("contRes");
# 		assertSearchResults(fldName, "2005", docIds);
# 		docIds.clear();
# 		docIds.add("pubDate195u");  // it's a range including 1970
# 		docIds.add("pubDate0197-1");
# 		docIds.add("pubDate0197-2");
# 		assertSearchResults(fldName, "1970", docIds);
# 	}
  end
#
#
  describe 'imprint_display' do
    let(:field) { 'imprint_display' }

    context 'with both 250 + 260' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('250', ' ', ' ',
            MARC::Subfield.new('a', 'Special ed.')
          ))
          r.append(MARC::DataField.new('260', ' ', ' ',
            MARC::Subfield.new('a', 'London :'),
            MARC::Subfield.new('b', "William Heinemann,"),
            MARC::Subfield.new('c', "2012")
          ))
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
            MARC::Subfield.new('b', "Éd. canadienne.")
          ))
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
            MARC::Subfield.new('a', 'Rev. as of Jan. 1, 1958.')
          ))
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
            MARC::Subfield.new('b', 'edited by Paul Watson.')
          ))
          r.append(MARC::DataField.new('260', ' ', ' ',
            MARC::Subfield.new('a', 'London')
          ))
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
            MARC::Subfield.new('a', 'Di 1 ban.')
          ))
          r.append(MARC::DataField.new('880', ' ', ' ',
            MARC::Subfield.new('6', '250-04'),
            MARC::Subfield.new('a', '第1版.')
          ))
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
            MARC::Subfield.new('c', 'c2013.'),
          ))
          r.append(MARC::DataField.new('880', ' ', ' ',
            MARC::Subfield.new('6', '260-03//r'),
            MARC::Subfield.new('a', 'אור יהודה :'),
            MARC::Subfield.new('b', 'כנרת :'),
            MARC::Subfield.new('b', 'זמורה־ביתן,'),
            MARC::Subfield.new('c', 'c2013.')
          ))
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
            MARC::Subfield.new('c', 'Minguo 69 [1980]'),
          ))
          r.append(MARC::DataField.new('880', ' ', ' ',
            MARC::Subfield.new('6', '260-02'),
            MARC::Subfield.new('a', '[台北] :'),
            MARC::Subfield.new('b', '該會,'),
            MARC::Subfield.new('c', '民國69 [1980]')
          ))
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
            MARC::Subfield.new('a', 'Di 1 ban.')
          ))
          r.append(MARC::DataField.new('260', ' ', ' ',
            MARC::Subfield.new('6', '880-05'),
            MARC::Subfield.new('a', 'Shanghai Shi :'),
            MARC::Subfield.new('b', 'Shanghai shu dian chu ban she,'),
            MARC::Subfield.new('c', '2013.')
          ))
          r.append(MARC::DataField.new('880', ' ', ' ',
            MARC::Subfield.new('6', '250-04'),
            MARC::Subfield.new('a', '第1版.')
          ))
          r.append(MARC::DataField.new('880', ' ', ' ',
            MARC::Subfield.new('6', '260-05'),
            MARC::Subfield.new('a', '上海市 :'),
            MARC::Subfield.new('b', '上海书店出版社,'),
            MARC::Subfield.new('c', '2013.')
          ))
        end
      end

      it 'displays the right value' do
        expect(result[field]).to eq ['Di 1 ban. 第1版. - Shanghai Shi : Shanghai shu dian chu ban she, 2013. 上海市 : 上海书店出版社, 2013.']
      end
    end
  end


  describe 'pub_date_sort' do
#
#
# 	/**
# 	 * integration test: pub_date_sort field population and ascending sort.
# 	 */
# @Test
# 	public final void testPubDateSortAsc()
# 			throws ParserConfigurationException, IOException, SAXException, InvocationTargetException, ClassNotFoundException, InstantiationException, IllegalAccessException, NoSuchMethodException, SolrServerException
# 	{
# 		createFreshIx("pubDateTests.mrc");
#
# 		// list of doc ids in correct publish date sort order
# 		List<String> expectedOrderList = new ArrayList<String>(50);
#
# 		expectedOrderList.add("pubDate00uu");   // "1st century"
# 		expectedOrderList.add("pubDate01uu");   // "2nd century"
# 		expectedOrderList.add("pubDate02uu");   // "3rd century"
# 		expectedOrderList.add("pubDate03uu");   // "4th century"
# 		expectedOrderList.add("pubDate0500");   // 0500
# 		expectedOrderList.add("pubDate08uu");   // "9th century"
# 		expectedOrderList.add("pubDate0801");   // 0801
# 		expectedOrderList.add("pubDate09uu");   // "10th century"
# 		expectedOrderList.add("pubDate0960");   // 0960
# 		expectedOrderList.add("pubDate0963");   // 0963
# 		expectedOrderList.add("pubDate10uu");   // "11th century"
# 		expectedOrderList.add("pubDate11uu");   // "12th century"
# 		expectedOrderList.add("pubDate12uu");   // "13th century"
# 		expectedOrderList.add("pubDate13uu");   // "14th century"
# 		expectedOrderList.add("pubDate16uu");   // "17th century"
# 		expectedOrderList.add("p19uu");   // "20th century"
# 		expectedOrderList.add("pubDate19uu");   // "20th century"
# 		expectedOrderList.add("r1900");   // "1900"
# 		expectedOrderList.add("s190u");   // "1900s"
# 		expectedOrderList.add("pubDate195u");   // "1950s"
# 		expectedOrderList.add("s195u");   // "1950s"
# 		expectedOrderList.add("g1958");   // "1958"
# 		expectedOrderList.add("w1959");   // "1959"ˇ
# 		expectedOrderList.add("bothDates008");  // "1964"
# //		expectedOrderList.add("pubDate0197-1");  // 1970
# 		expectedOrderList.add("contRes");       // "1984"
# 		expectedOrderList.add("y1989");   // "1989"
# 		expectedOrderList.add("b199u");   // "1990s"
# 		expectedOrderList.add("k1990");   // "1990"
# 		expectedOrderList.add("m1991");   // "1991"
# 		expectedOrderList.add("e1997");   // "1997"
# 		expectedOrderList.add("c1998");   // "1998"
# 		expectedOrderList.add("w1999");   // "1999"
# 		expectedOrderList.add("o20uu");   // "21st century"
# 		expectedOrderList.add("pubDate20uu");   // "21st century"
# 		expectedOrderList.add("f2000");   // "2000"
# 		expectedOrderList.add("firstDateOnly008");  // "2000"
# 		expectedOrderList.add("x200u");   // "2000s"
# 		expectedOrderList.add("q2001");   // "2001"
# //		expectedOrderList.add("pubDate0204");  // 2004
# //		expectedOrderList.add("pubDate0059");  // 2005
# 		expectedOrderList.add("z2006");   // "2006"
# 		expectedOrderList.add("v2007");   // "2007"
# 		expectedOrderList.add("b2008");   // "2008"
# 		expectedOrderList.add("z2009");   // "2009"
# 		expectedOrderList.add("zpubDate2010");   // "2010"
#
# 		// invalid/missing dates are designated as last in solr schema file
# 		//  they are in order of occurrence in the raw data
# 		expectedOrderList.add("pubDate0000");
# 		expectedOrderList.add("pubDate0019");
# //		expectedOrderList.add("pubDate0059");  // 2005 not in 008
# //		expectedOrderList.add("pubDate0197-1");
# //		expectedOrderList.add("pubDate0204");  // 2004  not in 008
# 		expectedOrderList.add("pubDate1uuu");
# 		expectedOrderList.add("pubDate6666");
# 		expectedOrderList.add("pubDate9999");
#
# 		// get search results sorted by pub_date_sort field
#         SolrDocumentList results = getAscSortDocs("collection", "sirsi", "pub_date_sort");
#
#         SolrDocument firstDoc = results.get(0);
# 		assertTrue("9999 pub date should not sort first", (String) firstDoc.getFirstValue(docIDfname) != "pubDate9999");
#
# 		// we know we have documents that are not in the expected order list,
# 		//  so we must allow for gaps
# 		// author_sort isn't stored, so we must look at id field
# 		int expDocIx = -1;
# 		for (SolrDocument doc : results)
# 		{
# 			if (expDocIx < expectedOrderList.size() - 1)
# 			{
# 				String resultDocId = (String) doc.getFirstValue(docIDfname);
# 				// is it a match?
#                 if (resultDocId.equals(expectedOrderList.get(expDocIx + 1)))
#                 	expDocIx++;
# 			}
# 			else break;  // we found all the documents in the expected order list
# 		}
#
# 		if (expDocIx != expectedOrderList.size() - 1)
# 		{
# 			String lastCorrDocId = expectedOrderList.get(expDocIx);
# 			fail("Publish Date Sort Order is incorrect.  Last correct document was " + lastCorrDocId);
# 		}
# 	}
#
#
# 	/**
# 	 * integration test: pub date descending sort should start with oldest and go to newest
# 	 *  (missing dates sort order tested in another method)
# 	 */
# @Test
# 	public void testPubDateSortDesc()
# 			throws ParserConfigurationException, IOException, SAXException, NoSuchMethodException, InstantiationException, InvocationTargetException, ClassNotFoundException, IllegalAccessException, SolrServerException
# 	{
# 		createFreshIx("pubDateTests.mrc");
#
# 		// list of doc ids in correct publish date sort order
# 		List<String> expectedOrderList = new ArrayList<String>(50);
#
# 		expectedOrderList.add("zpubDate2010");   // "2010"
# 		expectedOrderList.add("z2009");   // "2009"
# 		expectedOrderList.add("b2008");   // "2008"
# 		expectedOrderList.add("v2007");   // "2007"
# 		expectedOrderList.add("z2006");   // "2006"
# //		expectedOrderList.add("pubDate0059");  // 2005
# //		expectedOrderList.add("pubDate0204");  // 2004
# 		expectedOrderList.add("q2001");   // "2001"
# 		expectedOrderList.add("f2000");   // "2000"
# 		expectedOrderList.add("firstDateOnly008");  // "2000"
# 		expectedOrderList.add("x200u");   // "2000s"
# 		expectedOrderList.add("o20uu");   // "21st century"
# 		expectedOrderList.add("pubDate20uu");   // "21st century"
# 		expectedOrderList.add("w1999");   // "1999"
# 		expectedOrderList.add("c1998");   // "1998"
# 		expectedOrderList.add("e1997");   // "1997"
# 		expectedOrderList.add("m1991");   // "1991"
# 		expectedOrderList.add("b199u");   // "1990s"
# 		expectedOrderList.add("k1990");   // "1990"
# 		expectedOrderList.add("y1989");   // "1989"
# 		expectedOrderList.add("contRes");       // "1984"
# //		expectedOrderList.add("pubDate0197-1");  // 1970
# 		expectedOrderList.add("bothDates008");  // "1964"
# 		expectedOrderList.add("w1959");   // "1959"ˇ
# 		expectedOrderList.add("g1958");   // "1958"
# 		expectedOrderList.add("pubDate195u");   // "1950s"
# 		expectedOrderList.add("s195u");   // "1950s"
# 		expectedOrderList.add("r1900");   // "1900"
# 		expectedOrderList.add("s190u");   // "1900s"
# 		expectedOrderList.add("p19uu");   // "20th century"
# 		expectedOrderList.add("pubDate19uu");   // "20th century"
# 		expectedOrderList.add("pubDate16uu");   // "17th century"
# 		expectedOrderList.add("pubDate13uu");   // "14th century"
# 		expectedOrderList.add("pubDate12uu");   // "13th century"
# 		expectedOrderList.add("pubDate11uu");   // "12th century"
# 		expectedOrderList.add("pubDate10uu");   // "11th century"
# 		expectedOrderList.add("pubDate0963");   // 0963
# 		expectedOrderList.add("pubDate0960");   // 0960
# 		expectedOrderList.add("pubDate09uu");   // "10th century"
# 		expectedOrderList.add("pubDate0801");   // 0801
# 		expectedOrderList.add("pubDate08uu");   // "9th century"
# 		expectedOrderList.add("pubDate0500");   // 0500
# 		expectedOrderList.add("pubDate03uu");   // "4th century"
# 		expectedOrderList.add("pubDate02uu");   // "3rd century"
# 		expectedOrderList.add("pubDate01uu");   // "2nd century"
# 		expectedOrderList.add("pubDate00uu");   // "1st century"
#
# 		// invalid/missing dates are designated as last or first in solr
# 		//  schema file.
# 		expectedOrderList.add("pubDate0000");
# 		expectedOrderList.add("pubDate0019");
# //		expectedOrderList.add("pubDate0059");  // 2005 not in 008
# //		expectedOrderList.add("pubDate0197-1");
# //		expectedOrderList.add("pubDate0204");  // 2004  not in 008
# 		expectedOrderList.add("pubDate1uuu");
# 		expectedOrderList.add("pubDate6666");
# 		expectedOrderList.add("pubDate9999");
#
# 		// get search results sorted by pub_date_sort field
#         SolrDocumentList results = getDescSortDocs("collection", "sirsi", "pub_date_sort");
#
#         SolrDocument firstDoc = results.get(0);
# 		assertTrue("0000 pub date should not sort first", (String) firstDoc.getFirstValue(docIDfname) != "pubDate0000");
#
# 		// we know we have documents that are not in the expected order list,
# 		//  so we must allow for gaps
# 		// author_sort isn't stored, so we must look at id field
# 		int expDocIx = -1;
# 		for (SolrDocument doc : results)
# 		{
# 			if (expDocIx < expectedOrderList.size() - 1)
# 			{
# 				String resultDocId = (String) doc.getFirstValue(docIDfname);
# 				// is it a match?
#                 if (resultDocId.equals(expectedOrderList.get(expDocIx + 1)))
#                 	expDocIx++;
# 			}
# 			else break;  // we found all the documents in the expected order list
# 		}
#
# 		if (expDocIx != expectedOrderList.size() - 1)
# 		{
# 			String lastCorrDocId = expectedOrderList.get(expDocIx);
# 			fail("Publish Date Sort Order is incorrect.  Last correct document was " + lastCorrDocId);
# 		}
# 	}
  end

end
