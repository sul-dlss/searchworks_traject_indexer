require 'sirsi_holding'

RSpec.describe SirsiHolding do
  let(:field) { double('MarcField') }
  subject(:holding) { described_class.new(field) }

  describe SirsiHolding::CallNumber do
    describe '#dewey?' do
      it { expect(described_class.new('012.12 .W123')).to be_dewey }
      it { expect(described_class.new('12.12 .W123')).to be_dewey }
      it { expect(described_class.new('2.12 .W123')).to be_dewey }
      it { expect(described_class.new('PS123.34 .M123')).not_to be_dewey }
    end

    describe '#valid_lc?' do
      it { expect(described_class.new('K123.34 .M123')).to be_valid_lc }
      it { expect(described_class.new('KF123.34 .M123')).to be_valid_lc }
      it { expect(described_class.new('KFC123.34 .M123')).to be_valid_lc }
      it { expect(described_class.new('012.12 .W123')).not_to be_valid_lc }

      # will get normalized
      it { expect(described_class.new('TA1505. P76 V.4746:PT.2')).to be_valid_lc }
    end

    describe '#before_cutter' do
      it 'is correct hwen the cutter has a leading perioud' do
        expect(described_class.new('012.12 .W123').before_cutter).to eq '012.12'
        expect(described_class.new('012.12.W123').before_cutter).to eq '012.12'
      end

      it 'is correct hwen the cutter does not have a leading period' do
        expect(described_class.new('012.12 W123').before_cutter).to eq '012.12'
      end

      it 'is correct when the cutter has a leading slash' do
        expect(described_class.new('012.12/W123').before_cutter).to eq '012.12'
      end
    end

    describe '#with_leading_zeros' do
      it 'adds the correct leading zeros as needed' do
        expect(described_class.new('002.12 .W123').with_leading_zeros).to eq '002.12 .W123'
        expect(described_class.new('02.12 .W123').with_leading_zeros).to eq  '002.12 .W123'
        expect(described_class.new('2.12 .W123').with_leading_zeros).to eq   '002.12 .W123'
        expect(described_class.new('62 .B862 V.193').with_leading_zeros).to eq '062 .B862 V.193'
      end
    end
  end
end
