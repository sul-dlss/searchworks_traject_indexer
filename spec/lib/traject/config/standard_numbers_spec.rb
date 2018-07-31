RSpec.describe 'Standard Numbers' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end

  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }

  subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }


  describe 'oclc' do
    let(:fixture_name) { 'oclcNumTests.mrc' }
    let(:field) { 'oclc' }

    it 'has the right data' do
      expect(select_by_id('035withOCoLC-M')[field]).to eq(['656729'])
      expect(select_by_id('035withOCoLC-MnoParens')[field]).not_to eq(['656729'])

      # doc should have oclc from good 035 and none from bad 035s
      expect(select_by_id('Mult035onlyOneGood')[field]).to eq(['656729'])

      # 079 only
      expect(select_by_id('079onlyocm')[field]).to eq(['38052115'])
      expect(select_by_id('079onlyocn')[field]).to eq(['122811369'])

      # 079 with bad prefix - 035 (OCoLC) only
      expect(select_by_id('079badPrefix')[field]).to eq(['180776170'])

      # doc should only have oclc from subfield a
      expect(select_by_id('079onlywithz')[field]).to eq(['46660954'])

      # both 079 and 035: doc should have oclc from 079, not from either 035
      expect(select_by_id('079withbad035s')[field]).to eq(['12345666'])

      # doc should have oclc from good 035, but not from good 079
      expect(select_by_id('Good035withGood079')[field]).to eq(['656729'])

      # doc should have one oclc only, from (OCoLC) prefixed field
      expect(select_by_id('035OCoLConly')[field]).to eq(['180776170'])

      # doc should have one oclc only, from (OCoLC) prefixed field
      expect(select_by_id('035bad079OCoLConly')[field]).to eq(['180776170'])

      # no oclc number
      expect(select_by_id('035and079butNoOclc')[field]).to be_nil

      # multiple oclc numbers
      expect(select_by_id('MultOclcNums')[field]).to eq(['656729', '38052115', '38403775'])
    end
  end


