# frozen_string_literal: true

RSpec.describe 'Call Numbers' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/marc_config.rb')
    end
  end

  let(:fixture_name) { 'callNumberTests.mrc' }
  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }

  subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }

  describe 'lc_assigned_callnum_ssim' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '15069nam a2200409 a 4500'
        r.append(MARC::ControlField.new('008', '091123s2014    si a    sb    101 0 eng d'))
        r.append(MARC::DataField.new('050', ' ', '0',
                                     MARC::Subfield.new('a', 'F1356'),
                                     MARC::Subfield.new('b', '.M464 2005')))
        r.append(MARC::DataField.new('090', ' ', '0',
                                     MARC::Subfield.new('a', 'F090'),
                                     MARC::Subfield.new('b', '.Z1')))
      end
    end

    it 'extracts data from the 050ab field' do
      expect(result['lc_assigned_callnum_ssim']).to include 'F1356 .M464 2005'
    end

    it 'extracts data from the 090ab field' do
      expect(result['lc_assigned_callnum_ssim']).to include 'F090 .Z1'
    end
  end

  # /**
  #  * junit4 tests for Stanford University call number fields
  #  * @author Naomi Dushay
  #  */
  # public class CallNumberTests extends AbstractStanfordTest
  # {
  # 	private final String govDocStr = "Government Document";
  # 	private final boolean isSerial = true;
  # 	private final String ignoredId = "ignored";
  # 	private String fileName = "callNumberTests.mrc";
  #     private String testFilePath = testDataParentPath + File.separator + fileName;
  #
  # @Before
  # 	public final void setup()
  # 	{
  # 		mappingTestInit();
  # 	}
  #
  # 	/**
  # 	 * callnum_search shouldn't get forbidden call numbers
  # 	 */
  # @Test
  # 	public final void testIgnoredCallnumSearch()
  # 			throws IOException, ParserConfigurationException, SAXException, SolrServerException
  # 	{
  # 		createFreshIx(fileName);
  #
  # 		String fldName = "callnum_search";
  # 		assertSingleResult("690002", fldName, "\"159.32 .W211\"");
  # 		//  skipped values
  # 		assertZeroResults(fldName, "\"NO CALL NUMBER\"");
  # 		assertZeroResults(fldName, "\"IN PROCESS\"");
  # 		assertZeroResults(fldName, "\"INTERNET RESOURCE\"");
  # 		assertZeroResults(fldName, "WITHDRAWN");
  # 		assertZeroResults(fldName, "X*"); // X call nums (including XX)
  # 		assertZeroResults(fldName, "\"" + govDocStr + "\"");
  # 	}
  #
  # 	/**
  # 	 * callnum_facet_hsim contains the a user friendly hierarchical version of
  # 	 * local LC call number topic indicated by the letters.
  # 	 */
  # @Test
  # 	public final void testLC()
  # 	{
  # 		String fldName = "callnum_facet_hsim";
  # 		String startLC = edu.stanford.CallNumUtils.LC_TOP_FACET_VAL + "|";
  #
  # 		// single char LC classification
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "6661112", fldName, startLC + "Z - Bibliography, Library Science, Information Resources|Z - Bibliography, Library Science, Information Resources");
  # 		// LC 999 one letter, space before Cutter
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "7772223", fldName, startLC + "F - History of the Americas (Local)|F - History of the Americas (Local)");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "999LC1dec", fldName, startLC + "D - World History|D - World History");
  #
  # 		// two char LC classification
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "1033119", fldName, startLC + "B - Philosophy, Psychology, Religion|BX - Christian Denominations");
  # 		// LC 999 two letters, space before Cutter
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "999LC2", fldName, startLC + "H - Social Sciences|HG - Finance");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "999LC22", fldName, startLC + "C - Historical Sciences (Archaeology, Genealogy)|CB - History of Civilization");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "2913114", fldName, startLC + "D - World History|DH - Low Countries (History)");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "1732616", fldName, startLC + "Q - Science|QA - Mathematics");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "115472", fldName, startLC + "H - Social Sciences|HC - Economic History & Conditions");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "2913114", fldName, startLC + "D - World History|DH - Low Countries (History)");
  # 		// mult values for a single doc
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "3400092", fldName, startLC + "D - World History|DC - France (History)");
  #
  # 		// three char LC classification
  # 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, "999LC3NoDec", fldName, startLC + "K - Law|K - Law");
  # 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, "999LC3Dec", fldName, startLC + "K - Law|K - Law");
  # 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, "999LC3DecSpace", fldName, startLC + "K - Law|K - Law");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "999LC3NoDec", fldName, startLC + "K - Law|KJH - Law of Andorra");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "999LC3Dec", fldName, startLC + "K - Law|KJH - Law of Andorra");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "999LC3DecSpace", fldName, startLC + "K - Law|KJH - Law of Andorra");
  #
  # 		// LCPER
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "460947", fldName, startLC + "E - History of the Americas (General)|E - History of the Americas (General)");
  # 	}
  #
  # 	/**
  # 	 * callnum_search contains all local call numbers, except those that are
  # 	 *  ignored, such as "NO CALL NUMBER"  It includes "bad" LC call numbers,
  # 	 *  such as those beginning with X;  it includes MFILM and MCD call numbers
  # 	 *  and so on.  Testing Dewey call number search is in a separate method.
  # 	 */
  # @Test
  # 	public final void testSearchLC()
  # 	{
  # 		String fldName = "callnum_search";
  #
  # 		// LC 999 one letter
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "6661112", fldName, "Z3871.Z8");
  # 		// LC 999 one letter, space before Cutter
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "7772223", fldName, "F1356 .M464 2005");
  # 		// LC 999 one letter, decimal digits and space before Cutter
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "999LC1dec", fldName, "D764.7 .K72 1990");
  # 		// LC 999 two letters, space before Cutter
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "999LC2", fldName, "HG6046 .V28 1986");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "999LC22", fldName, "CB3 .A6 SUPPL. V.31");
  # 		// LC 999 two letters, no space before Cutter
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "999LC2NoDec", fldName, "PQ2678.I26 P54 1992");
  # 		// LC 999 three letters, no space before Cutter
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "999LC3NoDec", fldName, "KJH2678.I26 P54 1992");
  # 		// LC 999 three letters, decimal digit, no space before Cutter
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "999LC3Dec", fldName, "KJH666.4.I26 P54 1992");
  # 		// LC 999 three letters, decimal digit, space before Cutter
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "999LC3DecSpace", fldName, "KJH66.6 .I26 P54 1992");
  # 		// LC 999, LC 050, multiple LC facet values, 082 Dewey
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "2913114", fldName, "DH135 .P6 I65");
  # 		// LC 999, LC 050, multiple LC facet values, 082 Dewey
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "3400092", fldName, "DC34.5 .A78 L4 1996");
  #
  # 		// LC 999, LC 050, tough cutter
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "115472", fldName, "HC241.25 .I4 D47");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "1033119", fldName, "BX4659.E85 W44");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "1033119", fldName, "BX4659 .E85 W44 1982");
  # 		// 082 Dewey, LC 999, 050 (same value)
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "1732616", fldName, "QA273 .C83 1962");
  #
  # 		// Lane invalid LC call number, so it is excluded
  # 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, "7233951", fldName, "X578 .S64 1851");
  # 		solrFldMapTest.assertNoSolrFld(testFilePath, "7233951", fldName);
  #
  # 		// non-Lane invalid LC call number so it's included
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "greenX", fldName, "X666 .S666 1666");
  #
  # 		// LCPER 999
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "460947", fldName, "E184.S75 R47A V.1 1980");
  #
  # 		// SUDOC 999
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "5511738", fldName, "Y 4.AG 8/1:108-16");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "2678655", fldName, "GA 1.13:RCED-85-88");
  #
  # 		// ALPHANUM 999
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "4578538", fldName, "SUSEL-69048");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "1261173", fldName, "MFILM N.S. 1350 REEL 230 NO. 3741");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "1234673", fldName, "MCD Brendel Plays Beethoven's Eroica variations");
  # 	}
  #
  #
  # 	/**
  # 	 * callnum_facet_hsim contains the a user friendly hierarchical version of
  # 	 * local Dewey call number topic indicated by the hundred and tens digits of a
  # 	 *  Dewey call number.
  # 	 */
  # @Test
  # 	public final void testDeweyCallnumsFromFile()
  # 	{
  # 		String fldName = "callnum_facet_hsim";
  # 		String firstPart = edu.stanford.CallNumUtils.DEWEY_TOP_FACET_VAL + "|";
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "690002", fldName, firstPart + "100s - Philosophy & Psychology|150s - Psychology");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "2328381", fldName, firstPart + "800s - Literature|820s - English & Old English Literatures");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "1849258", fldName, firstPart + "300s - Social Sciences|350s - Public Administration");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "2214009", fldName, firstPart + "300s - Social Sciences|370s - Education");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "DeweyVol", fldName, firstPart + "600s - Technology|660s - Chemical Engineering");
  # 		// these have leading zeros
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "1", fldName, firstPart + "000s - Computer Science, Information & General Works|000s - Computer Science, Information & General Works");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "11", fldName, firstPart + "000s - Computer Science, Information & General Works|000s - Computer Science, Information & General Works");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "2", fldName, firstPart + "000s - Computer Science, Information & General Works|020s - Library & Information Sciences");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "22", fldName, firstPart + "000s - Computer Science, Information & General Works|020s - Library & Information Sciences");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "3", fldName, firstPart + "900s - History & Geography|990s - General History of Other Areas");
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "31", fldName, firstPart + "900s - History & Geography|990s - General History of Other Areas");
  # 	}
  #

  describe 'callnum_search' do
    let(:field) { 'callnum_search' }

    it 'has the correct data' do
      expect(select_by_id('690002')[field]).to eq(['159.32 .W211'])
      expect(select_by_id('2328381')[field]).to include('827.5 .S97TG')
      expect(select_by_id('1849258')[field]).to include('352.042 .C594 ED.2')
      expect(select_by_id('2214009')[field]).to eq(['370.1 .S655'])
      expect(select_by_id('1')[field]).to eq(['1 .N44'])
      expect(select_by_id('11')[field]).to eq(['1.123 .N44'])
      expect(select_by_id('2')[field]).to eq(['22 .N47'])
      expect(select_by_id('22')[field]).to eq(['22.456 .S655'])
      expect(select_by_id('3')[field]).to eq(['999 .F67'])
      expect(select_by_id('31')[field]).to eq(['999.85 .P84'])
    end

    it 'does not get forbidden call numbers' do
      bad_callnumbers = [
        'NO CALL NUMBER',
        'IN PROCESS',
        'INTERNET RESOURCE',
        'WITHDRAWN',
        'X*', # X call nums (including XX)
        '"Government Document"'
      ]
      all_callnumbers = results.map { |res| res[field] }.flatten
      expect(all_callnumbers).to include('159.32 .W211')
      expect(all_callnumbers).not_to include(*bad_callnumbers)
    end
  end

  #
  # 	// See CallNumFacetSimTests for gov doc call number tests
  #
  # 	/**
  # 	 * access facet should be "Online" for call number "INTERNET RESOURCE"
  # 	 */
  # @Test
  # 	public final void testAccessOnlineFrom999()
  # 	{
  # 		String fldName = "access_facet";
  # 		String fldVal = Access.ONLINE.toString();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "6280316", fldName, fldVal);
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "7117119", fldName, fldVal);
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "7531910", fldName, fldVal);
  # 	}
  #
  #
  # 	/**
  # 	 * test that SHELBYTITL, SHELBYSER and STORBYTITL locations cause call
  # 	 *  numbers to be ignored (not included in facets)
  # 	 */
  # @Test
  # 	public final void testIgnoreShelbyLocations()
  # 	{
  # 		String fldName = "callnum_facet_hsim";
  # 		MarcFactory factory = MarcFactory.newInstance();
  # 		Record record = factory.newRecord();
  # 	    DataField df = factory.newDataField("999", ' ', ' ');
  # 	    df.addSubfield(factory.newSubfield('a', "PQ9661 .P31 C6 1946"));
  # 	    df.addSubfield(factory.newSubfield('w', "LC"));
  # 	    df.addSubfield(factory.newSubfield('i', "36105111222333"));
  # 	    df.addSubfield(factory.newSubfield('l', "SHELBYTITL"));
  # 	    df.addSubfield(factory.newSubfield('m', "SCIENCE"));
  # 	    record.addVariableField(df);
  # 	    df = factory.newDataField("999", ' ', ' ');
  # 	    df.addSubfield(factory.newSubfield('a', "PQ9661 .P31 C6 1946"));
  # 	    df.addSubfield(factory.newSubfield('w', "LC"));
  # 	    df.addSubfield(factory.newSubfield('i', "36105111222333"));
  # 	    df.addSubfield(factory.newSubfield('k', "SHELBYSER"));
  # 	    df.addSubfield(factory.newSubfield('l', "INPROCESS"));
  # 	    df.addSubfield(factory.newSubfield('m', "SCIENCE"));
  # 	    record.addVariableField(df);
  # 	    df = factory.newDataField("999", ' ', ' ');
  # 	    df.addSubfield(factory.newSubfield('a', "PQ9661 .P31 C6 1946"));
  # 	    df.addSubfield(factory.newSubfield('w', "LC"));
  # 	    df.addSubfield(factory.newSubfield('i', "36105111222333"));
  # 	    df.addSubfield(factory.newSubfield('l', "STORBYTITL"));
  # 	    df.addSubfield(factory.newSubfield('m', "SCIENCE"));
  # 	    record.addVariableField(df);
  # 	    solrFldMapTest.assertSolrFldHasNoValue(record, fldName, "PQ9661");
  # 	}
  #
  #
  # 	/**
  # 	 * test that "BUS-PER", "BUSDISPLAY", "NEWS-STKS"
  # 	 * locations cause call numbers to be ignored (not included in facets) when
  # 	 * the library is "BUSINESS"
  # 	 */
  # @Test
  # 	public final void testIgnoreBizShelbyLocations()
  # 	{
  # 		String fldName = "callnum_facet_hsim";
  # 		MarcFactory factory = MarcFactory.newInstance();
  # 		String[] bizShelbyLocs = {"NEWS-STKS"};
  # 		for (String loc : bizShelbyLocs)
  # 		{
  # 			Record record = factory.newRecord();
  # 		    DataField df = factory.newDataField("999", ' ', ' ');
  # 		    df.addSubfield(factory.newSubfield('a', "PQ9661 .P31 C6 1946"));
  # 		    df.addSubfield(factory.newSubfield('w', "LC"));
  # 		    df.addSubfield(factory.newSubfield('i', "36105111222333"));
  # 		    df.addSubfield(factory.newSubfield('l', loc));
  # 		    df.addSubfield(factory.newSubfield('m', "BUSINESS"));
  # 		    record.addVariableField(df);
  # 		    solrFldMapTest.assertSolrFldHasNoValue(record, fldName, edu.stanford.CallNumUtils.LC_TOP_FACET_VAL + "|P - Language & Literature|PQ - French, Italian, Spanish & Portuguese Literature");
  #
  # 		    // don't ignore these locations if used by other libraries
  # 		    df = factory.newDataField("999", ' ', ' ');
  # 		    df.addSubfield(factory.newSubfield('a', "ML9661 .P31 C6 1946"));
  # 		    df.addSubfield(factory.newSubfield('w', "LC"));
  # 		    df.addSubfield(factory.newSubfield('i', "36105444555666"));
  # 		    df.addSubfield(factory.newSubfield('l', loc));
  # 		    df.addSubfield(factory.newSubfield('m', "GREEN"));
  # 		    record.addVariableField(df);
  # 		    solrFldMapTest.assertSolrFldValue(record, fldName, edu.stanford.CallNumUtils.LC_TOP_FACET_VAL + "|M - Music|ML - Literature on Music");
  # 		}
  # 	}
  #
  #
  # 	/**
  # 	 * shelfkey should contain shelving key versions of "lopped" call
  # 	 *  numbers (call numbers without volume info)
  # 	 */
  # @Test
  # 	public final void testShelfkeysInIx()
  # 			throws ParserConfigurationException, IOException, SAXException, SolrServerException
  # 	{
  # 		String fldName = "shelfkey";
  # 		String revFldName = "reverse_shelfkey";
  # 		createFreshIx(fileName);
  #
  # 		// assert searching works
  #
  # 		// LC: no volume info
  # 		String id = "999LC2";
  # 		String callnum = "HG6046 .V28 1986";
  # 		String shelfkey = CallNumberType.LC.getPrefix() + CallNumUtils.getLCShelfkey(callnum, id);
  # 		assertSingleResult(id, fldName, "\"" + shelfkey + "\"");
  # 		// it should be downcased
  # 		assertSingleResult(id, fldName, "\"" + shelfkey.toLowerCase() + "\"");
  # 		String reverseShelfkey = CallNumUtils.getReverseShelfKey(shelfkey);
  # 		assertSingleResult("999LC2", revFldName, "\"" + reverseShelfkey + "\"");
  # 		// it should be downcased
  # 		assertSingleResult("999LC2", revFldName, "\"" + reverseShelfkey.toLowerCase() + "\"");
  #
  # 		// LC: volume info to lop off
  # 		id = "999LC22";
  # 		callnum = "CB3 .A6 SUPPL. V.31";
  # // TODO: suboptimal -  it finds V.31 first, so it doesn't strip suppl.
  # 		shelfkey = CallNumberType.LC.getPrefix() + CallNumUtils.getLCShelfkey("CB3 .A6 SUPPL. ...", id).toLowerCase();
  # 		assertSingleResult(id, fldName, "\"" + shelfkey + "\"");
  # 		reverseShelfkey = CallNumUtils.getReverseShelfKey(shelfkey);
  # 		assertSingleResult("999LC22", revFldName, "\"" + reverseShelfkey + "\"");
  #
  # 		// assert we don't find what we don't expect
  # 		callnum = "NO CALL NUMBER";
  # 		assertZeroResults(fldName, "\"" + callnum + "\"");
  # 		shelfkey = CallNumberType.OTHER.getPrefix() + CallNumUtils.normalizeSuffix(callnum);
  # 		assertZeroResults(fldName, "\"" + shelfkey + "\"");
  # 		reverseShelfkey = CallNumUtils.getReverseShelfKey(shelfkey);
  # 		assertZeroResults(revFldName, "\"" + reverseShelfkey + "\"");
  #
  # 		//   2009-12:  actually, the whole IN PROCESS record is skipped b/c only one withdrawn item
  # 		callnum = "IN PROCESS";
  # 		assertZeroResults(fldName, "\"" + callnum + "\"");
  # 		shelfkey = CallNumberType.OTHER.getPrefix() + CallNumUtils.normalizeSuffix(callnum);
  # 		assertZeroResults(fldName, "\"" + shelfkey + "\"");
  # 		reverseShelfkey = CallNumUtils.getReverseShelfKey(shelfkey);
  # 		assertZeroResults(revFldName, "\"" + reverseShelfkey + "\"");
  #
  # 		// gov doc
  # 		assertZeroResults(fldName, "\"" + govDocStr + "\"");
  # 		shelfkey = CallNumberType.SUDOC.getPrefix() + CallNumUtils.normalizeSuffix(govDocStr);
  # 		assertZeroResults(fldName, "\"" + shelfkey + "\"");
  # 		reverseShelfkey = CallNumUtils.getReverseShelfKey(shelfkey);
  # 		assertZeroResults(revFldName, "\"" + reverseShelfkey + "\"");
  #
  # 		// ASIS 999 "INTERNET RESOURCE"
  # 		callnum = "INTERNET RESOURCE";
  # 		assertZeroResults(fldName, "\"" + callnum + "\"");
  # 		shelfkey = CallNumberType.OTHER.getPrefix() + CallNumUtils.normalizeSuffix(callnum);
  # 		assertZeroResults(fldName, "\"" + shelfkey + "\"");
  # 		reverseShelfkey = CallNumUtils.getReverseShelfKey(shelfkey);
  # 		assertZeroResults(revFldName, "\"" + reverseShelfkey + "\"");
  # 	}
  #
  #
  # 	/**
  # 	 * shelfkey should contain shelving key versions of "lopped" call
  # 	 *  numbers (call numbers without volume info)
  # 	 */
  # @Test
  # 	public final void testShelfkey()
  # 	{
  # 		String fldName = "shelfkey";
  #
  # 		// LC: no volume info
  # 		String id = "999LC2";
  # 		String callnum = "HG6046 .V28 1986";
  # 		String shelfkey = CallNumberType.LC.getPrefix() + CallNumUtils.getLCShelfkey(callnum, id).toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, shelfkey);
  #
  # 		// LC: volume info to lop off
  # 		id = "999LC22";
  # 		callnum = "CB3 .A6 SUPPL. V.31";
  # // TODO: suboptimal -  it finds V.31 first, so it doesn't strip suppl.
  # 		shelfkey = CallNumberType.LC.getPrefix() + CallNumUtils.getLCShelfkey("CB3 .A6 SUPPL. ...", id).toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, shelfkey);
  #
  # 		// LCPER
  # 		id = "460947";
  # 		callnum = "E184.S75 R47A V.1 1980";
  # 		shelfkey = CallNumberType.LC.getPrefix() + CallNumUtils.getLCShelfkey("E184.S75 R47A ...", id).toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, shelfkey);
  #
  # 		//  bad LC values
  # 		solrFldMapTest.assertNoSolrFld(testFilePath, "7370014", "NO CALL NUMBER");
  # 		solrFldMapTest.assertNoSolrFld(testFilePath, "7370014", "lc NO CALL NUMBER");
  # 		solrFldMapTest.assertNoSolrFld(testFilePath, "7370014", "other NO CALL NUMBER");
  # 		//   2009-12:  actually, the whole record is skipped b/c only one withdrawn item
  # //		solrFldMapTest.assertNoSolrFld(testFilePath, "3277173", "IN PROCESS");
  #
  # 		// Dewey: no vol info
  # 		id = "31";
  # 		callnum = "999.85 .P84";
  # 		shelfkey = CallNumberType.DEWEY.getPrefix() + CallNumUtils.getDeweyShelfKey(callnum).toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, shelfkey);
  #
  # 		// Dewey: vol info to lop off
  # 		id = "DeweyVol";
  # 		callnum = "666 .F67 VOL. 5";
  # 		shelfkey = CallNumberType.DEWEY.getPrefix() + CallNumUtils.getDeweyShelfKey("666 .F67 ...").toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, shelfkey);
  #
  # 		// SUDOC 999  -  uses raw callno
  # 		id = "5511738";
  # 		callnum = "Y 4.AG 8/1:108-16";
  # 		shelfkey = CallNumberType.SUDOC.getPrefix() + CallNumUtils.normalizeSuffix(callnum).toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, shelfkey);
  #
  # 		callnum = "GA 1.13:RCED-85-88";
  # 		shelfkey = CallNumberType.SUDOC.getPrefix() + CallNumUtils.normalizeSuffix(callnum).toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "2678655", fldName, shelfkey);
  #
  # 		solrFldMapTest.assertNoSolrFld(testFilePath, "2557826", govDocStr);
  # 		solrFldMapTest.assertNoSolrFld(testFilePath, "5511738", govDocStr);
  # 		solrFldMapTest.assertNoSolrFld(testFilePath, "2678655", govDocStr);
  #
  # 		// ALPHANUM 999 - uses raw callno
  # 		callnum = "SUSEL-69048";
  # 		shelfkey = CallNumberType.OTHER.getPrefix() + CallNumUtils.normalizeSuffix(callnum).toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "4578538", fldName, shelfkey);
  #
  # 		callnum = "MFILM N.S. 1350 REEL 230 NO. 3741";
  # 		shelfkey = CallNumberType.OTHER.getPrefix() + CallNumUtils.normalizeSuffix(callnum).toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "1261173", fldName, shelfkey);
  #
  # 		callnum = "MCD Brendel Plays Beethoven's Eroica variations";
  # 		shelfkey = CallNumberType.OTHER.getPrefix() + CallNumUtils.normalizeSuffix(callnum).toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "1234673", fldName, shelfkey);
  #
  # 		// this is a Lane invalid LC callnum
  # 		id = "7233951";
  # 		callnum = "X578 .S64 1851";
  # 		shelfkey = CallNumberType.OTHER.getPrefix() + CallNumUtils.getLCShelfkey(callnum, id).toLowerCase();
  # 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, id, fldName, shelfkey);
  # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(callnum, CallNumberType.OTHER, id).toLowerCase();
  # 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, id, fldName, shelfkey);
  # 		solrFldMapTest.assertNoSolrFld(testFilePath, id, fldName);
  #
  # 		id = "greenX";
  # 		callnum = "X666 .S666 1666";
  # 		shelfkey = CallNumberType.LC.getPrefix() + CallNumUtils.getLCShelfkey(callnum, id).toLowerCase();
  # 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, id, fldName, shelfkey);
  # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(callnum, CallNumberType.OTHER, id).toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, shelfkey);
  #
  # 		// ASIS 999 "INTERNET RESOURCE": No call number, but access Online
  # 		solrFldMapTest.assertNoSolrFld(testFilePath, "6280316", "INTERNET RESOURCE");
  # 		solrFldMapTest.assertNoSolrFld(testFilePath, "6280316", "other INTERNET RESOURCE");
  # 		solrFldMapTest.assertNoSolrFld(testFilePath, "7117119", "INTERNET RESOURCE");
  # 		solrFldMapTest.assertNoSolrFld(testFilePath, "7117119", "other INTERNET RESOURCE");
  # 		solrFldMapTest.assertNoSolrFld(testFilePath, "7531910", "INTERNET RESOURCE");
  # 		solrFldMapTest.assertNoSolrFld(testFilePath, "7531910", "other INTERNET RESOURCE");
  # 	}
  #
  #
  # 	/**
  # 	 * reverse_shelfkey should contain reverse shelfkey versions of
  # 	 *  "lopped" call numbers (call numbers without volume info). Used for
  # 	 *  sorting backwards.
  # 	 */
  # @Test
  # 	public final void testReverseShelfkey()
  # 	{
  # 		String fldName = "reverse_shelfkey";
  #
  # 		// LC: no volume info
  # 		String id = "999LC2";
  # 		String callnum = "HG6046 .V28 1986";
  # 		String shelfkey = CallNumberType.LC.getPrefix() + CallNumUtils.getLCShelfkey(callnum, id);
  # 		String reverseShelfkey = CallNumUtils.getReverseShelfKey(shelfkey);
  # 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, id, fldName, reverseShelfkey);
  # 		reverseShelfkey = reverseShelfkey.toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, reverseShelfkey);
  #
  # 		// LC: volume info to lop off
  # 		id = "999LC22";
  # 		callnum = "CB3 .A6 SUPPL. V.31";
  # // TODO: suboptimal -  it finds V.31 first, so it doesn't strip suppl.
  # 		String lopped = "CB3 .A6 SUPPL. ...";
  # 		shelfkey = CallNumberType.LC.getPrefix() + CallNumUtils.getLCShelfkey(lopped, id);
  # 		reverseShelfkey = CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, reverseShelfkey);
  #
  # 		// LCPER
  # 		id = "460947";
  # 		callnum = "E184.S75 R47A V.1 1980";
  # 		lopped = "E184.S75 R47A ...";
  # 		shelfkey = CallNumberType.LC.getPrefix() + CallNumUtils.getLCShelfkey(lopped, id);
  # 		reverseShelfkey = CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, reverseShelfkey);
  #
  # 		// Dewey: no vol info
  # 		callnum = "999.85 .P84";
  # 		shelfkey = CallNumberType.DEWEY.getPrefix() + CallNumUtils.getDeweyShelfKey(callnum);
  # 		reverseShelfkey = CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "31", fldName, reverseShelfkey);
  #
  # 		// Dewey: vol info to lop off
  # 		callnum = "352.042 .C594 ED.2";
  # 		lopped = "352.042 .C594 ...";
  # 		shelfkey = CallNumberType.DEWEY.getPrefix() + CallNumUtils.getDeweyShelfKey(lopped);
  # 		reverseShelfkey = CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "1849258", fldName, reverseShelfkey);
  #
  # 		// SUDOC 999
  # 		callnum = "Y 4.AG 8/1:108-16";
  # 		shelfkey = CallNumberType.SUDOC.getPrefix() + CallNumUtils.normalizeSuffix(callnum);
  # 		reverseShelfkey = CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "5511738", fldName, reverseShelfkey);
  #
  # 		callnum = "GA 1.13:RCED-85-88";
  # 		shelfkey = CallNumberType.SUDOC.getPrefix() + CallNumUtils.normalizeSuffix(callnum);
  # 		reverseShelfkey = CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "2678655", fldName, reverseShelfkey);
  #
  # 		// this is a Lane invalid LC callnum
  # 		id = "7233951";
  # 		callnum = "X578 .S64 1851";
  # 		shelfkey = CallNumberType.LC.getPrefix() + CallNumUtils.getLCShelfkey(callnum, id);
  # 		reverseShelfkey = CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
  # 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, id, fldName, reverseShelfkey);
  # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(callnum, CallNumberType.OTHER, id).toLowerCase();
  # 		reverseShelfkey = CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
  # 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, id, fldName, reverseShelfkey);
  # 		solrFldMapTest.assertNoSolrFld(testFilePath, id, fldName);
  #
  # 		id = "greenX";
  # 		callnum = "X666 .S666 1666";
  # 		// it's not processed as LC, but as OTHER
  # 		shelfkey = CallNumberType.LC.getPrefix() + CallNumUtils.getLCShelfkey(callnum, id).toLowerCase();
  # 		reverseShelfkey = CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
  # 		solrFldMapTest.assertSolrFldHasNoValue(testFilePath, id, fldName, reverseShelfkey);
  # 		// it's not processed as LC, but as OTHER
  # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(callnum, CallNumberType.OTHER, id).toLowerCase();
  # 		reverseShelfkey = CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, reverseShelfkey);
  #
  # 		// ALPHANUM 999 - uses raw callno
  # 		callnum = "SUSEL-69048";
  # 		shelfkey = CallNumberType.OTHER.getPrefix() + CallNumUtils.normalizeSuffix(callnum);
  # 		reverseShelfkey = CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "4578538", fldName, reverseShelfkey);
  #
  # 		callnum = "MFILM N.S. 1350 REEL 230 NO. 3741";
  # 		shelfkey = CallNumberType.OTHER.getPrefix() + CallNumUtils.normalizeSuffix(callnum);
  # 		reverseShelfkey = CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "1261173", fldName, reverseShelfkey);
  #
  # 		callnum = "MCD Brendel Plays Beethoven's Eroica variations";
  # 		shelfkey = CallNumberType.OTHER.getPrefix() + CallNumUtils.normalizeSuffix(callnum);
  # 		reverseShelfkey = CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
  # 		solrFldMapTest.assertSolrFldValue(testFilePath, "1234673", fldName, reverseShelfkey);
  #
  # 		// ASIS 999 "INTERNET RESOURCE": No call number, but access Online
  # 		callnum = "INTERNET RESOURCE";
  # 		shelfkey = CallNumberType.OTHER.getPrefix() + CallNumUtils.normalizeSuffix(callnum);
  # 		reverseShelfkey = CallNumUtils.getReverseShelfKey(shelfkey);
  # 		solrFldMapTest.assertNoSolrFld(testFilePath, "6280316", "INTERNET RESOURCE");
  # 		solrFldMapTest.assertNoSolrFld(testFilePath, "7117119", "INTERNET RESOURCE");
  # 		solrFldMapTest.assertNoSolrFld(testFilePath, "7531910", "INTERNET RESOURCE");
  # 	}
  #
  # 	/**
  # 	 * sort keys for call numbers including any volume information
  # 	 */
  # @Test
  # 	public final void testVolumeSortCallnum()
  # 	{
  # 		boolean isSerial = true;
  # 		String reversePeriodStr = new String(CallNumUtils.reverseNonAlphanum('.'));
  # 		String reverseSpaceStr = new String(CallNumUtils.reverseNonAlphanum(' '));
  # 		String reverseHyphenStr = new String(CallNumUtils.reverseNonAlphanum('-'));
  #
  # 		// LC
  # 		String callnum = "M453 .Z29 Q1 L V.2";
  # 		String lopped = "M453 .Z29 Q1 L ...";
  # 		String shelfkey = edu.stanford.CallNumUtils.getShelfKey(lopped, CallNumberType.LC, "fake").toLowerCase();
  # 		assertEquals("lc m   0453.000000 z0.290000 q0.100000 l v.000002", getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.LC, !isSerial, ignoredId));
  # 		String reversePrefix = "lc m   0453.000000 z0.290000 q0.100000 l 4" + reversePeriodStr + "zzzzzx";
  # 		assertTrue("serial volume sort incorrect", getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.LC, isSerial, ignoredId).startsWith(reversePrefix));
  #
  # 		callnum = "M453 .Z29 Q1 L SER.2";
  # 		assertEquals("lc m   0453.000000 z0.290000 q0.100000 l ser.000002", getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.LC, !isSerial, ignoredId));
  # 		reversePrefix = "lc m   0453.000000 z0.290000 q0.100000 l 7l8" + reversePeriodStr + "zzzzzx";
  # 		assertTrue("serial volume sort incorrect", getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.LC, isSerial, ignoredId).startsWith(reversePrefix));
  #
  # 		// dewey
  # 		// suffix year
  # 		callnum = "322.45 .R513 1957";
  # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(callnum, CallNumberType.DEWEY, "fake").toLowerCase();
  # 		assertEquals("dewey 322.45000000 r513 001957",  getVolumeSortCallnum(callnum, callnum, shelfkey, CallNumberType.DEWEY, !isSerial, ignoredId));
  # 		assertEquals("dewey 322.45000000 r513 001957",  getVolumeSortCallnum(callnum, callnum, shelfkey, CallNumberType.DEWEY, isSerial, ignoredId));
  #        // suffix volume
  # 		callnum = "323.09 .K43 V.1";
  # 		lopped = "323.09 .K43";
  # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(lopped, CallNumberType.DEWEY, "fake").toLowerCase();
  # 		assertEquals("dewey 323.09000000 k43 v.000001", getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.DEWEY, !isSerial, ignoredId));
  # 		reversePrefix = "dewey 323.09000000 k43 4" + reversePeriodStr + "zzzzzy";
  # 		assertTrue("serial volume sort incorrect", getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.DEWEY, isSerial, ignoredId).startsWith(reversePrefix));
  # 		// suffix - volume and year
  # 		callnum = "322.44 .F816 V.1 1974";
  # 		lopped = "322.44 .F816";
  # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(lopped, CallNumberType.DEWEY, "fake").toLowerCase();
  # 		assertEquals("dewey 322.44000000 f816 v.000001 001974", getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.DEWEY, !isSerial, ignoredId));
  # 		reversePrefix = "dewey 322.44000000 f816 4" + reversePeriodStr + "zzzzzy" + reverseSpaceStr + "zzyqsv";
  # 		assertTrue("serial volume sort incorrect", getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.DEWEY, isSerial, ignoredId).startsWith(reversePrefix));
  # 		// suffix no.
  # 		callnum = "323 .A512RE NO.23-28";
  # 		lopped = "323 .A512RE";
  # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(lopped, CallNumberType.DEWEY, "fake").toLowerCase();
  # 		assertEquals("dewey 323.00000000 a512re no.000023-000028", getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.DEWEY, !isSerial, ignoredId));
  # 		reversePrefix = "dewey 323.00000000 a512re cb" + reversePeriodStr + "zzzzxw" + reverseHyphenStr + "zzzzxr";
  # // TODO: problem with dewey call numbers with multiple letters at end of cutter
  # //		assertTrue("serial volume sort incorrect", getVolumeSortCallnum(callnum, lopped, isSerial).startsWith(reversePrefix));
  # 	}
  #
  #
  # // NOTE:  Dewey is like LC, except part before cutter is numeric.  Given
  # // how the code works, there is no need to test Dewey in addition to LC.
  #
  # // TODO:  test sorting of call numbers that are neither LC nor Dewey ...
  #
  # 	// list of raw call numbers NOT in order to check sorting
  # 	List<String> lcVolumeUnsortedCallnumList = new ArrayList<String>(25);
  # 	{
  # 		lcVolumeUnsortedCallnumList.add("B8.14 L3 V.4");
  # 		lcVolumeUnsortedCallnumList.add("B8.14 L3 V.3 1947");
  # 		lcVolumeUnsortedCallnumList.add("B8.14 L3 V.1");
  # 		lcVolumeUnsortedCallnumList.add("B8.14 L3 V.3");
  # 		lcVolumeUnsortedCallnumList.add("B8.14 L3 V.2");
  # 		lcVolumeUnsortedCallnumList.add("B8.14 L3 V.2 1959");
  # 		lcVolumeUnsortedCallnumList.add("B8.14 L3 V.1 Suppl");
  # 		lcVolumeUnsortedCallnumList.add("B8.14 L3 V.2 1947");
  # 		lcVolumeUnsortedCallnumList.add("B8.14 L3 V.2 1953");
  # 	}
  #
  # 	// list of raw call numbers in "proper" order for show view of non-serial
  # 	List<String> sortedLCVolCallnumList = new ArrayList<String>(25);
  # 	{
  # 		sortedLCVolCallnumList.add("B8.14 L3 V.1");
  # 		sortedLCVolCallnumList.add("B8.14 L3 V.1 Suppl");
  # 		sortedLCVolCallnumList.add("B8.14 L3 V.2");
  # 		sortedLCVolCallnumList.add("B8.14 L3 V.2 1947");
  # 		sortedLCVolCallnumList.add("B8.14 L3 V.2 1953");
  # 		sortedLCVolCallnumList.add("B8.14 L3 V.2 1959");
  # 		sortedLCVolCallnumList.add("B8.14 L3 V.3");
  # 		sortedLCVolCallnumList.add("B8.14 L3 V.3 1947");
  # 		sortedLCVolCallnumList.add("B8.14 L3 V.4");
  # 	}
  #
  #
  # 	// list of raw call numbers in "proper" order for show view of serial
  # 	List<String> serialSortedLCVolCallnumList = new ArrayList<String>(25);
  # 	{
  # 		serialSortedLCVolCallnumList.add("B8.14 L3 V.4");
  # 		serialSortedLCVolCallnumList.add("B8.14 L3 V.3 1947");
  # 		serialSortedLCVolCallnumList.add("B8.14 L3 V.3");
  # 		serialSortedLCVolCallnumList.add("B8.14 L3 V.2 1959");
  # 		serialSortedLCVolCallnumList.add("B8.14 L3 V.2 1953");
  # 		serialSortedLCVolCallnumList.add("B8.14 L3 V.2 1947");
  # 		serialSortedLCVolCallnumList.add("B8.14 L3 V.2");
  # 		serialSortedLCVolCallnumList.add("B8.14 L3 V.1 Suppl");
  # 		serialSortedLCVolCallnumList.add("B8.14 L3 V.1");
  # 	}
  #
  #
  # 	/**
  # 	 * test the sort of call numbers (for non-serials) with volume portion
  # 	 */
  # @Test
  # 	public void testLCVolumeSorting()
  # 	{
  # 		String lopped = "B8.14 L3";
  # 		String shelfkey = edu.stanford.CallNumUtils.getShelfKey(lopped, CallNumberType.LC, "fake").toLowerCase();
  # 		// compute list: non-serial volume sorting
  # 		Map<String,String> volSortString2callnum = new HashMap<String,String>(75);
  # 		for (String callnum : lcVolumeUnsortedCallnumList) {
  # 			volSortString2callnum.put(getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.LC, !isSerial, ignoredId), callnum);
  # 		}
  # 		List<String> ordered = new ArrayList<String>(volSortString2callnum.keySet());
  # 		Collections.sort(ordered);
  #
  # 		for (int i = 0; i < ordered.size(); i++) {
  # 			assertEquals("At position " + i + " in list: ", sortedLCVolCallnumList.get(i), volSortString2callnum.get(ordered.get(i)));
  # 		}
  # 	}
  #
  # 	/**
  # 	 * test the sort of call numbers (for serials) with volume portion
  # 	 */
  # @Test
  # 	public void testLCSerialVolumeSorting()
  # 	{
  # 		String lopped = "B8.14 L3";
  # 		String shelfkey = edu.stanford.CallNumUtils.getShelfKey(lopped, CallNumberType.LC, "fake").toLowerCase();
  # 		// compute list: non-serial volume sorting
  # 		Map<String,String> volSortString2callnum = new HashMap<String,String>(75);
  # 		for (String callnum : lcVolumeUnsortedCallnumList) {
  # 			volSortString2callnum.put(getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.LC, isSerial, ignoredId), callnum);
  # 		}
  # 		List<String> ordered = new ArrayList<String>(volSortString2callnum.keySet());
  # 		Collections.sort(ordered);
  #
  # 		for (int i = 0; i < ordered.size(); i++) {
  # 			assertEquals("At position " + i + " in list: ", serialSortedLCVolCallnumList.get(i), volSortString2callnum.get(ordered.get(i)));
  # 		}
  # 	}
  #
  # 	/**
  # 	 * test that the volume sorting is correct
  # 	 */
  # @Test
  # 	public final void testVolumeSortingCorrect()
  # 	{
  # 		List<String> unsortedDeweyVolSortList = new ArrayList<String>(25);
  # 		unsortedDeweyVolSortList.add("570.5 .N287 V.34:NO.2 1941");
  # 		unsortedDeweyVolSortList.add("570.5 .N287 V.34:NO.3 1941");
  # 		unsortedDeweyVolSortList.add("570.5 .N287 V.32:NO.4 1939");
  # 		unsortedDeweyVolSortList.add("570.5 .N287 V.34:NO.1 1941");
  # 		unsortedDeweyVolSortList.add("570.5 .N287 V.1-2 1923");
  # 		unsortedDeweyVolSortList.add("570.5 .N287 V.28:NO.2 1936:AUG.");
  # 		unsortedDeweyVolSortList.add("570.5 .N287 V.7-8 1926");
  # 		unsortedDeweyVolSortList.add("570.5 .N287 V.9-10 1927");
  # 		unsortedDeweyVolSortList.add("570.5 .N287 V.11-12 1928");
  # 		unsortedDeweyVolSortList.add("570.5 .N287 V.3-4 1924");
  # 		unsortedDeweyVolSortList.add("570.5 .N287 V.23-24 1934");
  # 		unsortedDeweyVolSortList.add("570.5 .N287 V.25-26 1935");
  # 		unsortedDeweyVolSortList.add("570.5 .N287 V.21-22 1933");
  # 		unsortedDeweyVolSortList.add("570.5 .N287 V.29-30 1937");
  # 		unsortedDeweyVolSortList.add("570.5 .N287 V.17-18 1931");
  # 		unsortedDeweyVolSortList.add("570.5 .N287 V.33:NO.2-10 1940");
  # 		unsortedDeweyVolSortList.add("570.5 .N287 V.5-6 1925");
  # 		unsortedDeweyVolSortList.add("570.5 .N287 V.15-16 1930");
  # 		unsortedDeweyVolSortList.add("570.5 .N287 V.13-14 1929");
  # 		unsortedDeweyVolSortList.add("570.5 .N287 V.19-20 1932");
  #
  #
  # 		// list of raw call numbers in "proper" order for show view of serial
  # 		List<String> sortedDeweyVolSortList = new ArrayList<String>(25);
  # 		sortedDeweyVolSortList.add("570.5 .N287 V.34:NO.3 1941");
  # 		sortedDeweyVolSortList.add("570.5 .N287 V.34:NO.2 1941");
  # 		sortedDeweyVolSortList.add("570.5 .N287 V.34:NO.1 1941");
  # 		sortedDeweyVolSortList.add("570.5 .N287 V.33:NO.2-10 1940");
  # 		sortedDeweyVolSortList.add("570.5 .N287 V.32:NO.4 1939");
  # 		sortedDeweyVolSortList.add("570.5 .N287 V.29-30 1937");
  # 		sortedDeweyVolSortList.add("570.5 .N287 V.28:NO.2 1936:AUG.");
  # 		sortedDeweyVolSortList.add("570.5 .N287 V.25-26 1935");
  # 		sortedDeweyVolSortList.add("570.5 .N287 V.23-24 1934");
  # 		sortedDeweyVolSortList.add("570.5 .N287 V.21-22 1933");
  # 		sortedDeweyVolSortList.add("570.5 .N287 V.19-20 1932");
  # 		sortedDeweyVolSortList.add("570.5 .N287 V.17-18 1931");
  # 		sortedDeweyVolSortList.add("570.5 .N287 V.15-16 1930");
  # 		sortedDeweyVolSortList.add("570.5 .N287 V.13-14 1929");
  # 		sortedDeweyVolSortList.add("570.5 .N287 V.11-12 1928");
  # 		sortedDeweyVolSortList.add("570.5 .N287 V.9-10 1927");
  # 		sortedDeweyVolSortList.add("570.5 .N287 V.7-8 1926");
  # 		sortedDeweyVolSortList.add("570.5 .N287 V.5-6 1925");
  # 		sortedDeweyVolSortList.add("570.5 .N287 V.3-4 1924");
  # 		sortedDeweyVolSortList.add("570.5 .N287 V.1-2 1923");
  #
  # //		// compute list: non-serial volume sorting
  # //		Map<String,String> volSortString2callnum = new HashMap<String,String>(75);
  # //		for (String callnum : unsortedDeweyVolSortList) {
  # //			volSortString2callnum.put(getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.LC, isSerial, ignoredId), callnum);
  # //		}
  # //
  # //		String shelfkey = edu.stanford.CallNumUtils.getShelfKey(lopped, CallNumberType.LC, "fake").toLowerCase();
  #
  # 		boolean isSerial = true;
  # 		String lopped = "570.5 .N287 ...";
  # 		String loppedShelfkey = edu.stanford.CallNumUtils.getShelfKey(lopped, CallNumberType.DEWEY, ignoredId);
  # 		// compute list: serial volume sorting
  # 		Map<String,String> volSortString2callnum = new HashMap<String,String>(75);
  # 		for (String callnum : unsortedDeweyVolSortList) {
  # 			volSortString2callnum.put(getVolumeSortCallnum(callnum, lopped, loppedShelfkey, CallNumberType.DEWEY, isSerial, ignoredId), callnum);
  # 		}
  #
  # 		List<String> ordered = new ArrayList<String>(volSortString2callnum.keySet());
  # 		Collections.sort(ordered);
  #
  # 		for (int i = 0; i < ordered.size(); i++) {
  # 			assertEquals("At position " + i + " in list: ", sortedDeweyVolSortList.get(i), volSortString2callnum.get(ordered.get(i)));
  # 		}
  # 	}
  #
  # }
end
