# frozen_string_literal: true

RSpec.describe 'Holdings config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/marc_config.rb')
    end
  end
  ##
  # Custom jRuby setup needed here to create the Traject::MarcCombiningReader
  # with the needed settings and argument type (IO / String:IO)
  if defined? JRUBY_VERSION
    let(:records) do
      Traject::MarcCombiningReader.new(
        File.open(file_fixture(fixture_name).to_s),
        'marc_source.type' => 'binary',
        'marc4j_reader.permissive' => true
      ).to_a
    end
  else
    let(:records) { Traject::MarcCombiningReader.new(file_fixture(fixture_name).to_s, {}).to_a }
  end
  let(:record) { records.first }
  let(:fixture_name) { '44794.marc' }
  subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }

  describe 'on_order_library_ssim' do
    let(:field) { 'on_order_library_ssim' }

    it do
      expect(select_by_id('44794')[field]).to eq ['SAL3']
    end
  end
  describe 'mhld_display' do
    let(:field) { 'mhld_display' }
    describe 'real data' do
      let(:fixture_name) { '2499.marc' }

      it do
        expect(select_by_id('2499')[field]).to eq [
          'MUSIC -|- STACKS -|-  -|- v.1 -|- ',
          'MUSIC -|- STACKS -|-  -|- v.2 -|- '
        ]
      end
      context do
        let(:fixture_name) { '9012.marc' }
        it do
          expect(select_by_id('9012')[field]).to eq [
            'SAL3 -|- STACKS -|-  -|- 1948,1965-1967,1974-1975 -|- '
          ]
        end
      end
      context do
        let(:fixture_name) { '1572.marc' }
        it do
          expect(select_by_id('1572')[field]).to eq [
            'SAL3 -|- STACKS -|-  -|- Heft 1-2 <v.568-569 in series> -|- '
          ]
        end
      end
      context do
        let(:fixture_name) { '7770475.marc' }
        it do
          expect { select_by_id('7770475')[field] }.not_to raise_error
        end
      end
    end
    describe 'unit tests' do
      describe '863 has unit after year' do
        # from http://searchworks.stanford.edu/view/474135
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(MARC::ControlField.new('001', 'aunitAfterYear'))
            r.append(MARC::DataField.new('852', ' ', ' ',
                                         MARC::Subfield.new('a', 'CSt'),
                                         MARC::Subfield.new('b', 'MATH-CS'),
                                         MARC::Subfield.new('c', 'SHELBYTITL'),
                                         MARC::Subfield.new('=', '8287')))
            r.append(MARC::DataField.new('853', '2', ' ',
                                         MARC::Subfield.new('8', '2'),
                                         MARC::Subfield.new('a', 'v.'),
                                         MARC::Subfield.new('b', 'no.'),
                                         MARC::Subfield.new('u', '4'),
                                         MARC::Subfield.new('v', 'r'),
                                         MARC::Subfield.new('i', '(year)'),
                                         MARC::Subfield.new('j', '(unit)')))
            r.append(MARC::DataField.new('863', ' ', '1',
                                         MARC::Subfield.new('8', '2.57'),
                                         MARC::Subfield.new('a', '54'),
                                         MARC::Subfield.new('b', '1'),
                                         MARC::Subfield.new('i', '2013'),
                                         MARC::Subfield.new('j', '1_TRIMESTRE')))
            r.append(MARC::DataField.new('866', '3', '1',
                                         MARC::Subfield.new('8', '1'),
                                         MARC::Subfield.new('a', 'v.25(1984)-')))
          end
        end
        it do
          expect(result[field]).to eq ['MATH-CS -|- SHELBYTITL -|-  -|- v.25(1984)- -|- v.54:no.1 (2013:1_TRIMESTRE)']
        end
      end
      describe 'latest received' do
        # from http://searchworks.stanford.edu/view/474135
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(MARC::ControlField.new('001', 'alatestRecdPatterns'))
            r.append(MARC::DataField.new('852', ' ', ' ',
                                         MARC::Subfield.new('a', 'CSt'),
                                         MARC::Subfield.new('b', 'lib'),
                                         MARC::Subfield.new('c', 'loc'),
                                         MARC::Subfield.new('=', 'output latest received')))
            r.append(MARC::DataField.new('853', '2', ' ',
                                         MARC::Subfield.new('8', '3'),
                                         MARC::Subfield.new('a', 'v.'),
                                         MARC::Subfield.new('b', 'pt.'),
                                         MARC::Subfield.new('u', '3'),
                                         MARC::Subfield.new('v', 'r'),
                                         MARC::Subfield.new('c', 'no.'),
                                         MARC::Subfield.new('v', 'c'),
                                         MARC::Subfield.new('i', '(year)'),
                                         MARC::Subfield.new('j', '(season)')))
            r.append(MARC::DataField.new('863', ' ', '1',
                                         MARC::Subfield.new('8', '3.36'),
                                         MARC::Subfield.new('a', '106'),
                                         MARC::Subfield.new('b', '3'),
                                         MARC::Subfield.new('c', '482'),
                                         MARC::Subfield.new('i', '2010'),
                                         MARC::Subfield.new('j', 'WIN')))
          end
        end
        it do
          expect(result[field]).to eq ['lib -|- loc -|-  -|-  -|- v.106:pt.3:no.482 (2010:WIN)']
        end
        context do
          let(:record) do
            MARC::Record.new.tap do |r|
              r.append(MARC::ControlField.new('001', 'alatestRecdPatterns'))
              r.append(MARC::DataField.new('852', ' ', ' ',
                                           MARC::Subfield.new('a', 'CSt'),
                                           MARC::Subfield.new('b', 'lib'),
                                           MARC::Subfield.new('c', 'loc'),
                                           MARC::Subfield.new('=', 'output latest received')))
              r.append(MARC::DataField.new('853', '2', ' ',
                                           MARC::Subfield.new('8', '1'),
                                           MARC::Subfield.new('a', 'v.'),
                                           MARC::Subfield.new('i', '(year)')))
              r.append(MARC::DataField.new('863', ' ', '1',
                                           MARC::Subfield.new('8', '1.11'),
                                           MARC::Subfield.new('a', '105'),
                                           MARC::Subfield.new('i', '2009')))
            end
          end
          it do
            expect(result[field]).to eq ['lib -|- loc -|-  -|-  -|- v.105 (2009)']
          end
        end
        context do
          let(:record) do
            MARC::Record.new.tap do |r|
              r.append(MARC::ControlField.new('001', 'alatestRecdPatterns'))
              r.append(MARC::DataField.new('852', ' ', ' ',
                                           MARC::Subfield.new('a', 'CSt'),
                                           MARC::Subfield.new('b', 'lib'),
                                           MARC::Subfield.new('c', 'loc'),
                                           MARC::Subfield.new('=', 'output latest received')))
              r.append(MARC::DataField.new('853', '2', ' ',
                                           MARC::Subfield.new('8', '1'),
                                           MARC::Subfield.new('a', 'v.'),
                                           MARC::Subfield.new('b', 'no.'),
                                           MARC::Subfield.new('u', '52'),
                                           MARC::Subfield.new('v', 'r'),
                                           MARC::Subfield.new('i', '(year)'),
                                           MARC::Subfield.new('j', '(month)'),
                                           MARC::Subfield.new('k', '(day)')))
              r.append(MARC::DataField.new('863', ' ', '1',
                                           MARC::Subfield.new('8', '1.569'),
                                           MARC::Subfield.new('a', '205'),
                                           MARC::Subfield.new('b', '10'),
                                           MARC::Subfield.new('i', '2011'),
                                           MARC::Subfield.new('j', '03'),
                                           MARC::Subfield.new('k', '9')))
            end
          end
          it do
            expect(result[field]).to eq ['lib -|- loc -|-  -|-  -|- v.205:no.10 (2011:March 9)']
          end
        end
      end
      describe 'library has includes sub z and sub a from 866/867/868' do
        # https://jirasul.stanford.edu/jira/browse/SW-885
        context '866subz' do
          let(:record) do
            # from http://searchworks.stanford.edu/view/48690
            MARC::Record.new.tap do |r|
              r.append(MARC::ControlField.new('001', 'asubz866'))
              r.append(MARC::DataField.new('852', ' ', ' ',
                                           MARC::Subfield.new('a', 'CSt'),
                                           MARC::Subfield.new('b', 'lib'),
                                           MARC::Subfield.new('c', 'loc')))
              r.append(MARC::DataField.new('866', ' ', '0',
                                           MARC::Subfield.new('8', '1'),
                                           MARC::Subfield.new('a', 'pt.1-4'),
                                           MARC::Subfield.new('z', '<v.3,16,27-28 in series>')))
              r.append(MARC::DataField.new('866', '8', '1',
                                           MARC::Subfield.new('8', '1'),
                                           MARC::Subfield.new('a', 'pt.2'),
                                           MARC::Subfield.new('z', '<v.16 in series>')))
              r.append(MARC::DataField.new('866', '8', '1',
                                           MARC::Subfield.new('8', '1'),
                                           MARC::Subfield.new('a', 'pt.5')))
            end
          end
          it do
            expect(result[field][0]).to eq 'lib -|- loc -|-  -|- pt.1-4 <v.3,16,27-28 in series> -|- '
            expect(result[field][1]).to eq 'lib -|- loc -|-  -|- pt.2 <v.16 in series> -|- '
            expect(result[field][2]).to eq 'lib -|- loc -|-  -|- pt.5 -|- '
          end
        end
        context '867subz' do
          let(:record) do
            MARC::Record.new.tap do |r|
              r.append(MARC::ControlField.new('001', 'asubz867'))
              r.append(MARC::DataField.new('852', ' ', ' ',
                                           MARC::Subfield.new('a', 'CSt'),
                                           MARC::Subfield.new('b', 'lib'),
                                           MARC::Subfield.new('c', 'loc')))
              r.append(MARC::DataField.new('867', ' ', '0',
                                           MARC::Subfield.new('8', '1'),
                                           MARC::Subfield.new('a', 'first'),
                                           MARC::Subfield.new('z', 'subz')))
              r.append(MARC::DataField.new('867', ' ', '0',
                                           MARC::Subfield.new('8', '1'),
                                           MARC::Subfield.new('a', 'second')))
              r.append(MARC::DataField.new('866', '3', '1',
                                           MARC::Subfield.new('8', '0'),
                                           MARC::Subfield.new('a', 'v.188')))
            end
          end
          it do
            expect(result[field].length).to eq 3
            expect(result[field][0]).to eq 'lib -|- loc -|-  -|- v.188 -|- '
            expect(result[field][1]).to eq 'lib -|- loc -|-  -|- Supplement: first subz -|- '
            expect(result[field][2]).to eq 'lib -|- loc -|-  -|- Supplement: second -|- '
          end
        end
        context '868subz' do
          let(:record) do
            MARC::Record.new.tap do |r|
              r.append(MARC::ControlField.new('001', 'asubz868'))
              r.append(MARC::DataField.new('852', ' ', ' ',
                                           MARC::Subfield.new('a', 'CSt'),
                                           MARC::Subfield.new('b', 'lib'),
                                           MARC::Subfield.new('c', 'loc')))
              r.append(MARC::DataField.new('868', ' ', '0',
                                           MARC::Subfield.new('8', '1'),
                                           MARC::Subfield.new('a', 'first'),
                                           MARC::Subfield.new('z', 'subz')))
              r.append(MARC::DataField.new('868', ' ', '0',
                                           MARC::Subfield.new('8', '1'),
                                           MARC::Subfield.new('a', 'second')))
              r.append(MARC::DataField.new('866', '3', '1',
                                           MARC::Subfield.new('8', '0'),
                                           MARC::Subfield.new('a', 'v.188')))
            end
          end
          it do
            expect(result[field].length).to eq 3
            expect(result[field][0]).to eq 'lib -|- loc -|-  -|- v.188 -|- '
            expect(result[field][1]).to eq 'lib -|- loc -|-  -|- Index: first subz -|- '
            expect(result[field][2]).to eq 'lib -|- loc -|-  -|- Index: second -|- '
          end
        end
      end
      describe '"latest" should be populated but only when 853 matches latest recd 863' do
        # https://jirasul.stanford.edu/jira/browse/VUF-2617
        # from http://searchworks.stanford.edu/view/3454845
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(MARC::ControlField.new('001', 'alatest'))
            r.append(MARC::DataField.new('852', ' ', ' ',
                                         MARC::Subfield.new('a', 'CSt'),
                                         MARC::Subfield.new('b', 'lib'),
                                         MARC::Subfield.new('c', 'loc'),
                                         MARC::Subfield.new('=', '41906')))
            r.append(MARC::DataField.new('853', '2', ' ',
                                         MARC::Subfield.new('8', '2'),
                                         MARC::Subfield.new('a', '(year)')))
            r.append(MARC::DataField.new('853', '2', ' ',
                                         MARC::Subfield.new('8', '3'),
                                         MARC::Subfield.new('a', '(year)'),
                                         MARC::Subfield.new('b', 'pt.'),
                                         MARC::Subfield.new('u', '2'),
                                         MARC::Subfield.new('v', 'r')))
            r.append(MARC::DataField.new('866', '3', '1',
                                         MARC::Subfield.new('8', '1'),
                                         MARC::Subfield.new('a', '2003,2006-')))
            r.append(MARC::DataField.new('863', ' ', '1',
                                         MARC::Subfield.new('8', '2.1'),
                                         MARC::Subfield.new('a', '2003')))
            r.append(MARC::DataField.new('863', ' ', '1',
                                         MARC::Subfield.new('8', '3.1'),
                                         MARC::Subfield.new('a', '2006'),
                                         MARC::Subfield.new('b', '1')))
            r.append(MARC::DataField.new('863', ' ', '1',
                                         MARC::Subfield.new('8', '3.2'),
                                         MARC::Subfield.new('a', '2006'),
                                         MARC::Subfield.new('b', '2')))
            r.append(MARC::DataField.new('863', ' ', '1',
                                         MARC::Subfield.new('8', '3.3'),
                                         MARC::Subfield.new('a', '2011'),
                                         MARC::Subfield.new('b', '1')))
            r.append(MARC::DataField.new('863', ' ', '1',
                                         MARC::Subfield.new('8', '3.4'),
                                         MARC::Subfield.new('a', '2011'),
                                         MARC::Subfield.new('b', '2')))
          end
        end
        it do
          expect(result[field].length).to eq 1
          expect(result[field]).to eq ['lib -|- loc -|-  -|- 2003,2006- -|- 2011:pt.2']
        end
      end
      describe 'malformed 863$8' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(MARC::ControlField.new('001', 'malformedsub8'))
            r.append(MARC::DataField.new('852', ' ', ' ',
                                         MARC::Subfield.new('a', 'CSt'),
                                         MARC::Subfield.new('b', 'EAST-ASIA'),
                                         MARC::Subfield.new('c', 'CHINESE')))
            r.append(MARC::DataField.new('866', '3', '1',
                                         MARC::Subfield.new('a', 'v.5:no.7/8(1982:June)-v.7:no.9/10(1983:Aug.);v.8:no.1/2(1983:Sept.)-v.13:no.9/10(1988:Oct.),v.13:no.9(1992:Aug.)-v.14:no.9(1993:Oct.); '),
                                         MARC::Subfield.new('8', '0')))
            r.append(MARC::DataField.new('863', '3', '1',
                                         MARC::Subfield.new('a', 'no.182/183(1994:Jan.)-no.191(1994:Oct.),no.193(1994:Dec.)-no.229(1997:Dec.) '),
                                         MARC::Subfield.new('8', '0'),
                                         MARC::Subfield.new('c', 'No content metadata'),
                                         MARC::Subfield.new('d', 'Lucie King Harris Fund')))
          end
        end
        it do
          expect(result[field].count).to eq 1
          expect(result[field]).to include(/^EAST-ASIA/)
        end
      end
    end
    describe 'mapping tests' do
      describe 'test 852 output' do
        let(:fixture_name) { 'mhldDisplay852only.mrc' }
        it do
          expect(select_by_id('358041')[field].length).to eq 3
          expect(select_by_id('358041')[field][0]).to eq 'GREEN -|- CURRENTPER -|- COUNTRY LIFE INTERNATIONAL. Latest yr. (or vol.) in CURRENT PERIODICALS; earlier in SAL -|-  -|- '
          expect(select_by_id('358041')[field][1]).to eq 'GREEN -|- CURRENTPER -|- Latest yr. (or vol.) in CURRENT PERIODICALS; earlier in SAL -|-  -|- '
          expect(select_by_id('358041')[field][2]).to eq 'GREEN -|- CURRENTPER -|- COUNTRY LIFE TRAVEL. Latest yr. (or vol.) in CURRENT PERIODICALS; earlier in SAL -|-  -|- '
        end
      end
      describe 'skip mhlds' do
        # per spec in email by Naomi Dushay on July 12, 2011, an MHLD is skipped
        # if 852 sub z  says "All holdings transfered"
        let(:fixture_name) { 'mhldDisplay852only.mrc' }
        it do
          expect(select_by_id('3974376')[field]).to be_nil
        end
      end
      describe 'skip skipped locations' do
        # if an 852 has a location in the locations_skipped_list.properties, then
        # it should not be included.
        let(:fixture_name) { 'mhldDisplay.mrc' }
        it do
          expect(select_by_id('SkippedLocs')[field]).to be_blank
        end
      end
      describe 'number of separators' do
        # ensure output with and without 86x have same number of separators
        let(:fixture_name) { 'mhldDisplay852only.mrc' }
        it '852 alone without comment' do
          expect(select_by_id('358041')[field]).not_to include 'SAL3 -|- STACKS -|-  -|-  -|- '
        end
        it '852 alone without comment' do
          expect(select_by_id('358041')[field]).to include 'GREEN -|- CURRENTPER -|- Latest yr. (or vol.) in CURRENT PERIODICALS; earlier in SAL -|-  -|- '
        end
        describe '852 w/ 866' do
          let(:fixture_name) { 'mhldDisplay868.mrc' }
          it do
            expect(select_by_id('keep868ind0')[field]).to include 'GREEN -|- CURRENTPER -|- keep 868 -|- v.194(2006)- -|- '
            expect(select_by_id('keep868ind0')[field]).to include 'GREEN -|- CURRENTPER -|-  -|- Index: keep me (868) -|- '
          end
        end
        describe '852 w/ 867' do
          let(:fixture_name) { 'mhldDisplay867.mrc' }
          it do
            expect(select_by_id('keep867ind0')[field]).to include 'GREEN -|- CURRENTPER -|- keep 867 -|- Supplement: keep me (867) -|- '
          end
        end
      end
      describe 'ensure all (non-skipped) 866s are output correctly' do
        let(:fixture_name) { 'mhldDisplay86x.mrc' }
        it do
          expect(select_by_id('358041')[field]).to include 'GREEN -|- CURRENTPER -|- COUNTRY LIFE INTERNATIONAL. Latest yr. (or vol.) in CURRENT PERIODICALS; earlier in SAL -|- 2009- -|- '
          expect(select_by_id('358041')[field]).to include 'SAL3 -|- STACKS -|-  -|- v.151(1972)-v.152(1972) -|- '
          expect(select_by_id('358041')[field]).to include 'SAL -|- STACKS -|-  -|- 1953; v.143(1968)-v.144(1968),v.153(1973)-v.154(1973),v.164(1978),v.166(1979),v.175(1984),v.178(1985),v.182(1988)-v.183(1989),v.194(2000)- -|- '
          expect(select_by_id('358725')[field]).to include 'GREEN -|- CURRENTPER -|- Latest yr. (or vol.) in CURRENT PERIODICALS; earlier in STACKS -|- [18-38, 1922-42]; 39, 1943- -|- '
        end
      end
      describe 'multiple 866' do
        # when there are multiple 866s in a record, the "latest received" should
        # only attach to the open holdings statement
        let(:fixture_name) { 'mhldDisplayEasy2.mrc' }
        it do
          expect(select_by_id('111')[field].length).to eq 4
          expect(select_by_id('111')[field][0]).to eq 'lib1 -|- loc1 -|- comment1 -|- 866a1open- -|- v.417:no.11 (2011:March 25)'
          expect(select_by_id('111')[field][1]).to eq 'lib1 -|- loc1 -|-  -|- 866a2closed -|- '
          expect(select_by_id('111')[field][2]).to eq 'lib1 -|- loc1 -|-  -|- 866a3closed -|- '
          expect(select_by_id('111')[field][3]).to eq 'lib1 -|- loc1 -|-  -|- 866a4closed -|- '
        end
      end
      describe '866 and 867' do
        # the "latest received" should only attach to the open holdings statement
        # when there are multiple 866s, or combination of 866 and 867 or 868
        let(:fixture_name) { 'mhldDisplayEasy2.mrc' }
        it do
          expect(select_by_id('222')[field].length).to eq 2
          expect(select_by_id('222')[field][0]).to eq 'lib1 -|- loc1 -|-  -|- 866a1open- -|- no.322 (2011:March)'
          expect(select_by_id('222')[field][1]).to eq 'lib1 -|- loc1 -|-  -|- Supplement: 867a -|- '
        end
      end
      describe 'no longer skipped 866' do
        # per email by Naomi Dushay on October 14, 2011, MHLD summary holdings are
        #  NOT skipped: display 866 regardless of second indicator value or presence of 852 sub =
        # previously:
        # per spec in email by Naomi Dushay on July 12, 2011, an MHLD summary holdings section
        #  is skipped if 866 has ind2 of 0 and 852 has a sub =
        let(:fixture_name) { 'mhldDisplay86x.mrc' }
        it do
          expect(select_by_id('362573')[field]).to include 'GREEN -|- CURRENTPER -|-  -|- V. 417 NO. 1A (JAN 2011) -|- '
          expect(select_by_id('362573')[field]).to include 'GREEN -|- CURRENTPER -|-  -|- V. 417 NO. 4A (FEB 2011) -|- '
          expect(select_by_id('362573')[field]).to include 'GREEN -|- CURRENTPER -|-  -|- V. 417 NO. 5A (FEB 2011) -|- '
          expect(select_by_id('362573')[field]).to include 'GREEN -|- CURRENTPER -|-  -|- V. 417 NO. 20A (JUN 2011) -|- '
          expect(select_by_id('362573')[field]).to include 'GREEN -|- CURRENTPER -|-  -|- V. 417 NO. 21A (JUN 2011) -|- '
          expect(select_by_id('362573')[field]).to include 'GREEN -|- CURRENTPER -|-  -|- V. 417 NO. 22A (JUN 2011) -|- '
          expect(select_by_id('362573')[field]).to include 'GREEN -|- CURRENTPER -|-  -|- V. 417 NO. 23A (JUN 2011) -|- '
        end
      end
      describe 'ensure all (non-skipped) 867s are output correctly' do
        let(:fixture_name) { 'mhldDisplay867.mrc' }
        it do
          expect(select_by_id('keep867ind0')[field]).to eq ['GREEN -|- CURRENTPER -|- keep 867 -|- Supplement: keep me (867) -|- ']
          expect(select_by_id('multKeep867ind0')[field][0]).to eq 'GREEN -|- STACKS -|- Supplement -|- Supplement: keep me 1 (867) -|- '
          expect(select_by_id('multKeep867ind0')[field][1]).to eq 'GREEN -|- STACKS -|-  -|- Supplement: keep me 2 (867) -|- '
        end
      end
      describe '867 no 866' do
        # ensure there is a "Latest Received" value when there is an 867 without
        # an 866, and there are 863s
        let(:fixture_name) { 'mhldDisplay.mrc' }
        it do
          expect(select_by_id('358041')[field]).to include 'GREEN -|- CURRENTPER -|- Latest yr. (or vol.) in CURRENT PERIODICALS; earlier in SAL -|- Supplement: COUNTRY LIFE ABROAD (WIN 2001), (JUL 14, 2005) -|- v.205:no.22 (2011:June 1)'
        end
      end
      describe 'no longer skipped 867' do
        ##
        # per email by Naomi Dushay on October 14, 2011, MHLD summary holdings are
        #  NOT skipped: display 867 regardless of second indicator value or presence of 852 sub =
        # previously:
        # per spec in email by Naomi Dushay on July 12, 2011, an MHLD summary holdings section
        #  is skipped if 867 has ind2 of 0 and 852 has a sub =
        let(:fixture_name) { 'mhldDisplay867.mrc' }
        it do
          start = 'GREEN -|- STACKS -|-  -|- Supplement: '
          expect(select_by_id('skip867ind0')[field]).to eq ["#{start}skip me (867) -|- "]
          expect(select_by_id('multSkip867ind0')[field]).to eq [
            "#{start}skip me 1 (867) -|- ",
            "#{start}skip me 2 (867) -|- ",
            'GREEN -|- STACKS -|- Supplement -|-  -|- '
          ]
        end
      end
      describe 'ensure all (non-skipped) 867s are output correctly' do
        let(:fixture_name) { 'mhldDisplay868.mrc' }
        # keep if 2nd indicator "0" and no 852 sub =
        it do
          expect(select_by_id('keep868ind0')[field]).to include 'GREEN -|- CURRENTPER -|- keep 868 -|- v.194(2006)- -|- '
          expect(select_by_id('keep868ind0')[field]).to include 'GREEN -|- CURRENTPER -|-  -|- Index: keep me (868) -|- '
          expect(select_by_id('multKeep868ind0')[field]).to include 'MUSIC -|- MUS-NOCIRC -|-  -|- Index: keep me 1 (868) -|- '
          expect(select_by_id('multKeep868ind0')[field]).to include 'MUSIC -|- MUS-NOCIRC -|-  -|- Index: keep me 2 (868) -|- '
        end
        context 'mhldDisplay86x' do
          let(:fixture_name) { 'mhldDisplay86x.mrc' }
          it do
            expect(select_by_id('484112')[field]).to include 'MUSIC -|- MUS-NOCIRC -|-  -|- Index: annee.188(1999) -|- '
            expect(select_by_id('484112')[field]).to include 'MUSIC -|- MUS-NOCIRC -|-  -|- Index: MICROFICHE (MAY/DEC 2000) -|- '
          end
        end
      end
      describe 'no longer skipped 868' do
        ##
        # per email by Naomi Dushay on October 14, 2011, MHLD summary holdings are
        #  NOT skipped: display 868 regardless of second indicator value or presence of 852 sub =
        # previously:
        # per spec in email by Naomi Dushay on July 12, 2011, an MHLD summary holdings section
        #  is skipped if 868 has ind2 of 0 and 852 has a sub =
        let(:fixture_name) { 'mhldDisplay868.mrc' }
        it do
          expect(select_by_id('skip868ind0')[field]).to include 'GREEN -|- CURRENTPER -|- skip 868 -|- v.194(2006)- -|- '
          expect(select_by_id('skip868ind0')[field]).to include 'GREEN -|- CURRENTPER -|-  -|- Index: skip me (868) -|- '
          start = 'MUSIC -|- MUS-NOCIRC -|-  -|- Index: '
          expect(select_by_id('multSkip868ind0')[field]).to include "#{start}skip me 1 (868) -|- "
          expect(select_by_id('multSkip868ind0')[field]).to include "#{start}skip me 2 (868) -|- "
        end
      end
      describe '852 subfield 3 should be included in the comment' do
        let(:fixture_name) { 'mhldDisplay852sub3.mrc' }
        it do
          expect(select_by_id('852zNo3')[field]).to eq ['GREEN -|- STACKS -|- sub z -|-  -|- ']
          expect(select_by_id('852-3noZ')[field]).to eq ['GREEN -|- STACKS -|- sub 3 -|-  -|- ']
          expect(select_by_id('852zAnd3')[field]).to eq ['GREEN -|- STACKS -|- sub 3 sub z -|-  -|- ']
        end
      end
      describe 'latest received' do
        # if the 866 field is open (ends with a hyphen), then use the most recent
        # 863, formatted per matching 853
        let(:fixture_name) { 'mhldDisplay.mrc' }
        it do
          expect(select_by_id('latestRecdPatterns')[field]).to include 'lib -|- loc -|-  -|-  -|- v.106:pt.3:no.482 (2010:WIN)'
          expect(select_by_id('latestRecdPatterns')[field]).to include 'lib -|- loc -|-  -|-  -|- v.105 (2009)'
          expect(select_by_id('latestRecdPatterns')[field]).to include 'lib -|- loc -|-  -|-  -|- v.205:no.10 (2011:March 9)'
          expect(select_by_id('358041')[field]).to include 'GREEN -|- CURRENTPER -|- COUNTRY LIFE INTERNATIONAL. Latest yr. (or vol.) in CURRENT PERIODICALS; earlier in SAL -|- 2009- -|- 2011:Summer'
        end
      end
      describe 'closed holdings' do
        # there should be no "Latest Received" portion when the 866 is closed
        # (doesn't end with a hyphen)
        let(:fixture_name) { 'mhldDisplay.mrc' }
        it do
          # 866 doesn't end with hyphen, and there are 863 - do not include 863 as Latest Received
          expect(select_by_id('484112')[field]).to include 'MUSIC -|- MUS-NOCIRC -|-  -|- v.188(1999) -|- '
          expect(select_by_id('484112')[field]).not_to include 'MUSIC -|- MUS-NOCIRC -|-  -|- v.188(1999) -|- annee 188 no.14 Dec 17, 1999'
        end
      end
      describe 'no 866' do
        # if there is no 866, then
        # if the 852 has a sub = , then display the most recent 863
        let(:fixture_name) { 'mhldDisplay.mrc' }
        it do
          # 852 has sub =  and no 866:  use most recent 863
          expect(select_by_id('358041')[field]).to include 'GREEN -|- CURRENTPER -|- COUNTRY LIFE TRAVEL. Latest yr. (or vol.) in CURRENT PERIODICALS; earlier in SAL -|-  -|- 2010/2011:Winter'
          # 852 has no sub =  and no 866:  do not use latest 863
          expect(select_by_id('2416921')[field]).to include 'GREEN -|- CURRENTPER -|- Latest yr. (or vol.) in CURRENT PERIODICALS; earlier in SAL3 -|-  -|- '
        end
      end
      describe 'multiple 852z' do
        # if an 852 has multiple subfield z, they should be concatenated with a " "
        let(:fixture_name) { 'mhldDisplay.mrc' }
        it do
          expect(select_by_id('852multz')[field]).to include 'LANE -|- STACKS -|- z4 z5 z6 -|-  -|- '
          expect(select_by_id('852multz')[field]).to include 'CROWN -|- STACKS -|- z1 z2 -|- 866a -|- '
          expect(select_by_id('852multz')[field]).to include 'HOOVER -|- STACKS -|- z3 -|- 866a -|- '
        end
      end
      describe 'single 852z' do
        # if an 852 has only one 866, with 853/863, ensure only one field is output.
        let(:fixture_name) { 'mhldDisplay.mrc' }
        it do
          expect(select_by_id('866before863')[field]).to eq ['lib -|- loc -|- comment -|- 1, 1977- -|- v.23:no.1 (1999:January)']
        end
      end
      describe '358041' do
        let(:fixture_name) { 'mhldDisplay.mrc' }
        it do
          # 852 has sub =  and no 866:  use most recent 863
          expect(select_by_id('358041')[field]).to include 'GREEN -|- CURRENTPER -|- COUNTRY LIFE INTERNATIONAL. Latest yr. (or vol.) in CURRENT PERIODICALS; earlier in SAL -|- 2009- -|- 2011:Summer'
          expect(select_by_id('358041')[field]).to include 'SAL3 -|- STACKS -|-  -|- v.151(1972)-v.152(1972) -|- '
          expect(select_by_id('358041')[field]).to include 'SAL -|- STACKS -|-  -|- 1953; v.143(1968)-v.144(1968),v.153(1973)-v.154(1973),v.164(1978),v.166(1979),v.175(1984),v.178(1985),v.182(1988)-v.183(1989),v.194(2000)- -|- '
          # 867 ind 0  previous 852 has sub =  - now used per email by Naomi Dushay on October 14, 2011
          expect(select_by_id('358041')[field]).to include 'GREEN -|- CURRENTPER -|- Latest yr. (or vol.) in CURRENT PERIODICALS; earlier in SAL -|- Supplement: COUNTRY LIFE ABROAD (WIN 2001), (JUL 14, 2005) -|- v.205:no.22 (2011:June 1)'
          expect(select_by_id('358041')[field]).to include 'GREEN -|- CURRENTPER -|- COUNTRY LIFE TRAVEL. Latest yr. (or vol.) in CURRENT PERIODICALS; earlier in SAL -|-  -|- 2010/2011:Winter'
        end
      end
      describe 'test the expected values for a record with easier text strings' do
        let(:fixture_name) { 'mhldDisplayEasy.mrc' }
        it do
          expect(select_by_id('358041')[field]).to include 'lib1 -|- loc1 -|- comment1 -|- 866a1open- -|- 2011:Summer'
          expect(select_by_id('358041')[field]).to include 'lib2 -|- loc2 -|-  -|- 866a2 -|- '
          expect(select_by_id('358041')[field]).to include 'lib3 -|- loc3 -|-  -|- 866a3open- -|- '
          expect(select_by_id('358041')[field]).to include 'lib1 -|- loc1 -|- comment4 -|- Supplement: 867a -|- v.205:no.22 (2011:June 1)'
          expect(select_by_id('358041')[field]).to include 'lib1 -|- loc1 -|- comment5 -|-  -|- 2010/2011:Winter'
        end
      end
    end
  end
  describe 'bookplates_display' do
    let(:field) { 'bookplates_display' }
    describe 'population of bookplates_display' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::ControlField.new('001', 'aunitAfterYear'))
          r.append(MARC::DataField.new('979', ' ', ' ',
                                       MARC::Subfield.new('f', 'BAILEYT'),
                                       MARC::Subfield.new('b', 'druid:tf882hn2198'),
                                       MARC::Subfield.new('c', 'tf882hn2198_00_0001.jp2'),
                                       MARC::Subfield.new('d', 'Annie Nelson Bailey Memorial Book Fund')))
        end
      end
      it do
        expect(result[field]).to eq ['BAILEYT -|- tf882hn2198 -|- tf882hn2198_00_0001.jp2 -|- Annie Nelson Bailey Memorial Book Fund']
      end
    end
    describe 'multiple 979' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::ControlField.new('001', 'aunitAfterYear'))
          r.append(MARC::DataField.new('979', ' ', ' ',
                                       MARC::Subfield.new('f', 'BAILEYT'),
                                       MARC::Subfield.new('b', 'druid:tf882hn2198'),
                                       MARC::Subfield.new('c', 'tf882hn2198_00_0001.jp2'),
                                       MARC::Subfield.new('d', 'Annie Nelson Bailey Memorial Book Fund')))
          r.append(MARC::DataField.new('979', ' ', ' ',
                                       MARC::Subfield.new('f', 'HARRISL'),
                                       MARC::Subfield.new('b', 'druid:bm267dr4255'),
                                       MARC::Subfield.new('c', 'No content metadata'),
                                       MARC::Subfield.new('d', 'Lucie King Harris Fund')))
          r.append(MARC::DataField.new('979', ' ', ' ',
                                       MARC::Subfield.new('f', 'BENDERRM'),
                                       MARC::Subfield.new('b', 'druid:hd360gv1231'),
                                       MARC::Subfield.new('c', 'hd360gv1231_00_0001.jp2'),
                                       MARC::Subfield.new('d', 'Stanford Bookstore : Centennial')))
        end
      end
      it do
        expect(result[field].count).to eq 2
        expect(result[field][0]).to eq 'BAILEYT -|- tf882hn2198 -|- tf882hn2198_00_0001.jp2 -|- Annie Nelson Bailey Memorial Book Fund'
        expect(result[field][1]).to eq 'BENDERRM -|- hd360gv1231 -|- hd360gv1231_00_0001.jp2 -|- Stanford Bookstore : Centennial'
      end
    end
    describe 'no content' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::ControlField.new('001', 'aunitAfterYear'))
          r.append(MARC::DataField.new('979', ' ', ' ',
                                       MARC::Subfield.new('f', 'HARRISL'),
                                       MARC::Subfield.new('b', 'druid:bm267dr4255'),
                                       MARC::Subfield.new('c', 'No content metadata'),
                                       MARC::Subfield.new('d', 'Lucie King Harris Fund')))
        end
      end
      it do
        expect(result[field]).to be_nil
      end
    end
  end
  describe 'fund_facet' do
    let(:field) { 'fund_facet' }
    describe 'population of fund_facet' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::ControlField.new('001', 'aunitAfterYear'))
          r.append(MARC::DataField.new('979', ' ', ' ',
                                       MARC::Subfield.new('f', 'BENDERRM'),
                                       MARC::Subfield.new('b', 'druid:hd360gv1231'),
                                       MARC::Subfield.new('c', 'hd360gv1231_00_0001.jp2'),
                                       MARC::Subfield.new('d', 'Stanford Bookstore : Centennial')))
        end
      end
      it do
        expect(result[field]).to eq %w[BENDERRM hd360gv1231]
      end
    end
    describe 'multiple 979' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::ControlField.new('001', 'aunitAfterYear'))
          r.append(MARC::DataField.new('979', ' ', ' ',
                                       MARC::Subfield.new('f', 'BAILEYT'),
                                       MARC::Subfield.new('b', 'druid:tf882hn2198'),
                                       MARC::Subfield.new('c', 'tf882hn2198_00_0001.jp2'),
                                       MARC::Subfield.new('d', 'Annie Nelson Bailey Memorial Book Fund')))
          r.append(MARC::DataField.new('979', ' ', ' ',
                                       MARC::Subfield.new('f', 'HARRISL'),
                                       MARC::Subfield.new('b', 'druid:bm267dr4255'),
                                       MARC::Subfield.new('c', 'No content metadata'),
                                       MARC::Subfield.new('d', 'Lucie King Harris Fund')))
          r.append(MARC::DataField.new('979', ' ', ' ',
                                       MARC::Subfield.new('f', 'BENDERRM'),
                                       MARC::Subfield.new('b', 'druid:hd360gv1231'),
                                       MARC::Subfield.new('c', 'hd360gv1231_00_0001.jp2'),
                                       MARC::Subfield.new('d', 'Stanford Bookstore : Centennial')))
        end
      end
      it do
        expect(result[field]).to eq %w[BAILEYT tf882hn2198 BENDERRM hd360gv1231]
      end
    end
  end
end