#
# 	/**
# 	 * Test population of isbn_display: the ISBNs used for external
# 	 *  lookups (e.g. Google Book Search)
# 	 */
# @Test
# 	public final void testISBNdisplay()
# 	{
# 		String fldName = "isbn_display";
# 		String testFilePath = testDataParentPath + File.separator + "isbnTests.mrc";
#
# 		// no isbn
# 	    solrFldMapTest.assertNoSolrFld(testFilePath, "No020", fldName);
# 	    solrFldMapTest.assertNoSolrFld(testFilePath, "020noSubaOrz", fldName);
#
# 		// 020 subfield a 10 digit varieties
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020suba10digit", fldName, "1417559128");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020suba10endsX", fldName, "123456789X");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020suba10trailingText", fldName, "1234567890");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020suba10trailingText", fldName, "0123456789");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020suba10trailingText", fldName, "0521672694");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020suba10trailingText", fldName, "052185668X");
#
# 		// 020 subfield a 13 digit varieties
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020suba13", fldName, "9780809424887");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020suba13endsX", fldName, "979123456789X");
# 	    solrFldMapTest.assertNoSolrFld(testFilePath, "020suba13bad", fldName);
# 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, "020suba13bad", fldName, "000123456789X");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020suba13trailingText", fldName, "978185585039X");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020suba13trailingText", fldName, "9780809424887");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020suba13trailingText", fldName, "9780809424870");
# 		// sub a mixed 10 and 13 digit
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020subaMult", fldName, "0809424886");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020subaMult", fldName, "123456789X");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020subaMult", fldName, "1234567890");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020subaMult", fldName, "979123456789X");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020subaMult", fldName, "9780809424887");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020subaMult", fldName, "9781855850484");
# 		// no subfield a in 020, but has subfield z 10 digit
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020subz10digit", fldName, "9876543210");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020subz10endsX", fldName, "123456789X");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020subz10trailingText", fldName, "1234567890");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020subz10trailingText", fldName, "0123456789");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020subz10trailingText", fldName, "0521672694");
# 		// no subfield a in 020, but has subfield z 13 digit
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020subz13digit", fldName, "9780809424887");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020subz13endsX", fldName, "979123456789X");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020subz13trailingText", fldName, "978185585039X");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020subz13trailingText", fldName, "9780809424887");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020subz13trailingText", fldName, "9780809424870");
# 		// mult subfield z in single 020
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020multSubz", fldName, "9802311987");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020multSubz", fldName, "9802311995");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020multSubz", fldName, "9802312002");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020multSubz", fldName, "9876543210");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020multSubz", fldName, "123456789X");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020multSubz", fldName, "9780809424887");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020multSubz", fldName, "979123456789X");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020multSubz", fldName, "9780809424870");
#
# 		// mult a and z - should only have a
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020SubaAndz", fldName, "0123456789");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020SubaAndz", fldName, "0521672694");
# 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, "020SubaAndz", fldName, "9802311987");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "020SubaAndz", fldName, "052185668X");
# 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, "020SubaAndz", fldName, "123456789X");
# 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, "020SubaAndz", fldName, "9780809424887");
# 	}
#
# 	/**
# 	 * Test population of isbn_search field: the ISBNs that an end user can
# 	 *  search for in our index
# 	 */
# @Test
# 	public final void testISBNsearch()
# 		throws IOException, ParserConfigurationException, SAXException, SolrServerException
# 	{
# 		String fldName = "isbn_search";
# 		createFreshIx("isbnTests.mrc");
#
# 		// searches are not exhaustive  (b/c programmer is exhausted)
#
# 		// isbn search with sub a value from record with mult a and z
# 		Set<String> docIds = new HashSet<String>();
# 		docIds.add("020suba10trailingText");
# 		docIds.add("020SubaAndz");
# 		assertSearchResults(fldName, "052185668X", docIds);
#
# 		// isbn search with sub z value from record with mult a and z
# 		docIds.clear();
# 		docIds.add("020suba13");
# 		docIds.add("020suba13trailingText");
# 		docIds.add("020subaMult");
# 		docIds.add("020subz13digit");
# 		docIds.add("020subz13trailingText");
# 		docIds.add("020multSubz");
# 		docIds.add("020SubaAndz");
# 		assertSearchResults(fldName, "9780809424887", docIds);
#
# 		assertSingleResult("774z", fldName, "0001112223");
# 	}
#
# 	/**
# 	 * isbn_search should be case insensitive
# 	 */
# @Test
# 	public final void testISBNSearchCaseInsensitive()
# 		throws IOException, ParserConfigurationException, SAXException, SolrServerException
# 	{
# 		String fldName = "isbn_search";
# 		createFreshIx("isbnTests.mrc");
#
# 		Set<String> docIds = new HashSet<String>();
# 		docIds.add("020suba10trailingText");
# 		docIds.add("020SubaAndz");
# 		assertSearchResults(fldName, "052185668X", docIds);
# 		assertSearchResults(fldName, "052185668x", docIds);
# 	}
#
# 	/**
# 	 * Test population of issn_display field: the ISSNs used for
# 	 *  external lookups (e.g. xISSN)
# 	 */
# @Test
# 	public final void testISSNdisplay()
# 	{
# 		String fldName = "issn_display";
# 		String testFilePath = testDataParentPath + File.separator + "issnTests.mrc";
#
# 		// no issn
# 	    solrFldMapTest.assertNoSolrFld(testFilePath, "No022", fldName);
# 	    solrFldMapTest.assertNoSolrFld(testFilePath, "022subaNoHyphen", fldName);
# 	    solrFldMapTest.assertNoSolrFld(testFilePath, "022subaTooManyChars", fldName);
# 		// 022 single subfield
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "022suba", fldName, "1047-2010");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "022subaX", fldName, "1047-201X");
# 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, "022subL", fldName, "0796-5621");
# 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, "022subM", fldName, "0863-4564");
# 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, "022subY", fldName, "0813-1964");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "022subZ", fldName, "1144-585X");
# 		// 022 mult subfields
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "022subAandL", fldName, "0945-2419");
# 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, "022subAandL", fldName, "0796-5621");
# 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, "022subLandM", fldName, "0038-6073");
# 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, "022subLandM", fldName, "0796-5621");
# 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, "022subMandZ", fldName, "0103-8915");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "022subMandZ", fldName, "1144-5858");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "Two022a", fldName, "0666-7770");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "Two022a", fldName, "1221-2112");
# 	}


  describe 'issn_search' do
    let(:fixture_name) { 'issnTests.mrc' }
    let(:field) { 'issn_search' }

    it 'has the right data' do
      expect(select_by_id('022suba')[field]).to eq(['1047-2010'])
      expect(select_by_id('022subaX')[field]).to eq(['1047-201X'])

      expect(select_by_id('022subL')[field]).to eq(['0796-5621'])
      expect(select_by_id('022subAandL')[field]).to eq(['0945-2419', '0796-5621'])
      expect(select_by_id('022subLandM')[field]).to eq(['0038-6073', '0796-5621'])

      expect(select_by_id('022subM')[field]).to eq(['0863-4564'])
      expect(select_by_id('022subY')[field]).to eq(['0813-1964'])
      expect(select_by_id('022subMandZ')[field]).to eq(['0103-8915', '1144-5858'])
      expect(select_by_id('022subZ')[field]).to eq(['1144-585X'])
      expect(select_by_id('Two022a')[field]).to eq(['0666-7770', '1221-2112'])

      expect(select_by_id('785x')[field]).to eq(['8750-2836'])
    end
  end
  # /**
  #  * Test population of issn_display field: the ISSNs used for
  #  *  external lookups (e.g. xISSN) - for Lane-specific ISSNs
  #  */
