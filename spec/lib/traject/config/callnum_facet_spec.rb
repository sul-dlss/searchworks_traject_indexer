require 'sirsi_holding'

def record_with_999(call_number:, scheme:, home_location: 'STACKS', library: 'GREEN', indexer:)
  indexer.map_record(
    MARC::Record.new.tap do |r|
      r.append(
        MARC::DataField.new(
          '999',
          ' ',
          ' ',
          MARC::Subfield.new('a', call_number),
          MARC::Subfield.new('l', home_location),
          MARC::Subfield.new('m', library),
          MARC::Subfield.new('w', scheme)
        )
      )
      yield r if block_given?
    end
  )
end

RSpec.describe 'Call Number Facet' do
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end

  let(:field) { 'callnum_facet_hsim' }
  let(:record) { record_with_999(call_number: call_number, scheme: scheme) }

  context 'call numbers excluded for various reasons' do
    it 'handles unexpected callnum type (by not including them)' do
      expect(record_with_999(call_number: 'M123 .M234', scheme: 'ALPHANUM', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: 'M123 .M234', scheme: 'HARVYENCH', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: 'M123 .M234', scheme: 'OTHER', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: 'M123 .M234', scheme: 'THESIS', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: 'M123 .M234', scheme: 'XX', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: 'M123 .M234', scheme: 'ASIS', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: 'M123 .M234', scheme: 'AUTO', indexer: indexer)[field]).to be_nil
    end

    it 'handles weird LC callnum from Lane-Med (by not including them)' do
      # invalid LC from Lane
      expect(record_with_999(call_number: 'notLC', scheme: 'LC', library: 'LANE-MED', indexer: indexer)[field]).to be_nil

      # valid LC from Lane
      expect(record_with_999(call_number: 'M123 .M456', scheme: 'LC', indexer: indexer)[field]).to eq(
        ['LC Classification|M - Music|M - Music']
      )

      #  invalid LC not from Lane
      expect(record_with_999(call_number: 'notLC', scheme: 'LC', indexer: indexer)[field]).to be_nil
    end

    it 'assigns value for valid LC even if it is a shelve by location' do
      SirsiHolding::SHELBY_LOCS.each do |loc|
        # valid LC
        # FIXME: we DO want a value if there is valid LC for shelby location
        # expect(record_with_999(call_number: 'M123 .M456', scheme: 'LC', home_location: loc, indexer: indexer)[field]).to eq(
        #   ['LC Classification|M - Music|M - Music']
        # )

        # invalid LC
        expect(record_with_999(call_number: 'not valid!', scheme: 'LC', home_location: loc, indexer: indexer)[field]).to be_nil
        # invalid Dewey
        expect(record_with_999(call_number: 'not valid!', scheme: 'DEWEY', home_location: loc, indexer: indexer)[field]).to be_nil
        # Hopkins weird Shelby
        expect(record_with_999(call_number: ' 1976', scheme: 'LCPER', home_location: loc, indexer: indexer)[field]).to be_nil
        expect(record_with_999(call_number: '1976', scheme: 'LCPER', home_location: loc, indexer: indexer)[field]).to be_nil
      end
    end

    it 'handles missing or lost call numbers (by not including them)' do
      SirsiHolding::LOST_OR_MISSING_LOCS.each do |loc|
        # valid LC
        expect(record_with_999(call_number: 'M123 .M456', home_location: loc, scheme: 'LC', indexer: indexer)[field]).to be_nil
        # invalid LC
        expect(record_with_999(call_number: 'not valid!', home_location: loc, scheme: 'LC', indexer: indexer)[field]).to be_nil
        # valid Dewey
        expect(record_with_999(call_number: '123.4 .B45', home_location: loc, scheme: 'DEWEY', indexer: indexer)[field]).to be_nil
        # invalid Dewey
        expect(record_with_999(call_number: 'not valid!', home_location: loc, scheme: 'DEWEY', indexer: indexer)[field]).to be_nil
      end
    end

    it 'handles ignored call numbers (by not including them)' do
      # LC
      expect(record_with_999(call_number: 'INTERNET RESOURCE stuff', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: 'XX stuff', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: 'NO CALL NUMBER', scheme: 'LC', indexer: indexer)[field]).to be_nil

      # Dewey
      expect(record_with_999(call_number: 'INTERNET RESOURCE stuff', scheme: 'DEWEY', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: 'XX stuff', scheme: 'DEWEY', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: 'NO CALL NUMBER', scheme: 'DEWEY', indexer: indexer)[field]).to be_nil
    end

    it 'handles empty call numbers (by not returning them)' do
      # LC
      expect(record_with_999(call_number: nil, scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: ' ', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '. . ', scheme: 'LC', indexer: indexer)[field]).to be_nil

      # Dewey
      expect(record_with_999(call_number: nil, scheme: 'DEWEY', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '', scheme: 'DEWEY', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: ' ', scheme: 'DEWEY', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '. . ', scheme: 'DEWEY', indexer: indexer)[field]).to be_nil
    end

    it 'does not return call nubmers typed as Alphanum, and clearly not LC or Dewey' do
      expect(record_with_999(call_number: '71 15446 V.1', scheme: 'ALPHANUM', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '4488.301 0300 2001 CD-ROM', scheme: 'ALPHANUM', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '8291.209 .A963 V.5 1971/1972', scheme: 'ALPHANUM', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '"NEW BEGINNING" INVESTMENT RESERVE FUND', scheme: 'ALPHANUM', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '"21" BRANDS, INCORPORATED', scheme: 'ALPHANUM', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: ' "LA CONSOLIDADA", S.A', scheme: 'ALPHANUM', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '(THE) NWNL COMPANIES, INC.', scheme: 'ALPHANUM', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: 'ISHII SPRING 2009', scheme: 'ALPHANUM', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: 'OYER WINTER 2012', scheme: 'ALPHANUM', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: "O'REILLY FALL 2006", scheme: 'ALPHANUM', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: 'XV 852', scheme: 'ALPHANUM', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: 'YUGOSLAV SERIAL 1963 NO.5-6', scheme: 'ALPHANUM', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: 'SUSEL-69048', scheme: 'ALPHANUM', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: 'MFICHE 3239', scheme: 'ALPHANUM', indexer: indexer)[field]).to be_nil
    end

    it 'does not return call numbers w/ the scheme ASIS' do
      expect(record_with_999(call_number: '(ADL4044.1)XX', scheme: 'ASIS', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '134776', scheme: 'ASIS', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: 'INTERNET RESOURCE', scheme: 'ASIS', indexer: indexer)[field]).to be_nil
    end
  end

  context 'LC Call Numbers' do
  #
  # 	/**
  # 	 * when all items are online and/or all items have ignored callnums,
  # 	 *  then we look for an LC call number first in 050, then in 090 and
  # 	 *  if we find a good one, we use it for facet and browsing
  # 	 */
  # @Test
  # 	public void hasSeparateBrowseCallnum()
  # 	{
  # 		// 1 item online, type LC:  no 050 or 090
  # 		Record record = getRecordWith999("INTERNET RESOURCE", CallNumberType.LC);
  # 		solrFldMapTest.assertNoSolrFld(record, fldName);
  # 		// add 090 - get value from 090
  # 		DataField df090 = factory.newDataField("090", ' ', ' ');
  # 		df090.addSubfield(factory.newSubfield('a', "QM142"));
  # 		df090.addSubfield(factory.newSubfield('b', ".A84 2010"));
  # 		record.addVariableField(df090);
  # 		solrFldMapTest.assertSolrFldValue(record, fldName, "LC Classification|Q - Science|QM - Human Anatomy");
  # 		// add 050 - get value from 050 instead of 090
  # 		DataField df050 = factory.newDataField("050", '1', '4');
  # 		df050.addSubfield(factory.newSubfield('a', "QA76.76.C672"));
  # 		record.addVariableField(df050);
  # 		solrFldMapTest.assertSolrFldValue(record, fldName, "LC Classification|Q - Science|QA - Mathematics");
  # 		solrFldMapTest.assertSolrFldHasNumValues(record, fldName, 1);
  #
  # 		// 1 item ignored callnum, type ASIS:  no 050 or 090
  # 		record = getRecordWith999(StanfordIndexer.SKIPPED_CALLNUMS.toArray()[0].toString(), "ASIS");
  # 		solrFldMapTest.assertNoSolrFld(record, fldName);
  # 		// add 090 - get value from 090
  # 		df090 = factory.newDataField("090", ' ', ' ');
  # 		df090.addSubfield(factory.newSubfield('a', "QM142"));
  # 		df090.addSubfield(factory.newSubfield('b', ".A84 2010"));
  # 		record.addVariableField(df090);
  # 		solrFldMapTest.assertSolrFldValue(record, fldName, "LC Classification|Q - Science|QM - Human Anatomy");
  # 		// add 050 - get value from 050 instead of 090
  # 		df050 = factory.newDataField("050", '1', '4');
  # 		df050.addSubfield(factory.newSubfield('a', "QA76.76.C672"));
  # 		record.addVariableField(df050);
  # 		solrFldMapTest.assertSolrFldValue(record, fldName, "LC Classification|Q - Science|QA - Mathematics");
  # 		solrFldMapTest.assertSolrFldHasNumValues(record, fldName, 1);
  # 	}
  #

    it 'handles single letter LC call numbers' do
      expect(record_with_999(call_number: 'D764.7 .K72 1990', scheme: 'LC', indexer: indexer)[field]).to eq(
        ['LC Classification|D - World History|D - World History']
      )

      expect(record_with_999(call_number: 'F1356 .M464 2005', scheme: 'LC', indexer: indexer)[field]).to eq(
        ['LC Classification|F - History of the Americas (Local)|F - History of the Americas (Local)']
      )

      expect(record_with_999(call_number: ' M2 .C17 L3 2005', scheme: 'LC', indexer: indexer)[field]).to eq(
        ['LC Classification|M - Music|M - Music']
      )

      expect(record_with_999(call_number: 'U897 .C87 Z55 2001', scheme: 'LC', indexer: indexer)[field]).to eq(
        ['LC Classification|U - Military Science|U - Military Science']
      )

      expect(record_with_999(call_number: 'Z3871.Z8', scheme: 'LC', indexer: indexer)[field]).to eq(
        ['LC Classification|Z - Bibliography, Library Science, Information Resources|Z - Bibliography, Library Science, Information Resources']
      )
    end

    it 'handles two letter LC call numbers' do
      expect(record_with_999(call_number: 'QE538.8 .N36 1975-1977', scheme: 'LC', indexer: indexer)[field]).to eq(
        ['LC Classification|Q - Science|QE - Geology']
      )

      expect(record_with_999(call_number: 'BX4659 .E85 W44', scheme: 'LC', indexer: indexer)[field]).to eq(
        ['LC Classification|B - Philosophy, Psychology, Religion|BX - Christian Denominations']
      )

      expect(record_with_999(call_number: 'HG6046 .V28 1986', scheme: 'LC', indexer: indexer)[field]).to eq(
        ['LC Classification|H - Social Sciences|HG - Finance']
      )
    end

    it 'handles three letter LC call numbers' do
      # 6830340
      expect(record_with_999(call_number: 'KKX500 .S98 2005', scheme: 'LC', indexer: indexer)[field]).to eq(
        ['LC Classification|K - Law|KKX - Law of Turkey']
      )

      expect(record_with_999(call_number: 'KJV4189 .A67 A15 2014', scheme: 'LC', indexer: indexer)[field]).to eq(
        ['LC Classification|K - Law|KJV - Law of France']
      )
    end

    it 'includes the classification when it is not available in the map' do
      expect(record_with_999(call_number: 'KFC1050 .C35 2014', scheme: 'LC', indexer: indexer)[field]).to eq(
        ['LC Classification|K - Law|KFC']
      )
    end

    it 'handles multiple 999s with the same LC class appropriately' do
      doc = record_with_999(call_number: 'ML171 .L38 2005', scheme: 'LC', indexer: indexer) do |marc_record|
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

      expect(doc[field].sort).to eq(
        [
          'LC Classification|M - Music|M - Music',
          'LC Classification|M - Music|ML - Literature on Music'
        ]
      )
    end

    it 'handles multiple 999s with different LC classes appropriately' do
      doc = record_with_999(call_number: 'ML171 .L38 2005', scheme: 'LC', indexer: indexer) do |marc_record|
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

      expect(doc[field]).to eq(
        [
          'LC Classification|M - Music|ML - Literature on Music',
          'LC Classification|Q - Science|QE - Geology'
        ]
      )
    end


    it 'handles lane LC call numbers' do
      expect(record_with_999(call_number: 'Q603 .H47 1960', library: 'LANE-MED', scheme: 'LC', indexer: indexer)[field]).to eq(
        ['LC Classification|Q - Science|Q - Science']
      )
    end

    it 'handles LC call numbers that have a scheme listed something else' do
      skip 'This test was marked as TODO in SolrMarc'

      expect(record_with_999(call_number: 'QE538.8 .N36 1975-1977', scheme: 'DEWEY', indexer: indexer)[field]).to eq(
        ['LC Classification|Q - Science|QE - Geology']
      )

      expect(record_with_999(call_number: 'QE538.8 .N36 1975-1977', scheme: 'ALPHANUM', indexer: indexer)[field]).to eq(
        ['LC Classification|Q - Science|QE - Geology']
      )

      expect(record_with_999(call_number: 'QE538.8 .N36 1975-1977', scheme: 'OTHER', indexer: indexer)[field]).to eq(
        ['LC Classification|Q - Science|QE - Geology']
      )
    end
  end

  context 'invalid LC call numbers' do
    it 'are not included' do
      # bad Cutter
      expect(record_with_999(call_number: 'QE538.8 .NB36 1975-1977', scheme: 'DEWEY', indexer: indexer)[field]).to be_nil

      # paren start char
      expect(record_with_999(call_number: '(V) JN6695 .I28 1999 COPY', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '???', scheme: 'LC', indexer: indexer)[field]).to be_nil

      # weird callnums
      expect(record_with_999(call_number: '158613F868 .C45 N37 2000', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '5115126059 A17 2004', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '70 03126', scheme: 'LC', indexer: indexer)[field]).to be_nil
    end

    it 'handles LC call numbers starting with illegal letters correctly (by not including them)' do
      expect(record_with_999(call_number: 'INTERNET RESOURCE KF3400 .S36 2009', scheme: 'LC', indexer: indexer)[field]).to be_nil
      # FIXME: we DO want a value for INTERNET or NO CALLNUM, either from the bib, or if there is a valid callnum after INTERNET RESOURCE");
      # expect(record_with_999(call_number: 'INTERNET RESOURCE KF3400 .S36 2009', scheme: 'LC', indexer: indexer)[field]).to eq(
      #   ['LC Classification|K - Law|KF - Law of the U.S.']
      # )

      expect(record_with_999(call_number: 'INTERNET RESOURCE GALE EZPROXY', scheme: 'LC', indexer: indexer)[field]).to be_nil
      # should be govdoc
      expect(record_with_999(call_number: 'ICAO DOC 4444/15TH ED', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: 'ORNL-6371', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: 'X X', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: 'XM98-1 NO.1', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: 'XX(6661112.1)', scheme: 'LC', indexer: indexer)[field]).to be_nil

      expect(record_with_999(call_number: 'YBP1834690', scheme: 'LC', indexer: indexer)[field]).to be_nil
    end

    it 'handles call numbers that are alphanum, but have scheme listed as LC (by not including them)' do
      expect(record_with_999(call_number: '1ST AMERICAN BANCORP, INC.', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '2 B SYSTEM INC.', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '202 DATA SYSTEMS, INC.', scheme: 'LC', indexer: indexer)[field]).to be_nil
    end

    it 'handles unusual Lane (med school) call numbers (by not including them)' do
      expect(record_with_999(call_number: '1.1', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '20.44', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '4.15[C]', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '6.4C-CZ[BC]', scheme: 'LC', indexer: indexer)[field]).to be_nil
    end

    it 'handles Harvard Yenching call numbers (by not including them)' do
      expect(record_with_999(call_number: '6.4C-CZ[BC]', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '2345 5861 V.3', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '2061 4246 NO.5-6 1936-1937', scheme: 'ALPHANUM', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '4362 .S12P2 1965 .C3', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '4861.1 3700 1989:NO.4-6', scheme: 'ALPHANUM', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '4488.301 0300 2005 CD-ROM', scheme: 'LCPER', indexer: indexer)[field]).to be_nil
    end

    it 'handles weird in process call numbers (by not including them)' do
      expect(record_with_999(call_number: '001AQJ5818', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '(XX.4300523)', scheme: 'AUTO', indexer: indexer)[field]).to be_nil
      # EDI in process
      expect(record_with_999(call_number: '427331959', scheme: 'LC', indexer: indexer)[field]).to be_nil
      # Japanese
      expect(record_with_999(call_number: '7926635', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '7890569-1001', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '7885324-1001-2', scheme: 'LC', indexer: indexer)[field]).to be_nil
      # Rare
      expect(record_with_999(call_number: '741.5 F', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '(ADL4044.1)XX', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '(XX.4300523)', scheme: 'LC', indexer: indexer)[field]).to be_nil
      # math-cs tech-reports  (home Loc TECH-RPTS)
      expect(record_with_999(call_number: '134776', scheme: 'LC', indexer: indexer)[field]).to be_nil
      expect(record_with_999(call_number: '262198', scheme: 'LC', indexer: indexer)[field]).to be_nil
    end
  end

  context 'dewey call numbers' do
    it 'has the correct data' do
      expect(record_with_999(call_number: '159.32 .W211', scheme: 'DEWEY', indexer: indexer)[field]).to eq(
        ['Dewey Classification|100s - Philosophy & Psychology|150s - Psychology']
      )

      expect(record_with_999(call_number: '550.6 .U58P NO.1707', scheme: 'DEWEY', indexer: indexer)[field]).to eq(
        ['Dewey Classification|500s - Science|550s - Earth Sciences']
      )
    end

    it 'has the correct data for dewey call numbers w/o leading zeros' do
      expect(record_with_999(call_number: '062 .B862 V.193', scheme: 'DEWEY', indexer: indexer)[field]).to eq(
        ['Dewey Classification|000s - Computer Science, Information & General Works|060s - General Organization & Museology']
      )

      expect(record_with_999(call_number: '62 .B862 V.193', scheme: 'DEWEY', indexer: indexer)[field]).to eq(
        ['Dewey Classification|000s - Computer Science, Information & General Works|060s - General Organization & Museology']
      )

      expect(record_with_999(call_number: '002 U73', scheme: 'DEWEY', indexer: indexer)[field]).to eq(
        ['Dewey Classification|000s - Computer Science, Information & General Works|000s - Computer Science, Information & General Works']
      )

      expect(record_with_999(call_number: '2 U73', scheme: 'DEWEY', indexer: indexer)[field]).to eq(
        ['Dewey Classification|000s - Computer Science, Information & General Works|000s - Computer Science, Information & General Works']
      )
    end

    it 'only includes one call number if there are duplicates' do
      doc = record_with_999(call_number: '370.6 .N28 V.113:PT.1', scheme: 'DEWEY', indexer: indexer)

      expect(doc[field]).to eq(
        ['Dewey Classification|300s - Social Sciences|370s - Education']
      )

      doc = record_with_999(call_number: '370.6 .N28 V.113:PT.1', scheme: 'DEWEY', indexer: indexer) do |marc_record|
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
        ['Dewey Classification|300s - Social Sciences|370s - Education']
      )
    end

    it 'includes multiple call numbers from the same record' do
      doc = record_with_999(call_number: '518 .M161', scheme: 'DEWEY', indexer: indexer)

      expect(doc[field]).to eq(
        ['Dewey Classification|500s - Science|510s - Mathematics']
      )

      doc = record_with_999(call_number: '518 .M161', scheme: 'DEWEY', indexer: indexer) do |marc_record|
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
          'Dewey Classification|500s - Science|510s - Mathematics',
          'Dewey Classification|000s - Computer Science, Information & General Works|060s - General Organization & Museology'
        ]
      )
    end

    it 'includes both dewey and LC call numbers when present' do
      doc = record_with_999(call_number: 'PR5190 .P3 Z48 2011', scheme: 'LC', indexer: indexer) do |marc_record|
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
          'LC Classification|P - Language & Literature|PR - English Literature',
          'Dewey Classification|900s - History & Geography|960s - General History of Africa'
        ]
      )

      doc = record_with_999(call_number: 'QE539.2 .P34 O77 2005', scheme: 'LC', indexer: indexer) do |marc_record|
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
          'LC Classification|Q - Science|QE - Geology',
          'Dewey Classification|500s - Science|550s - Earth Sciences'
        ]
      )
    end

    it 'inlcudes items typed as DEWEYPER' do
      expect(record_with_999(call_number: '550.6 .U58O 92-600', scheme: 'DEWEYPER', indexer: indexer)[field]).to eq(
        ['Dewey Classification|500s - Science|550s - Earth Sciences']
      )
    end

    it 'handles call numbers that dewey but listed as LC' do
      expect(record_with_999(call_number: '180.8 D25 V.1', scheme: 'LC', indexer: indexer)[field]).to eq(
        ['Dewey Classification|100s - Philosophy & Psychology|180s - Ancient, Medieval, Oriental Philosophy']
      )

      expect(record_with_999(call_number: '219.7 K193L V.5', scheme: 'LC', indexer: indexer)[field]).to eq(
        ['Dewey Classification|200s - Religion|210s - Natural Theology']
      )

      expect(record_with_999(call_number: '3.37 D621', scheme: 'LC', indexer: indexer)[field]).to eq(
        ['Dewey Classification|000s - Computer Science, Information & General Works|000s - Computer Science, Information & General Works']
      )
    end
  end

  context 'invalid DEWEY call numbers' do
    it 'are not included' do
      expect(record_with_999(call_number: '180.8 DX25 V.1', scheme: 'DEWEY', indexer: indexer)[field]).to be_nil
    end
  end

  context 'Gov Doc (call numbers)' do
    it 'has the correct data based on home location' do
      SirsiHolding::GOV_DOCS_LOCS.each do |loc|
        record_with_999(call_number: 'ICAO DOC 4444/15TH ED', scheme: 'ALPHANUM', home_location: 'BRIT-DOCS', indexer: indexer)[field].each do |val|
          expect(val).to start_with('Government Document|')
        end
      end
    end

    it 'has the correct data based on call number scheme' do
      expect(record_with_999(call_number: 'something', scheme: 'SUDOC', indexer: indexer)[field]).to eq(
        ['Government Document|Other']
      )
    end

    it 'has the correct data based on the presence of 086' do
      expect(record_with_999(call_number: 'something', scheme: 'ALPHANUM', indexer: indexer)[field]).to be_nil

      doc = record_with_999(call_number: 'something', scheme: 'ALPHANUM', indexer: indexer) do |marc_record|
        marc_record.append(
          MARC::DataField.new(
            '086',
            ' ',
            ' '
          )
        )
      end

      expect(doc[field]).to eq(['Government Document|Other'])
    end

    it 'handles both GovDocs, LC, and Dewey' do
      doc = record_with_999(call_number: 'I 19.76:98-600-B', scheme: 'SUDOC', home_location: 'SSRC-FICHE', indexer: indexer) do |marc_record|
        marc_record.append(
          MARC::DataField.new(
            '999',
            ' ',
            ' ',
            MARC::Subfield.new('a', '550.6 .U58O 00-600'),
            MARC::Subfield.new('w', 'DEWEYPER')
          )
        )

        marc_record.append(
          MARC::DataField.new(
            '999',
            ' ',
            ' ',
            MARC::Subfield.new('a', 'QE538.8 .N36 1985:APR.'),
            MARC::Subfield.new('w', 'LCPER')
          )
        )
      end

      expect(doc[field]).to eq(
        [
          'LC Classification|Q - Science|QE - Geology',
          'Government Document|Federal',
          'Dewey Classification|500s - Science|550s - Earth Sciences'
        ]
      )
    end
  end
end
