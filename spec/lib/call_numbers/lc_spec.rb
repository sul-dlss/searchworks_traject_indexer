require 'call_numbers/lc'

describe CallNumbers::LC do

  describe 'standard numbers' do
    it 'handles 1 - 3 class letters' do
      expect(described_class.new('P123.23 .M23 2002').klass).to eq 'P'
      expect(described_class.new('PS123.23 .M23 2002').klass).to eq 'PS'
      expect(described_class.new('PSX123.23 .M23 2002').klass).to eq 'PSX'
    end

    it 'parses the class number and decimal' do
      expect(described_class.new('P123.23 .M23 2002').klass_number).to eq '123'
      expect(described_class.new('P123.23 .M23 2002').klass_decimal).to eq '.23'

      expect(described_class.new('P123 .M23 2002').klass_number).to eq '123'
      expect(described_class.new('P123 .M23 2002').klass_decimal).to be_nil
    end

    describe 'doons (dates or other numbers)' do
      it 'parses a doon after the class number/decimal and before the 1st cutter' do
        expect(described_class.new('P123.23 2012 .M23 2002 .M45 V.1').doon1).to match(/^2012/)
      end

      it 'parses a doon after the 1st cutter and before other cutters' do
        expect(described_class.new('P123.23 2012 .M23 2002 .M45 V.1').doon2).to match(/^2002/)
      end

      it 'parses a doon after the 2nd cutter and before other cutters' do
        expect(described_class.new('G4362 .L3 .E63 1997 .E2').doon3).to match(/^1997/)
      end

      it 'allows for characters after the number in the doon (e.g. 12TH)' do
        expect(described_class.new('P123.23 20TH .M45 V.1').doon1).to match(/^20TH/)
      end
    end

    describe 'cutters' do
      it 'handles 3 possible cutters' do
        expect(described_class.new('P123.23 .M23 V.1 2002').cutter1).to eq '.M23'
        expect(described_class.new('P123.23 .M23 V.1 2002').cutter2).to be_nil
        expect(described_class.new('P123.23 .M23 V.1 2002').cutter3).to be_nil

        expect(described_class.new('P123.23 .M23 .M45 V.1 2002').cutter1).to eq '.M23'
        expect(described_class.new('P123.23 .M23 .M45 V.1 2002').cutter2).to eq '.M45'
        expect(described_class.new('P123.23 .M23 .M45 V.1 2002').cutter3).to be_nil

        expect(described_class.new('P123.23 .M23 .M45 .S32 V.1 2002').cutter1).to eq '.M23'
        expect(described_class.new('P123.23 .M23 .M45 .S32 V.1 2002').cutter2).to eq '.M45'
        expect(described_class.new('P123.23 .M23 .M45 .S32 V.1 2002').cutter3).to eq '.S32'
      end

      it 'handles multi-letter cutters' do
        expect(described_class.new('P123.23 .MS23').cutter1).to eq '.MS23'
        expect(described_class.new('P123.23 .MSA23').cutter1).to eq '.MSA23'
      end

      it 'handles a single letter after the cutter number' do
        expect(described_class.new('P123.23 .MS23A').cutter1).to eq '.MS23A'
      end

      it 'parses cutters that do not have a space before them' do
        expect(described_class.new('P123.23.M23.S32').cutter1).to eq '.M23'
        expect(described_class.new('P123.23.M23.S32').cutter2).to eq '.S32'
      end

      it 'parses cutters with no space or period' do
        expect(described_class.new('P123M23S').cutter1).to eq 'M23S'
        expect(described_class.new('P123M23SL').cutter1).to eq 'M23SL'
        expect(described_class.new('P123M23S32').cutter1).to eq 'M23'
        expect(described_class.new('P123M23S32').cutter2).to eq 'S32'
      end
    end

    describe 'folio' do
      it 'handles folio' do
        expect(described_class.new('P123M23S32 F 123').folio).to eq 'F'
      end

      it 'handles a folio at the end of the string' do
        expect(described_class.new('P123M23S32 F').folio).to eq 'F'
      end

      it 'handles a flat folio at the end of the string' do
        expect(described_class.new('P123M23S32 FF').folio).to eq 'FF'
      end

      it 'does nothing with tons of Fs' do
        expect(described_class.new('P123M23S32 FFFFF').folio).to eq nil
      end
    end

    describe 'the rest of the stuff' do
      it 'puts any other content into the rest attribute' do
        expect(described_class.new('P123.23 .M23 V.1 2002').rest).to eq 'V.1 2002'
        expect(described_class.new('P123.23 2012 .M23 2002 .M45 V.1 2002-2012/GobbldyGoop').rest).to eq 'V.1 2002-2012/GobbldyGoop'
      end
    end

    describe '#lopped' do
      context 'non-serial' do
        it 'leaves cutters in tact' do
          expect(described_class.new('P123.23 .M23 A12').lopped).to eq 'P123.23 .M23 A12'
        end

        it 'drops data after the first volume designation' do
          expect(described_class.new('PN2007 .S589 NO.17 1998').lopped).to eq 'PN2007 .S589'
          expect(described_class.new('PN2007 .K3 V.7:NO.4').lopped).to eq 'PN2007 .K3'
          expect(described_class.new('PN2007 .K3 V.8:NO.1-2 1972').lopped).to eq 'PN2007 .K3'
          expect(described_class.new('PN2007 .K3 V.5-6:NO.11-25 1967-1970').lopped).to eq 'PN2007 .K3'
          expect(described_class.new('PN2007 .S3 NO.14-15,34').lopped).to eq 'PN2007 .S3'
        end

        it 'retains a year right after the cutter' do
          expect(described_class.new('PN2007 .S3 1987').lopped).to eq 'PN2007 .S3 1987'
          expect(described_class.new('PN2007 .K93 2002/2003:NO.3/1').lopped).to eq 'PN2007 .K93 2002/2003'
          expect(described_class.new('PN2007 .Z37 1993:JAN.-DEC').lopped).to eq 'PN2007 .Z37 1993'
          expect(described_class.new('PN2007 .Z37 1994:SEP-1995:JUN').lopped).to eq 'PN2007 .Z37 1994'
          expect(described_class.new('PN2007 .K93 2002:NO.1-2').lopped).to eq 'PN2007 .K93 2002'
        end

        it 'handles multiple cutters' do
          expect(described_class.new('PN1993.5 .A35 A373 VOL.4').lopped).to eq 'PN1993.5 .A35 A373'
          expect(described_class.new('PN1993.5 .A1 S5595 V.2 2008').lopped).to eq 'PN1993.5 .A1 S5595'
          expect(described_class.new('PN1993.5 .A75 C564 V.1:NO.1-4 2005').lopped).to eq 'PN1993.5 .A75 C564'
          expect(described_class.new('PN1993.5 .L3 S78 V.1-2 2004-2005').lopped).to eq 'PN1993.5 .L3 S78'

          # When the year is first
          expect(described_class.new('PN1993.5 .F7 A3 2006:NO.297-300').lopped).to eq 'PN1993.5 .F7 A3 2006'
          expect(described_class.new('JQ1519 .A5 A369 1990:NO.1-9+SUPPL.').lopped).to eq 'JQ1519 .A5 A369 1990'
          expect(described_class.new('PN1993.5 .F7 A3 2005-2006 SUPPL.NO.27-30').lopped).to eq 'PN1993.5 .F7 A3 2005-2006 SUPPL'
          expect(described_class.new('PN1993.5 .S6 S374 F 2001:JUL.-NOV.').lopped).to eq 'PN1993.5 .S6 S374 F 2001'
        end

        it 'does not lop off an existing ellipsis' do
          expect(described_class.new('A1 .B2 ...').lopped).to eq 'A1 .B2 ...'
          expect(described_class.new('A1 .B2 BOO ...').lopped).to eq 'A1 .B2 BOO ...'
          expect(described_class.new('A1 .B2 BOO .C3 BOO ...').lopped).to eq 'A1 .B2 BOO .C3 BOO ...'
        end
      end

      context 'when a serial' do
        it 'leaves cutters in tact' do
          expect(described_class.new('P123.23 .M23 A12', serial: true).lopped).to eq 'P123.23 .M23 A12'
        end

        it 'drops data after the first volume designation' do
          expect(described_class.new('PN2007 .S589 NO.17 1998', serial: true).lopped).to eq 'PN2007 .S589'
          expect(described_class.new('PN2007 .K3 V.7:NO.4', serial: true).lopped).to eq 'PN2007 .K3'
          expect(described_class.new('PN2007 .K3 V.8:NO.1-2 1972', serial: true).lopped).to eq 'PN2007 .K3'
          expect(described_class.new('PN2007 .K3 V.5-6:NO.11-25 1967-1970', serial: true).lopped).to eq 'PN2007 .K3'
          expect(described_class.new('PN2007 .S3 NO.14-15,34', serial: true).lopped).to eq 'PN2007 .S3'
        end

        it 'drops year data after the cutter' do
          expect(described_class.new('PN2007 .S3 1987', serial: true).lopped).to eq 'PN2007 .S3'
          expect(described_class.new('PN2007 .K93 2002/2003:NO.3/1', serial: true).lopped).to eq 'PN2007 .K93'
          expect(described_class.new('PN2007 .Z37 1993:JAN.-DEC', serial: true).lopped).to eq 'PN2007 .Z37'
          expect(described_class.new('PN2007 .Z37 1994:SEP-1995:JUN', serial: true).lopped).to eq 'PN2007 .Z37'
          expect(described_class.new('PN2007 .K93 2002:NO.1-2', serial: true).lopped).to eq 'PN2007 .K93'
        end
      end
    end
  end
end
