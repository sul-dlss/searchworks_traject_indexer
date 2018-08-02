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

  describe 'isbn_display [the ISBNs used for external lookups (e.g. Google Book Search)]' do
    let(:fixture_name) { 'isbnTests.mrc' }
    let(:field) { 'isbn_display' }

    it 'has the correct data' do#
      # no isbn
      expect(select_by_id('No020')[field]).to be_nil
      expect(select_by_id('020noSubaOrz')[field]).to be_nil

      # 020 subfield a 10 digit varieties
      expect(select_by_id('020suba10digit')[field]).to eq(['1417559128'])
      expect(select_by_id('020suba10endsX')[field]).to eq(['123456789X'])
      expect(select_by_id('020suba10trailingText')[field]).to eq(
        ['1234567890', '0123456789', '0521672694', '052185668X']
      )
#
# 		# 020 subfield a 13 digit varieties
      expect(select_by_id('020suba13')[field]).to eq(['9780809424887'])
      expect(select_by_id('020suba13endsX')[field]).to eq(['979123456789X'])
      expect(select_by_id('020suba13bad')[field]).to be_nil
      expect(select_by_id('020suba13trailingText')[field]).to eq(['978185585039X', '9780809424887', '9780809424870'])

      # sub a mixed 10 and 13 digit
      expect(select_by_id('020subaMult')[field]).to eq(
        ['0809424886', '123456789X', '1234567890', '979123456789X', '9780809424887', '9781855850484']
      )

      # no subfield a in 020, but has subfield z 10 digit
      expect(select_by_id('020subz10digit')[field]).to eq(['9876543210'])
      expect(select_by_id('020subz10endsX')[field]).to eq(['123456789X'])
      expect(select_by_id('020subz10trailingText')[field]).to eq(
        ['1234567890', '0123456789', '0521672694']
      )

      # no subfield a in 020, but has subfield z 13 digit
      expect(select_by_id('020subz13digit')[field]).to eq(['9780809424887'])
      expect(select_by_id('020subz13endsX')[field]).to eq(['979123456789X'])
      expect(select_by_id('020subz13trailingText')[field]).to eq(
        ['978185585039X', '9780809424887', '9780809424870']
      )

      # mult subfield z in single 020
      expect(select_by_id('020multSubz')[field].sort).to eq(
        [
          '9802311987',
          '9802311995',
          '9802312002',
          '9876543210',
          '123456789X',
          '9780809424887',
          '979123456789X',
          '9780809424870'
        ].sort
      )

      # mult a and z - should only have a
      expect(select_by_id('020SubaAndz')[field]).to eq(
        ['0123456789', '0521672694', '052185668X']
      )
    end
  end

  describe 'isbn_search' do
    let(:fixture_name) { 'isbnTests.mrc' }
    let(:field) { 'isbn_search' }

    it 'has the correct data' do
      expect(select_by_id('020suba10trailingText')[field]).to include('052185668X')
      expect(select_by_id('020SubaAndz')[field]).to include('052185668X')

      # isbn search with sub z value from record with mult a and z
      expect(select_by_id('020suba13')[field]).to include('9780809424887')
      expect(select_by_id('020suba13trailingText')[field]).to include('9780809424887')
      expect(select_by_id('020subaMult')[field]).to include('9780809424887')
      expect(select_by_id('020subz13digit')[field]).to include('9780809424887')
      expect(select_by_id('020subz13trailingText')[field]).to include('9780809424887')
      expect(select_by_id('020multSubz')[field]).to include('9780809424887')
      expect(select_by_id('020SubaAndz')[field]).to include('9780809424887')
      expect(select_by_id('774z')[field]).to eq(['0001112223'])
    end
  end

  describe 'issn_display' do
    let(:fixture_name) { 'issnTests.mrc' }
    let(:field) { 'issn_display' }

    it 'has the correct data' do
      # no issn
      expect(select_by_id('No022')[field]).to be_nil
      expect(select_by_id('022subaNoHyphen')[field]).to be_nil
      expect(select_by_id('022subaTooManyChars')[field]).to be_nil

      # 022 single subfield
      expect(select_by_id('022suba')[field]).to eq(['1047-2010'])
      expect(select_by_id('022subaX')[field]).to eq(['1047-201X'])
      expect(select_by_id('022subL')[field]).to be_nil
      expect(select_by_id('022subM')[field]).to be_nil
      expect(select_by_id('022subY')[field]).to be_nil
      expect(select_by_id('022subZ')[field]).to eq(['1144-585X'])

      # 022 mult subfields
      expect(select_by_id('022subAandL')[field]).to eq(['0945-2419'])
      expect(select_by_id('022subLandM')[field]).to be_nil
      expect(select_by_id('022subMandZ')[field]).to eq(['1144-5858'])
      expect(select_by_id('Two022a')[field]).to eq(['0666-7770', '1221-2112'])
    end

    describe 'lane records' do
      let(:records) { MARC::XMLReader.new(file_fixture(fixture_name).to_s).to_a }
      let(:fixture_name) { 'issnTestsLane.xml' }

      it 'has the correct data' do
        # no issn
        expect(select_by_id('No022')[field]).to be_nil
        expect(select_by_id('022subaNoHyphen')[field]).to be_nil
        expect(select_by_id('022subaTooManyChars')[field]).to be_nil

        # 022 single subfield
        expect(select_by_id('022suba')[field]).to eq(['1047-2010 (Print)'])
        expect(select_by_id('022subaX')[field]).to eq(['1047-201X (Print)'])

        # 022 mult subfields
        expect(select_by_id('022subAandL')[field]).to eq(['0945-2419 (Print)'])
        expect(select_by_id('022subLandM')[field]).to be_nil
      end
    end
  end

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

  describe 'lccn' do
    let(:fixture_name) { 'lccnTests.mrc' }
    let(:field) { 'lccn' }

    it 'has the correct data' do
      # no lccn
      expect(select_by_id('No010')[field]).to be_nil

      # TODO:  the 9 digit lccn passes.  I don't know why.  I no longer care.
      # solrFldMapTest.assertNoSolrFld(testFilePath, "010bad", fldName);
      # converted for rspec
      # expect(select_by_id('010bad')[field]).to be_nil

      # 010 sub a only
      expect(select_by_id('010suba8digit')[field]).to eq(['85153773'])
      expect(select_by_id('010suba10digit')[field]).to eq(['2001627090'])

      # prefix
      expect(select_by_id('010suba8digitPfx')[field]).to eq(['a  60123456'])
      expect(select_by_id('010suba8digit2LetPfx')[field]).to eq(['bs 66654321'])
      expect(select_by_id('010suba8digit3LetPfx')[field]).to eq(['cad77665544'])

      # according to loc marc doc, shouldn't have prefix for 10 digit, but
      # what the heck - let's test
      expect(select_by_id('010suba10digitPfx')[field]).to eq(['r 2001336783'])
      expect(select_by_id('010suba10digit2LetPfx')[field]).to eq(['ne2001045944'])

      # suffix
      expect(select_by_id('010suba8digitSfx')[field]).to eq(['79139101'])
      expect(select_by_id('010suba10digitSfx')[field]).to eq(['2006002284'])
      expect(select_by_id('010suba8digitSfx2')[field]).to eq(['73002284'])

      # sub z
      expect(select_by_id('010subz')[field]).to eq(['20072692384'])
      expect(select_by_id('010subaAndZ')[field]).to eq(['76647633'])
      expect(select_by_id('010multSubZ')[field]).to eq(['76647633'])
    end
  end
end
