require 'call_numbers/dewey'

describe CallNumbers::Dewey do
  describe 'standard numbers' do
    it 'handles 1 - 3 class numbers' do
      expect(described_class.new('1.23 .M23 2002').klass_number).to eq '1'
      expect(described_class.new('11.23 .M23 2002').klass_number).to eq '11'
      expect(described_class.new('111.23 .M23 2002').klass_number).to eq '111'
    end

    it 'parses the decimal' do
      expect(described_class.new('111.23 .M23 2002').klass_decimal).to eq '.23'
      expect(described_class.new('111 .M23 2002').klass_decimal).to be_nil
    end

    describe 'doons (dates or other numbers)' do
      it 'parses a doon after the class number/decimal and before the 1st cutter' do
        expect(described_class.new('123.23 2012 .M23 2002 .M45 V.1').doon1).to match(/^2012/)
      end

      it 'parses a doon after the 1st cutter and before other cutters' do
        expect(described_class.new('123.23 2012 .M23 2002 .M45 V.1').doon2).to match(/^2002/)
      end

      it 'parses a doon after the 2nd cutter and before other cutters' do
        expect(described_class.new('436.2 .L3 .E63 1997 .E2').doon3).to match(/^1997/)
      end

      it 'allows for characters after the number in the doon (e.g. 12TH)' do
        expect(described_class.new('123.23 20TH .M45 V.1').doon1).to match(/^20TH/)
      end
    end

    describe 'cutters' do
      it 'handles 3 possible cutters' do
        expect(described_class.new('123.23 .M23 V.1 2002').cutter1).to eq '.M23'
        expect(described_class.new('123.23 .M23 V.1 2002').cutter2).to be_nil
        expect(described_class.new('123.23 .M23 V.1 2002').cutter3).to be_nil

        expect(described_class.new('123.23 .M23 .M45 V.1 2002').cutter1).to eq '.M23'
        expect(described_class.new('123.23 .M23 .M45 V.1 2002').cutter2).to eq '.M45'
        expect(described_class.new('123.23 .M23 .M45 V.1 2002').cutter3).to be_nil

        expect(described_class.new('123.23 .M23 .M45 .S32 V.1 2002').cutter1).to eq '.M23'
        expect(described_class.new('123.23 .M23 .M45 .S32 V.1 2002').cutter2).to eq '.M45'
        expect(described_class.new('123.23 .M23 .M45 .S32 V.1 2002').cutter3).to eq '.S32'
      end

      it 'handles multi-letter cutters' do
        expect(described_class.new('123.23 .MS23').cutter1).to eq '.MS23'
        expect(described_class.new('123.23 .MSA23').cutter1).to eq '.MSA23'
      end

      it 'handles a multiple letters after the cutter number' do
        expect(described_class.new('123.23 .MS23ABC').cutter1).to eq '.MS23ABC'
      end

      it 'parses cutters that do not have a space before them' do
        expect(described_class.new('123.23.M23.S32').cutter1).to eq '.M23'
        expect(described_class.new('123.23.M23.S32').cutter2).to eq '.S32'
      end

      it 'parses cutters delimited by a slash' do
        expect(described_class.new('123.23/M23/S32').cutter1).to eq '/M23'
        expect(described_class.new('123.23/M23/S32').cutter2).to eq '/S32'
      end

      it 'parses cutters with no space or period' do
        expect(described_class.new('123M23S').cutter1).to eq 'M23S'
        expect(described_class.new('123M23S32').cutter1).to eq 'M23'
        expect(described_class.new('123M23S32').cutter2).to eq 'S32'
      end
    end

    describe 'folio' do
      it 'handles folio' do
        expect(described_class.new('123M23S32 F 123').folio).to eq 'F'
      end

      it 'handles a folio at the end of the string' do
        expect(described_class.new('123M23S32 F').folio).to eq 'F'
      end

      it 'handles a flat folio at the end of the string' do
        expect(described_class.new('123M23S32 FF').folio).to eq 'FF'
      end

      it 'does nothing with tons of Fs' do
        expect(described_class.new('123M23S32 FFFFF').folio).to eq nil
      end
    end

    describe 'the rest of the stuff' do
      it 'puts any other content into the rest attribute' do
        expect(described_class.new('123.23 .M23 V.1 2002').rest).to eq 'V.1 2002'
        expect(described_class.new('123.23 2012 .M23 2002 .M45 V.1 2002-2012/GobbldyGoop').rest).to eq 'V.1 2002-2012/GobbldyGoop'
      end
    end

    describe '#lopped' do
      context 'non-serial' do
        it 'leaves cutters in tact' do
          expect(described_class.new('123.23 .M23 A12').lopped).to eq '123.23 .M23 A12'
        end

        it 'removed volume information and other data' do
          expect(described_class.new('519 .D26ST 1965 V.1 TESTS').lopped).to eq '519 .D26ST 1965'
          expect(described_class.new('519 .L18ST GRADE 1').lopped).to eq '519 .L18ST'
          expect(described_class.new('553.2805 .P117 NOV/DEC 2009').lopped).to eq '553.2805 .P117'
          expect(described_class.new('553.2805 .P117 2009:SEPT./OCT').lopped).to eq '553.2805 .P117 2009'
        end
      end

      context 'serial' do

      end
    end
  end
end
