# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CallNumbers::Shelfkey do
  describe 'class methods' do
    describe '#pad_cutter' do
      it 'handles normal cutters' do
        expect(described_class.pad_cutter('.M32')).to eq 'm0.320000'
        expect(described_class.pad_cutter('M32')).to eq 'm0.320000'
      end

      it 'padds the letter of the cutter up to two spaces' do
        expect(described_class.pad_cutter('.M32')).to eq 'm0.320000'
        expect(described_class.pad_cutter('.MS32')).to eq 'ms.320000'
        expect(described_class.pad_cutter('.MSA32')).to eq 'msa.320000'
      end

      it 'rounds cutter digits' do
        expect(described_class.pad_cutter('.M32897389')).to eq 'm0.328974'
      end
    end
  end
end
