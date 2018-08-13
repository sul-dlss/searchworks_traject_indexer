RSpec.describe 'ItemInfo config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end

  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }
  let(:fixture_name) { 'subjectSearchTests.mrc' }
  subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }

  describe 'barcode_search' do
    let(:fixture_name) { 'locationTests.mrc' }
    let(:field) { 'barcode_search'}

    it 'has data' do
      # Single barcode
      result = select_by_id('115472')[field]
      expect(result).to eq ['36105033811451']
      # many barcodes
      result = select_by_id('1033119')[field]
      expect(result).to eq %w[36105037439663 36105001623284]
    end
  end

  describe 'building_facet' do
    let(:records) { MARC::XMLReader.new(file_fixture(fixture_name).to_s).to_a }
    let(:fixture_name) { 'buildingTests.xml' }
    let(:field) { 'building_facet' }

    it 'has data' do
      expect(select_by_id('229800')[field]).to eq ['Archive of Recorded Sound']
      expect(select_by_id('345228')[field]).to eq ['Art & Architecture (Bowes)']
      expect(select_by_id('804724')[field]).to eq ['SAL Newark (off-campus storage)']
      expect(select_by_id('1147269')[field]).to eq ['Classics']
      expect(select_by_id('1505065')[field]).to eq ['Earth Sciences (Branner)']
      expect(select_by_id('1618836')[field]).to eq ['Education (Cubberley)']
      expect(select_by_id('1849258')[field]).to eq ['Engineering (Terman)']
      expect(select_by_id('2678655')[field]).to eq ['Business']
      expect(select_by_id('3027805')[field]).to eq ['Marine Biology (Miller)']
      expect(select_by_id('4258089')[field]).to eq ['Special Collections']
      expect(select_by_id('4428936')[field]).to eq ['Philosophy (Tanner)']
      expect(select_by_id('4823592')[field]).to eq ['Law (Crown)']
      expect(select_by_id('5666387')[field]).to eq ['Music']
      expect(select_by_id('6676531')[field]).to eq ['East Asia']
      expect(select_by_id('10421123')[field]).to eq ['Lathrop']
      expect(select_by_id('2797608')[field]).to eq ['Media & Microtext Center']
      expect(select_by_id('2797609')[field]).to eq ['David Rumsey Map Center']
      expect(select_by_id('11847684')[field]).to eq ['Science (Li and Ma)']

      # Green

      expect(select_by_id('1033119')[field]).to include 'Green'
      expect(select_by_id('1261173')[field]).to include 'Green'
      expect(select_by_id('2557826')[field]).to include 'Green'
      expect(select_by_id('3941911')[field]).to include 'Green'
      expect(select_by_id('4114632')[field]).to include 'Green'
      expect(select_by_id('2099904')[field]).to include 'Green'
      # checked out
      expect(select_by_id('575946')[field]).to include 'Green'
      # NOT  3277173  (withdrawn)

      # SAL 1 & 2
      expect(select_by_id('1033119')[field]).to include 'SAL1&2 (on-campus shelving)'
      expect(select_by_id('1962398')[field]).to include 'SAL1&2 (on-campus shelving)'
      expect(select_by_id('2328381')[field]).to include 'SAL1&2 (on-campus shelving)'
      expect(select_by_id('2913114')[field]).to include 'SAL1&2 (on-campus shelving)'

      # SAL3 (off-campus storage)
      expect(select_by_id('690002')[field]).to include 'SAL3 (off-campus storage)'
      expect(select_by_id('2328381')[field]).to include 'SAL3 (off-campus storage)'
      expect(select_by_id('3941911')[field]).to include 'SAL3 (off-campus storage)'
      expect(select_by_id('7651581')[field]).to include 'SAL3 (off-campus storage)'

      # Lane
      expect(select_by_id('7370014')[field]).to include 'Medical (Lane)'
      expect(select_by_id('7233951')[field]).to include 'Medical (Lane)'

      # Hoover
      expect(select_by_id('3743949')[field]).to include 'Hoover Library'
      expect(select_by_id('3400092')[field]).to include 'Hoover Archives'
    end

    it 'skips invalid buildings' do
      buildings = []
      results.map do |result|
        buildings << result[field]
      end

      expect(buildings.flatten).not_to include(
        'APPLIEDPHY', # Applied Physics Department
        'CPM', # 1391080 GREEN - Current Periodicals & Microtext
        'GRN-REF', # 2442876, GREEN - Reference - Obsolete
        'ILB', # 1111, Inter-Library Borrowing
        'SPEC-DESK', # GREEN (Humanities & Social Sciences)
        'SUL',
        'PHYSICS', # Physics Library
        'MEYER', # INDEX-168 Meyer
        'BIOLOGY', # closed
        'CHEMCHMENG', # closed
        'MATH-CS' # closed
      )
    end
  end

  describe 'item_display' do
    let(:field) { 'item_display' }

    describe 'field is populated correctly, focusing on building/library' do
      let(:fixture_name) { 'buildingTests.mrc' }

      it 'APPLIEDPHY ignored for building facet, but not here' do
        expect(select_by_id('115472')[field].length).to eq 1
        expect(select_by_id('115472')[field].first).to include('-|- APPLIEDPHY -|-')
      end

      it 'inlcudes various libraries' do
        sample_libs_and_ids = {
          'ART': '345228',
          'CLASSICS': '1147269',
          'ENG': '1849258',
          'GOV-DOCS': '2099904',
          'GREEN': '1261173',
          'HOOVER': '3743949',
          'SAL3': '690002',
          'SCIENCE': '460947',
          'SPEC-COLL': '4258089'
        }

        sample_libs_and_ids.each do |library, id|
          expect(select_by_id(id)[field].length).to be >= 1
          expect(select_by_id(id)[field]).to be_any do |field|
            field.include?("-|- #{library} -|-")
          end
        end
      end

      it 'handles multiple items in single record, diff buildings' do
        expect(select_by_id('1033119')[field].length).to eq 2

        expect(select_by_id('1033119')[field].first).to match(
          /^36105037439663 -\|- GREEN -\|- .*BX4659\.E85 W44/
        )

        expect(select_by_id('1033119')[field].last).to match(
          /^36105001623284 -\|- SAL -\|- .*BX4659 \.E85 W44 1982/
        )
      end

      it 'handles same build, same loc, same callnum, one in another building' do
        expect(select_by_id('2328381')[field].length).to eq 3

        expect(select_by_id('2328381')[field][0]).to match(
          /^36105003934432 -\|- SAL -\|- .*PR3724\.T3/
        )
        expect(select_by_id('2328381')[field][1]).to match(
          /^36105003934424 -\|- SAL -\|- .*PR3724\.T3/
        )

        expect(select_by_id('2328381')[field][2]).to match(
          /^36105048104132 -\|- SAL3 -\|- .*827\.5 \.S97TG/
        )
      end

      describe 'with item display fixture' do
        let(:fixture_name) { 'itemDisplayTests.mrc' }

        it 'handles materials in LANE' do
          expect(select_by_id('6661112')[field].length).to eq 1
          expect(select_by_id('6661112')[field].first).to match(
            /^36105082101390 -\|- LANE-MED -\|- .*Z3871\.Z8 V\.22 1945/
          )
        end

        it 'handles mult items same build, diff loc' do
          expect(select_by_id('2328381')[field].length).to eq 3

          expect(select_by_id('2328381')[field][0]).to match(
            /^36105003934432 -\|- GREEN -\|- .*PR3724\.T3/
          )
          expect(select_by_id('2328381')[field][1]).to match(
            /^36105003934424 -\|- GREEN -\|- .*PR3724\.T3/
          )

          expect(select_by_id('2328381')[field][2]).to match(
            /^36105048104132 -\|- GRN-REF -\|- .*827\.5 \.S97TG/
          )
        end
      end

      describe 'field is populated correctly, focusing on locations' do
        it 'includes valious locations' do
          sample_ids_and_locs = {
            '229800': %w[STACKS],
            '3941911': %w[STACKS BENDER],
            '6676531': %w[JAPANESE],
            '1261173': %w[MEDIA-MTXT],
            '7233951': %w[ASK@LANE],
            '1962398': %w[SAL-PAGE],
            '2913114': %w[SAL-PAGE],
            '7651581': %w[INPROCESS],
            '2557826': %w[FED-DOCS]
          }

          sample_ids_and_locs.each do |id, locations|
            data = select_by_id(id.to_s)[field]
            expect(data.length).to be >= 1
            locations.each do |location|
              expect(data).to be_any do |field|
                field.include?("-|- #{location} -|-")
              end
            end
          end
        end

        it 'handles one withdrawn location, one valid properly' do
          data = select_by_id('2214009')[field]
          # 36105033336798 is WITHDRAWN and should not be returned
          expect(data.length).to eq 1
          expect(data.first).to match(/^36105033336780 -\|- SAL3 -\|- STACKS/)
        end

        context 'with a different fixture' do
          let(:fixture_name) { 'itemDisplayTests.mrc' }

          it 'handles on order locations' do
            data = select_by_id('460947')[field]
            expect(data.length).to eq 2
            expect(data.first).to match(
              /^36105007402873 -\|- GREEN -\|- ON-ORDER .* E184\.S75 R47A V\.1 1980/
            )
          end

          it 'handles reserve locations' do
            expect(select_by_id('690002')[field].length).to eq 1
            expect(select_by_id('690002')[field].first).to match(
              /^36105046693508 -\|- EARTH-SCI -\|- BRAN-RESV/
            )
          end

          it 'handles mult items same build, diff loc' do
            expect(select_by_id('2328381')[field].length).to eq 3
            expect(select_by_id('2328381')[field][0]).to match(
              /^36105003934432 -\|- GREEN -\|- STACKS/
            )

            expect(select_by_id('2328381')[field][1]).to match(
              /^36105003934424 -\|- GREEN -\|- BINDERY/
            )

            expect(select_by_id('2328381')[field][2]).to match(
              /^36105048104132 -\|- GRN-REF -\|- STACKS/
            )
          end

          it 'hanldes multiple items for single bib with same library / location, diff callnum' do
            expect(select_by_id('666')[field].length).to eq 3
            expect(select_by_id('666')[field][0]).to match(
              /^36105003934432 -\|- GREEN -\|- STACKS/
            )

            expect(select_by_id('666')[field][1]).to match(
              /^36105003934424 -\|- GREEN -\|- STACKS/
            )

            expect(select_by_id('666')[field][2]).to match(
              /^36105048104132 -\|- GREEN -\|- STACKS/
            )
          end
        end
      end
    end

    describe 'displays home location' do
      let(:fixture_name) { 'buildingTests.mrc' }

      it 'CHECKEDOUT as current location, STACKS as home location' do
        expect(select_by_id('575946')[field].length).to eq 2
        expect(select_by_id('575946')[field].first).to match(
          /^36105035087092 -\|- GREEN -\|- STACKS -\|- CHECKEDOUT -/
        )

        expect(select_by_id('575946')[field].last).to match(
          /^36105035087093 -\|- GREEN -\|- STACKS -\|- CHECKEDOUT -/
        )
      end

      it 'WITHDRAWN as current location implies item is skipped' do
        expect(select_by_id('3277173')[field]).to be_nil
      end
    end

    pending 'location implies item is shelved by title' do
      let(:fixture_name) { 'callNumberLCSortTests.mrc' }

      it 'handles SHELBYTITL' do
        expect(select_by_id('1111')[field].length).to eq 1
        expect(select_by_id('1111')[field].first).to match(
          /^36105129694373 -\|- SCIENCE -\|- SHELBYTITL .* Shelved by title/
        )
      end

      # 		// callnum for all three is  PQ9661 .P31 C6 VOL 1 1946"
      # 		// STORBYTITL
      # 	    fldVal = "36105129694375 -|- SCIENCE -|- STORBYTITL" + SEP + SEP + "STKS-MONO" + SEP +
      # 				callnum + SEP + shelfkey + SEP + reversekey + SEP + show_view_callnum + SEP + volSort + SEP + SEP + CallNumberType.LC;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, "3311", fldName, fldVal);

      # 		// SHELBYSER
      # 		id = "2211";
      # 		callnum = "Shelved by Series title";
      # 		shelfkey = callnum.toLowerCase();
      # 		reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		show_view_callnum = callnum + " VOL 1 1946";
      # 		volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(show_view_callnum, callnum, shelfkey, CallNumberType.OTHER, isSerial, id);
      # 		fldVal = "36105129694374 -|- SCIENCE -|- SHELBYSER" + SEP + SEP + "STKS-MONO" + SEP +
      # 				callnum + SEP + shelfkey + SEP + reversekey + SEP + show_view_callnum + SEP + volSort + SEP + SEP + CallNumberType.LC;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, fldVal);

      # 	/**
      # 	 * test that "BUS-PER", "BUSDISPLAY", "NEWS-STKS"
      # 	 * locations cause call numbers to be ignored (not included in facets) when
      # 	 * the library is "BUSINESS"
      # 	 */
      # @Test
      # 	public final void testItemDisplayBizShelbyLocs()
      # 			throws ParserConfigurationException, IOException, SAXException
      # 	{
      # 		String fldName = "item_display";
      # 		MarcFactory factory = MarcFactory.newInstance();
      # 		String callnum = "Shelved by title";
      # 		String shelfkey = callnum.toLowerCase();
      # 		String reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		String show_view_callnum = callnum + " VOL 1 1946";
      # 		String volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(show_view_callnum, callnum, shelfkey, CallNumberType.LC, isSerial, null);
      #
      # 		String fullCallNum = "E184.S75 R47A V.1 1980";
      # 		String fullShelfkey = edu.stanford.CallNumUtils.getShelfKey(fullCallNum, CallNumberType.LC, null).toLowerCase();
      # 		String fullReversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(fullShelfkey).toLowerCase();
      # 		String fullVolSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(fullCallNum, fullCallNum, fullShelfkey, CallNumberType.LC, isSerial, null);
      #
      # 		String otherCallnum = "BUS54594-11 V.3 1986 MAY-AUG.";
      # 		String otherShowViewCallnum = callnum + " V.3 1986 MAY-AUG.";
      # 		String otherVolSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(otherShowViewCallnum, callnum, shelfkey, CallNumberType.OTHER, isSerial, null);
      #
      # 		Leader ldr = factory.newLeader("01247cas a2200337 a 4500");
      # 		ControlField cf008 = factory.newControlField("008");
      # 		cf008.setData("830415c19809999vauuu    a    0    0eng  ");
      #
      # 		String[] bizShelbyLocs = {"NEWS-STKS"};
      # 		for (String loc : bizShelbyLocs)
      # 		{
      # 			Record record = factory.newRecord();
      # 			record.setLeader(ldr);
      # 			record.addVariableField(cf008);
      # 		    DataField df = factory.newDataField("999", ' ', ' ');
      # 		    df.addSubfield(factory.newSubfield('a', "PQ9661 .P31 C6 VOL 1 1946"));
      # 		    df.addSubfield(factory.newSubfield('w', "LC"));
      # 		    df.addSubfield(factory.newSubfield('i', "36105111222333"));
      # 		    df.addSubfield(factory.newSubfield('l', loc));
      # 		    df.addSubfield(factory.newSubfield('m', "BUSINESS"));
      # 		    record.addVariableField(df);
      # 			String expFldVal = "36105111222333 -|- BUSINESS -|- " + loc + SEP + SEP + SEP +
      # 					callnum + SEP + shelfkey + SEP + reversekey + SEP + show_view_callnum + SEP + volSort + SEP + SEP + CallNumberType.LC;
      # 		    solrFldMapTest.assertSolrFldValue(record, fldName, expFldVal);
      #
      # 			record = factory.newRecord();
      # 			record.setLeader(ldr);
      # 			record.addVariableField(cf008);
      # 		    df = factory.newDataField("999", ' ', ' ');
      # 		    df.addSubfield(factory.newSubfield('a', otherCallnum));
      # 		    df.addSubfield(factory.newSubfield('w', "ALPHANUM"));
      # 		    df.addSubfield(factory.newSubfield('i', "20504037816"));
      # 		    df.addSubfield(factory.newSubfield('l', loc));
      # 		    df.addSubfield(factory.newSubfield('m', "BUSINESS"));
      # 		    record.addVariableField(df);
      # 			expFldVal = "20504037816 -|- BUSINESS -|- " + loc + SEP + SEP + SEP +
      # 					callnum + SEP +
      # 					shelfkey + SEP +
      # 					reversekey + SEP +
      # 					otherShowViewCallnum + SEP +
      # 					otherVolSort + SEP + SEP + CallNumberType.ALPHANUM;
      # 		    solrFldMapTest.assertSolrFldValue(record, fldName, expFldVal);
      #
      #
      # 		    // don't treat these locations specially if used by other libraries
      # 			record = factory.newRecord();
      # 			record.setLeader(ldr);
      # 			record.addVariableField(cf008);
      # 		    df = factory.newDataField("999", ' ', ' ');
      # 		    df.addSubfield(factory.newSubfield('a', fullCallNum));
      # 		    df.addSubfield(factory.newSubfield('w', "LC"));
      # 		    df.addSubfield(factory.newSubfield('i', "36105444555666"));
      # 		    df.addSubfield(factory.newSubfield('l', loc));
      # 		    df.addSubfield(factory.newSubfield('m', "GREEN"));
      # 		    record.addVariableField(df);
      # 			expFldVal = "36105444555666 -|- GREEN -|- " + loc + SEP + SEP + SEP +
      # 					fullCallNum + SEP + fullShelfkey + SEP + fullReversekey + SEP + fullCallNum + SEP + fullVolSort + SEP + SEP + CallNumberType.LC;
      # 		    solrFldMapTest.assertSolrFldValue(record, fldName, expFldVal);
      # 		}
      # 	}
      #
    end

    describe 'locations should not be displayed' do
      let(:fixture_name) { 'locationTests.mrc' }

      it 'do not return an item_display' do
        expect(select_by_id('345228')[field]).to be_nil
        expect(select_by_id('575946')[field]).to be_nil
        expect(select_by_id('804724')[field]).to be_nil
        expect(select_by_id('1033119')[field]).to be_nil
        expect(select_by_id('1505065')[field]).to be_nil

        # INPROCESS - keep it
        expect(select_by_id('7651581')[field].length).to eq 1
        expect(select_by_id('7651581')[field].first).to match(
          /^36105129694373 -\|- SAL3 -\|- INPROCESS/
        )
      end
    end

    describe 'when location is to be left "as is"  (no translation in map, but don\'t skip)' do
      let(:fixture_name) { 'mediaLocTests.mrc' }

      it 'has the correct data' do
        expect(select_by_id('7652182')[field].length).to eq 3
        expect(select_by_id('7652182')[field][0]).to match(
          /^36105130436541 -\|- EARTH-SCI -\|- PERM-RES/
        )
        expect(select_by_id('7652182')[field][1]).to match(
          /^36105130436848 -\|- EARTH-SCI -\|- REFERENCE/
        )
        expect(select_by_id('7652182')[field][2]).to match(
          /^36105130437192 -\|- EARTH-SCI -\|- MEDIA/
        )
      end
    end

    skip 'lopped call numbers' do
      # 	/**
      # 	 * test if item_display field is populated correctly, focused on lopped callnums
      # 	 *  item_display contains:  (separator is " -|- ")
      # 	 *    barcode -|- library(short version) -|- location -|-
      # 	 *     lopped call number (no volume/part info) -|-
      # 	 *     shelfkey (from lopped call num) -|-
      # 	 *     reverse_shelfkey (from lopped call num) -|-
      # 	 *     full callnum -|- callnum sortable for show view
      # 	 */
      #  @Test
      # 	public final void testItemDisplayLoppedCallnums()
      # 			throws ParserConfigurationException, IOException, SAXException
      # 	{
      # 		String fldName = "item_display";
      # 	    String testFilePath = testDataParentPath + File.separator + "buildingTests.mrc";
      #
      # 		// LC
      # 		String id = "460947";
      # 		String callnum = "E184.S75 R47A V.1 1980";
      # 		String lopped = "E184.S75 R47A ...";
      # 		String shelfkey = edu.stanford.CallNumUtils.getShelfKey(lopped, CallNumberType.LC, id).toLowerCase();
      # 		String reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		String volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.LC, isSerial, id);
      # 		String fldVal = "36105007402873 -|- SCIENCE -|- STACKS -|- " + SEP + "STKS-MONO" + SEP +
      # 				lopped + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP + SEP + CallNumberType.LC;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, fldVal);
      #
      # 		id = "575946";
      # 		callnum = "CB3 .A6 SUPPL. V.31";
      # // TODO:  suboptimal - it finds V.31, so it doesn't look for SUPPL. preceding it.
      # 		lopped = "CB3 .A6 SUPPL. ...";
      # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(lopped, CallNumberType.LC, id).toLowerCase();
      # 		reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.LC, !isSerial, id);
      # 		fldVal = "36105035087092 -|- GREEN -|- STACKS -|- CHECKEDOUT" + SEP + "STKS-MONO" + SEP +
      # 				lopped + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP + SEP + CallNumberType.LC;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, fldVal);
      #
      # 		// DEWEY (no vol)
      # 		id = "690002";
      # 		callnum = "159.32 .W211";
      # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(callnum, CallNumberType.DEWEY, id).toLowerCase();
      # 		reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, callnum, shelfkey, CallNumberType.DEWEY, !isSerial, id);
      # 		fldVal = "36105046693508 -|- SAL3 -|- STACKS -|- " + SEP + "STKS-MONO" + SEP +
      # 				callnum + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP + SEP + CallNumberType.DEWEY;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, fldVal);
      #
      # 		// SUDOC (no vol)
      # 		id = "2557826";
      # 		callnum = "E 1.28:COO-4274-1";
      # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(callnum, CallNumberType.SUDOC, id).toLowerCase();
      # 		reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, callnum, shelfkey, CallNumberType.SUDOC, !isSerial, id);
      # 		fldVal = "001AMR5851 -|- GREEN -|- FED-DOCS -|- " + SEP + "GOVSTKS" + SEP +
      # 				callnum + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP + SEP + CallNumberType.SUDOC;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, fldVal);
      #
      #
      # 	    testFilePath = testDataParentPath + File.separator + "itemDisplayTests.mrc";
      #
      # 		// LCPER
      # 		id = "460947";
      # 		callnum = "E184.S75 R47A V.1 1980";
      # 		lopped = "E184.S75 R47A ...";
      # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(lopped, CallNumberType.LC, id).toLowerCase();
      # 		reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.LC, isSerial, id);
      # 		fldVal = "36105007402873 -|- GREEN -|- ON-ORDER -|- " + SEP + "STKS-MONO" + SEP +
      # 				lopped + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP + SEP + CallNumberType.LC;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, fldVal);
      # 		// DEWEYPER (no vol)
      # 		id = "446688";
      # 		callnum = "666.27 .F22";
      # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(callnum, CallNumberType.DEWEY, id).toLowerCase();
      # 		reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, callnum, shelfkey, CallNumberType.DEWEY, !isSerial, id);
      # 		fldVal = "36105007402873 -|- GREEN -|- STACKS -|- " + SEP + "STKS-MONO" + SEP +
      # 				callnum + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP  + SEP + CallNumberType.DEWEY;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, fldVal);
      # 		// ALPHANUM-SUSEL (no vol)
      # 		id = "4578538";
      # 		callnum = "SUSEL-69048";
      # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(callnum, CallNumberType.OTHER, id).toLowerCase();
      # 		reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, callnum, shelfkey, CallNumberType.OTHER, !isSerial, id);
      # 		fldVal = "36105046377987 -|- SAL3 -|- STACKS -|- " + SEP + "STKS-MONO" + SEP +
      # 				callnum + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP + SEP + CallNumberType.ALPHANUM;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, fldVal);
      # 		// ALPHANUM - MFILM ... which is no longer lopped 12-03-09
      # 		id = "1261173";
      # 		callnum = "MFILM N.S. 1350 REEL 230 NO. 3741";
      # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(callnum, CallNumberType.OTHER, id).toLowerCase();
      # 		reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.OTHER, !isSerial, id);
      # 		fldVal = "001AFX2969 -|- GREEN -|- MEDIA-MTXT -|- " + SEP + "NH-MICR" + SEP +
      # 				callnum + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP + SEP + CallNumberType.ALPHANUM;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, fldVal);
      # 		// ALPHANUM - MCD
      # 		id = "1234673";
      # 		callnum = "MCD Brendel Plays Beethoven's Eroica variations";
      # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(callnum, CallNumberType.OTHER, id).toLowerCase();
      # 		reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, callnum, shelfkey, CallNumberType.OTHER, !isSerial, id);
      # 		fldVal = "001AFX2969 -|- GREEN -|- MEDIA-MTXT -|- " + SEP + "NH-MICR" + SEP +
      # 				callnum + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP + SEP + CallNumberType.ALPHANUM;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, fldVal);
      #
      # 		// multiple items with same call number
      # 		id = "3941911";
      # 		callnum = "PS3557 .O5829 K3 1998";
      # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(callnum, CallNumberType.LC, id).toLowerCase();
      # 		reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, callnum, shelfkey, CallNumberType.LC, !isSerial, id);
      # 		fldVal = "36105025373064 -|- GREEN -|- BENDER -|- " + SEP + "NONCIRC" + SEP +
      # 				callnum + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP +  SEP + CallNumberType.LC;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, fldVal);
      # 		fldVal = "36105019748495 -|- GREEN -|- BENDER -|- " + SEP + "STKS-MONO" + SEP +
      # 				callnum + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP +  SEP + CallNumberType.LC;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, fldVal);
      # 		// multiple items with same call number due to vol lopping
      # 		id = "111";
      # 		callnum = "PR3724.T3 A2 V.12";
      # 		lopped = "PR3724.T3 A2 ...";
      # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(lopped, CallNumberType.LC, id).toLowerCase();
      # 		reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.LC, !isSerial, id);
      # 		fldVal = "36105003934432 -|- GREEN -|- STACKS -|- " + SEP + "STKS-MONO" + SEP +
      # 				lopped + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP + SEP + CallNumberType.LC;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, fldVal);
      # 		callnum = "PR3724.T3 A2 V.1";
      # 		volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.LC, !isSerial, id);
      # 		fldVal = "36105003934424 -|- GREEN -|- STACKS -|- " + SEP + "STKS-MONO" + SEP +
      # 				lopped + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP + SEP + CallNumberType.LC;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, fldVal);
      # 		callnum = "PR3724.T3 A2 V.2";
      # 		volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.LC, !isSerial, id);
      # 		fldVal = "36105048104132 -|- GREEN -|- STACKS -|- " + SEP + "STKS-MONO" + SEP +
      # 				lopped + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP + SEP + CallNumberType.LC;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, fldVal);
      #
      # 		// multiple items with same call number due to mult buildings
      # 		id = "222";
      # 		callnum = "PR3724.T3 V2";
      # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(callnum, CallNumberType.LC, id).toLowerCase();
      # 		reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, callnum, shelfkey, CallNumberType.LC, !isSerial, id);
      # 		fldVal = "36105003934432 -|- GREEN -|- STACKS -|- " + SEP + "STKS-MONO" + SEP +
      # 				callnum + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP + SEP + CallNumberType.LC;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, fldVal);
      # 		fldVal = "36105003934424 -|- SAL -|- STACKS -|- " + SEP + "STKS-MONO" + SEP +
      # 				callnum + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP + SEP + CallNumberType.LC;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, fldVal);
      #
      # 		// invalid LC call number
      # 		id = "4823592";
      # 		callnum = "Y 4.G 74/7:G 21/10";
      # 		lopped = CallNumUtils.removeLCVolSuffix(callnum);
      # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(lopped, CallNumberType.OTHER, "4823592").toLowerCase();
      # 		reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.OTHER, !isSerial, id);
      # 		fldVal = "36105063104488 -|- LAW -|- BASEMENT -|- " + SEP + "LAW-STKS" + SEP +
      # 				lopped + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP + SEP + CallNumberType.OTHER;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, fldVal);
      # 	}
      #
    end

    skip 'forward sort key (shelfkey)' do
      # 	/**
      # 	 * test if item_display field is populated correctly, focused on forward sorting callnums
      # 	 *  item_display contains:  (separator is " -|- ")
      # 	 *    barcode -|- library(short version) -|- location -|-
      # 	 *     lopped call number (no volume/part info) -|-
      # 	 *     shelfkey (from lopped call num) -|-
      # 	 *     reverse_shelfkey (from lopped call num) -|-
      # 	 *     full callnum -|- callnum sortable for show view
      # 	 */
      # @Test
      # 	public final void testItemDisplayShelfkey()
      # 			throws ParserConfigurationException, IOException, SAXException
      # 	{
      # 		String fldName = "item_display";
      # 	    String testFilePath = testDataParentPath + File.separator + "buildingTests.mrc";
      #
      # 		// are we getting the shelfkey for the lopped call number?
      # 		String id = "460947";
      # 		String callnum = "E184.S75 R47A V.1 1980";
      # 		String lopped = "E184.S75 R47A ...";
      # 		String shelfkey = edu.stanford.CallNumUtils.getShelfKey(lopped, CallNumberType.LC, id).toLowerCase();
      # 		String reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		String volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.LC, isSerial, id);
      # 		String fldVal = "36105007402873 -|- SCIENCE -|- STACKS -|- " + SEP + "STKS-MONO" + SEP +
      # 				lopped + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP + SEP + CallNumberType.LC;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, fldVal);
    end

    describe 'public note' do
      context 'when the public note is upper case ".PUBLIC."' do
        let(:record) do
          MARC::Record.new.tap do |record|
            record.append(
              MARC::DataField.new(
                '999', ' ', ' ',
                MARC::Subfield.new('a', 'AB123.45 .M67'),
                MARC::Subfield.new('o', '.PUBLIC. Note')
              )
            )
          end
        end

        it 'is included' do
          expect(result[field].length).to eq 1
          expect(result[field].first).to include('-|- .PUBLIC. Note -|-')
        end
      end

      context 'when the public note is lower case ".public."' do
        let(:record) do
          MARC::Record.new.tap do |record|
            record.append(
              MARC::DataField.new(
                '999', ' ', ' ',
                MARC::Subfield.new('a', 'AB123.45 .M67'),
                MARC::Subfield.new('o', '.public. Note')
              )
            )
          end
        end

        it 'is included' do
          expect(result[field].length).to eq 1
          expect(result[field].first).to include('-|- .public. Note -|-')
        end
      end

      context 'when the public note is mixed case' do
        let(:record) do
          MARC::Record.new.tap do |record|
            record.append(
              MARC::DataField.new(
                '999', ' ', ' ',
                MARC::Subfield.new('a', 'AB123.45 .M67'),
                MARC::Subfield.new('o', '.PuBlIc. Note')
              )
            )
          end
        end

        it 'is included' do
          expect(result[field].length).to eq 1
          expect(result[field].first).to include('-|- .PuBlIc. Note -|-')
        end
      end

      context 'when the public note does not have periods around it' do
        let(:record) do
          MARC::Record.new.tap do |record|
            record.append(
              MARC::DataField.new(
                '999', ' ', ' ',
                MARC::Subfield.new('a', 'AB123.45 .M67'),
                MARC::Subfield.new('o', 'public Note')
              )
            )
          end
        end

        it 'is not included' do
          expect(result[field].length).to eq 1
          expect(result[field].first).not_to include('public Note')
        end
      end

      context 'when the note does not begin with ".PUBLIC."' do
        let(:record) do
          MARC::Record.new.tap do |record|
            record.append(
              MARC::DataField.new(
                '999', ' ', ' ',
                MARC::Subfield.new('a', 'AB123.45 .M67'),
                MARC::Subfield.new('o', 'Note .PUBLIC.')
              )
            )
          end
        end

        it 'is not included' do
          expect(result[field].length).to eq 1
          expect(result[field].first).not_to include('Note .PUBLIC.')
        end
      end

      context 'when the note does not have the word ".PUBLIC."' do
        let(:record) do
          MARC::Record.new.tap do |record|
            record.append(
              MARC::DataField.new(
                '999', ' ', ' ',
                MARC::Subfield.new('a', 'AB123.45 .M67'),
                MARC::Subfield.new('o', 'Note ')
              )
            )
          end
        end

        it 'is not included' do
          expect(result[field].length).to eq 1
          expect(result[field].first).not_to include('Note ')
        end
      end
    end

    skip 'reverse shelfkeys' do
      # /**
      # 	 * test if item_display field is populated correctly, focused on backward sorting callnums
      # 	 *  item_display contains:  (separator is " -|- ")
      # 	 *    barcode -|- library(short version) -|- location -|-
      # 	 *     lopped call number (no volume/part info) -|-
      # 	 *     shelfkey (from lopped call num) -|-
      # 	 *     reverse_shelfkey (from lopped call num) -|-
      # 	 *     full callnum -|- callnum sortable for show view
      # 	 */
      # @Test
      # 	public final void testItemDisplayReverseShelfkey()
      # 			throws ParserConfigurationException, IOException, SAXException
      # 	{
      # 		String fldName = "item_display";
      # 	    String testFilePath = testDataParentPath + File.separator + "buildingTests.mrc";
      #
      # 		// are we getting the reverse shelfkey for the lopped call number?
      # 		String id = "460947";
      # 		String callnum = "E184.S75 R47A V.1 1980";
      # 		String lopped = "E184.S75 R47A ...";
      # 		String shelfkey = edu.stanford.CallNumUtils.getShelfKey(lopped, CallNumberType.LC, id).toLowerCase();
      # 		String reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		String volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.LC, isSerial, id);
      # 		String fldVal = "36105007402873 -|- SCIENCE -|- STACKS -|- " + SEP + "STKS-MONO" + SEP +
      # 				lopped + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort  + SEP + SEP + CallNumberType.LC;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, fldVal);
      # 	}
    end

    describe 'full call numbers' do
      let(:fixture_name) { 'buildingTests.mrc' }

      it 'are populated' do
        expect(select_by_id('460947')[field].length).to eq 2
        expect(select_by_id('460947')[field].first).to include('-|- E184.S75 R47A V.1 1980 -|-')
        expect(select_by_id('460947')[field].last).to include('-|- E184.S75 R47A V.2 1980 -|-')
      end
    end

    describe 'call number type' do
      context 'ALPHANUM' do
        let(:record) do
          MARC::Record.new.tap do |record|
            record.append(
              MARC::DataField.new(
                '999', ' ', ' ',
                MARC::Subfield.new('a', 'YUGOSLAV SERIAL 1973'),
                MARC::Subfield.new('w', 'ALPHANUM')
              )
            )
          end
        end

        it 'includes the correct data' do
          expect(result[field].first).to end_with('-|- ALPHANUM')
        end
      end

      context 'DEWEY' do
        let(:record) do
          MARC::Record.new.tap do |record|
            record.append(
              MARC::DataField.new(
                '999', ' ', ' ',
                MARC::Subfield.new('a', '370.1 .S655'),
                MARC::Subfield.new('w', 'DEWEY')
              )
            )
          end
        end

        it 'includes the correct data' do
          expect(result[field].first).to end_with('-|- DEWEY')
        end
      end

      context 'LC' do
        let(:record) do
          MARC::Record.new.tap do |record|
            record.append(
              MARC::DataField.new(
                '999', ' ', ' ',
                MARC::Subfield.new('a', 'E184.S75 R47A V.1 1980'),
                MARC::Subfield.new('w', 'LC')
              )
            )
          end
        end

        it 'includes the correct data' do
          expect(result[field].first).to end_with('-|- LC')
        end
      end

      context 'SUDOC' do
        let(:record) do
          MARC::Record.new.tap do |record|
            record.append(
              MARC::DataField.new(
                '999', ' ', ' ',
                MARC::Subfield.new('a', 'E 1.28:COO-4274-1'),
                MARC::Subfield.new('w', 'SUDOC')
              )
            )
          end
        end

        it 'includes the correct data' do
          expect(result[field].first).to end_with('-|- SUDOC')
        end
      end

      context 'OTHER' do
        let(:record) do
          MARC::Record.new.tap do |record|
            record.append(
              MARC::DataField.new(
                '999', ' ', ' ',
                MARC::Subfield.new('a', '71 15446'),
                MARC::Subfield.new('w', 'THESIS')
              )
            )
          end
        end

        it 'includes the correct data' do
          expect(result[field].first).to end_with('-|- OTHER')
        end
      end

      context 'XX' do
        let(:record) do
          MARC::Record.new.tap do |record|
            record.append(
              MARC::DataField.new(
                '999', ' ', ' ',
                MARC::Subfield.new('a', 'XX(3195846.2579)'),
                MARC::Subfield.new('w', 'XX')
              )
            )
          end
        end

        it 'includes the correct data' do
          expect(result[field].first).to end_with('-|- OTHER')
        end
      end

      context 'Hoover Archives with call numbers starting with XX' do
        let(:record) do
          MARC::Record.new.tap do |record|
            record.append(
              MARC::DataField.new(
                '999', ' ', ' ',
                MARC::Subfield.new('a', 'XX066 BOX 11'),
                MARC::Subfield.new('m', 'HV-ARCHIVE'),
                MARC::Subfield.new('w', 'ALPHANUM')
              )
            )
          end
        end

        it 'includes the correct data' do
          expect(result[field].first).to end_with('-|- ALPHANUM')
        end
      end

      context 'ASIS' do
        let(:record) do
          MARC::Record.new.tap do |record|
            record.append(
              MARC::DataField.new(
                '999', ' ', ' ',
                MARC::Subfield.new('a', 'INTERNET RESOURCE'),
                MARC::Subfield.new('w', 'ASIS')
              )
            )
          end
        end

        it 'includes the correct data' do
          expect(result[field].first).to end_with('-|- OTHER')
        end
      end

      context 'yet another OTHER' do
        let(:record) do
          MARC::Record.new.tap do |record|
            record.append(
              MARC::DataField.new(
                '999', ' ', ' ',
                MARC::Subfield.new('a', 'X X'),
                MARC::Subfield.new('w', 'OTHER')
              )
            )
          end
        end

        it 'includes the correct data' do
          expect(result[field].first).to end_with('-|- OTHER')
        end
      end
    end

    skip 'volsort/full shelfkey' do
      # 	/**
      # 	 * test if item_display field is populated correctly, focused on sorting call numbers for show view
      # 	 *  item_display contains:  (separator is " -|- ")
      # 	 *    barcode -|- library(short version) -|- location -|-
      # 	 *     lopped call number (no volume/part info) -|-
      # 	 *     shelfkey (from lopped call num) -|-
      # 	 *     reverse_shelfkey (from lopped call num) -|-
      # 	 *     full callnum -|- callnum sortable for show view
      # 	 */
      # @Test
      # 	public final void testItemDisplayCallnumVolumeSort()
      # 			throws ParserConfigurationException, IOException, SAXException
      # 	{
      # 		String fldName = "item_display";
      # 	    String testFilePath = testDataParentPath + File.separator + "buildingTests.mrc";
      #
      # 		// are we getting the volume sortable call number we expect?
      # 		String id = "460947";
      # 		String callnum = "E184.S75 R47A V.1 1980";
      # 		String lopped = CallNumUtils.removeLCVolSuffix(callnum) + " ...";
      # 		String shelfkey = edu.stanford.CallNumUtils.getShelfKey(lopped, CallNumberType.LC, id).toLowerCase();
      # 		String reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		String volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.LC, isSerial, id);
      # 		String fldVal = "36105007402873 -|- SCIENCE -|- STACKS -|- " + SEP + "STKS-MONO" + SEP +
      # 				lopped + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP + SEP + CallNumberType.LC;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, fldName, fldVal);
      # 	}
      #
    end

    skip 'shefkey field data is the same as the field in the item_display' do
      # 	/**
      # 	 * test if shelfkey field data (for searching) matches shelfkey in
      # 	 * item_display field
      # 	 */
      # @Test
      # 	public void testShelfkeyMatchesItemDisp()
      # 			throws ParserConfigurationException, IOException, SAXException
      # 	{
      # 	    String testFilePath = testDataParentPath + File.separator + "shelfkeyMatchItemDispTests.mrc";
      #
      # 		// shelfkey should be same in item_display and in shelfkey fields
      # 	    String id = "5788269";
      # 	    String callnum = "CALIF A125 .A34 2002";
      # 	    String lopped = CallNumUtils.getLoppedCallnum(callnum, CallNumberType.OTHER, isSerial) + " ...";
      # 	    String shelfkey = edu.stanford.CallNumUtils.getShelfKey(lopped, CallNumberType.OTHER, id).toLowerCase();
      # 	    String reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 	    String volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.LC, isSerial, id);
      # 	    String fldVal = "36105122888543 -|- GREEN -|- CALIF-DOCS" + SEP + SEP + "GOVSTKS" + SEP +
      # 				lopped + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP + SEP + CallNumberType.ALPHANUM;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, "item_display", fldVal);
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, "shelfkey", shelfkey);
      #
      # 	    id = "409752";
      # 		callnum = "CALIF A125 .B9 V.17 1977:NO.3";
      # 		lopped = CallNumUtils.getLoppedCallnum(callnum, CallNumberType.OTHER, isSerial) + " ...";
      # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(lopped, CallNumberType.OTHER, id).toLowerCase();
      # 		reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.LC, isSerial, id);
      # 		fldVal = "36105127370745 -|- GREEN -|- CALIF-DOCS" + SEP + SEP + "GOVSTKS" + SEP +
      # 				lopped + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP + SEP + CallNumberType.ALPHANUM;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, "item_display", fldVal);
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, "shelfkey", shelfkey);
      # 		callnum = "CALIF A125 .B9 V.7-15 1966-1977:NO.1";
      # 		lopped = CallNumUtils.getLoppedCallnum(callnum, CallNumberType.OTHER, isSerial) + " ...";
      # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(lopped, CallNumberType.OTHER, id).toLowerCase();
      # 		reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.LC, isSerial, id);
      # 		fldVal = "36105127370737 -|- GREEN -|- CALIF-DOCS -|- " + SEP + "GOVSTKS" + SEP +
      # 				lopped + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP + SEP + CallNumberType.ALPHANUM;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, "item_display", fldVal);
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, "shelfkey", shelfkey);
      #
      # 	    id = "373245";
      # 		callnum = "553.2805 .P187 V.1-2 1916-1918";
      # 		lopped = CallNumUtils.getLoppedCallnum(callnum, CallNumberType.DEWEY, isSerial) + " ...";
      # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(lopped, CallNumberType.DEWEY, id).toLowerCase();
      # 		reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.LC, isSerial, id);
      # 		fldVal = "36105027549075 -|- SAL3 -|- STACKS -|- " + SEP + "STKS-PERI" + SEP +
      # 				lopped + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP + SEP + CallNumberType.DEWEY;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, "item_display", fldVal);
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, "shelfkey", shelfkey);
      #
      # 	    id = "373759";
      # 		callnum = "553.2805 .P494 V.11 1924:JAN.-JUNE";
      # 		lopped = CallNumUtils.getLoppedCallnum(callnum, CallNumberType.DEWEY, isSerial) + " ...";
      # 		shelfkey = edu.stanford.CallNumUtils.getShelfKey(lopped, CallNumberType.DEWEY, id).toLowerCase();
      # 		reversekey = org.solrmarc.tools.CallNumUtils.getReverseShelfKey(shelfkey).toLowerCase();
      # 		volSort = edu.stanford.CallNumUtils.getVolumeSortCallnum(callnum, lopped, shelfkey, CallNumberType.LC, isSerial, id);
      # 		fldVal = "36105027313985 -|- SAL3 -|- STACKS -|- " + SEP + "STKS-PERI" + SEP +
      # 				lopped + SEP + shelfkey + SEP + reversekey + SEP + callnum + SEP + volSort + SEP + SEP + CallNumberType.DEWEY;
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, "item_display", fldVal);
      # 	    solrFldMapTest.assertSolrFldValue(testFilePath, id, "shelfkey", shelfkey);
      # 	}
      #
    end

    context 'when a record has multiple copies' do
      let(:fixture_name) { 'multipleCopies.mrc' }

      it 'results in multiple fields' do
        expect(select_by_id('1')[field].length).to eq 2
        expect(select_by_id('1')[field].first).to start_with('36105003934432 -|-')
        expect(select_by_id('1')[field].last).to start_with('36105003934424 -|-')
      end
    end
  end
end