# @Test
# public final void testISSNdisplayLane()
# {
# 	String fldName = "issn_display";
# 	String testFilePath = testDataParentPath + File.separator + "issnTestsLane.xml";
#
# 	// no issn
#     solrFldMapTest.assertNoSolrFld(testFilePath, "No022", fldName);
#     solrFldMapTest.assertNoSolrFld(testFilePath, "022subaNoHyphen", fldName);
#     solrFldMapTest.assertNoSolrFld(testFilePath, "022subaTooManyChars", fldName);
# 	// 022 single subfield
#     solrFldMapTest.assertSolrFldValue(testFilePath, "022suba", fldName, "1047-2010 (Print)");
#     solrFldMapTest.assertSolrFldValue(testFilePath, "022subaX", fldName, "1047-201X (Print)");
#     // 022 mult subfields
#     solrFldMapTest.assertSolrFldValue(testFilePath, "022subAandL", fldName, "0945-2419 (Print)");
# 	solrFldMapTest.assertSolrFldHasNoValue(testFilePath, "022subAandL", fldName, "0796-5621");
# 	solrFldMapTest.assertSolrFldHasNoValue(testFilePath, "022subLandM", fldName, "0038-6073 (Print)");
# 	solrFldMapTest.assertSolrFldHasNoValue(testFilePath, "022subLandM", fldName, "0796-5621 (George)");
# }
#
# /**
# 	 * Test population of issn_search field: the ISSNs that an end user can
# 	 *  search for in our index - Lane-specific ISSNs
#  */
# @Test
# public final void testISSNSearchLane()
# 	throws IOException, ParserConfigurationException, SAXException, SolrServerException
# {
# 	String fldName = "issn_search";
# 	createFreshIx("issnTestsLane.xml");
#
# 	assertSingleResult("022suba", fldName, "1047-2010");
# 	assertSingleResult("022subaX", fldName, "1047-201X");
#
# 	Set<String> docIds = new HashSet<String>();
# 	docIds.add("022subL");
# 	docIds.add("022subAandL");
# 	docIds.add("022subLandM");
# 	assertSearchResults(fldName, "0796-5621", docIds);
#
# 	assertSingleResult("022subM", fldName, "0863-4564");
# 	assertSingleResult("022subY", fldName, "0813-1964");
# 	assertSingleResult("022subMandZ", fldName, "1144-5858");
# 	assertSingleResult("022subLandM", fldName, "0038-6073");
# 	assertSingleResult("022subMandZ", fldName, "0103-8915");
# 	assertSingleResult("022subZ", fldName, "1144-585X");
# 	assertSingleResult("022subAandL", fldName, "0945-2419");
# 	assertSingleResult("Two022a", fldName, "0666-7770");
# 	assertSingleResult("Two022a", fldName, "1221-2112");
#
# 	// without hyphen:
# 	assertSingleResult("022subM", fldName, "08634564");
# 	assertSingleResult("022subZ", fldName, "1144585X");
#
# 	assertSingleResult("785x", fldName, "8750-2836");
#
# }
#
# 	/**
# 	 * Test population of lccn field
# 	 */
# @Test
# 	public final void testLCCN()
# 	{
# 		String fldName = "lccn";
# 		String testFilePath = testDataParentPath + File.separator + "lccnTests.mrc";
#
# 		// no lccn
# 		solrFldMapTest.assertNoSolrFld(testFilePath, "No010", fldName);
# // TODO:  the 9 digit lccn passes.  I don't know why.  I no longer care.
# //		solrFldMapTest.assertNoSolrFld(testFilePath, "010bad", fldName);
# 		// 010 sub a only
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "010suba8digit", fldName, "85153773");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "010suba10digit", fldName, "2001627090");
# 		// prefix
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "010suba8digitPfx", fldName, "a  60123456");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "010suba8digit2LetPfx", fldName, "bs 66654321");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "010suba8digit3LetPfx", fldName, "cad77665544");
# 		// according to loc marc doc, shouldn't have prefix for 10 digit, but
# 		//  what the heck - let's test
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "010suba10digitPfx", fldName, "r 2001336783");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "010suba10digit2LetPfx", fldName, "ne2001045944");
# 		// suffix
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "010suba8digitSfx", fldName, "79139101");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "010suba10digitSfx", fldName, "2006002284");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "010suba8digitSfx2", fldName, "73002284");
# 		// sub z
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "010subz", fldName, "20072692384");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "010subaAndZ", fldName, "76647633");
# 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, "010subaAndZ", fldName, "76000587");
# 	    solrFldMapTest.assertSolrFldValue(testFilePath, "010multSubZ", fldName, "76647633");
# 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, "010multSubZ", fldName, "2000123456");
# 	}
#
# }
end
