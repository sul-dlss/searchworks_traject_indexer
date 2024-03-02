# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Utils do
  describe '.balance_parentheses' do
    it 'works' do
      expect(described_class.balance_parentheses('abc')).to eq 'abc'
      expect(described_class.balance_parentheses('a(bc')).to eq 'abc'
      expect(described_class.balance_parentheses('a(b)c')).to eq 'a(b)c'
      expect(described_class.balance_parentheses('abc)')).to eq 'abc'
      expect(described_class.balance_parentheses('(a(bc))')).to eq '(a(bc))'
    end
  end

  describe '.longest_common_call_number_prefix' do
    it 'works' do
      expect(described_class.longest_common_call_number_prefix('interspecies', 'interstellar', 'interstate')).to eq 'inters'
      expect(described_class.longest_common_call_number_prefix('throne', 'throne')).to eq 'throne'
      expect(described_class.longest_common_call_number_prefix('throne', 'dungeon')).to eq ''
      expect(described_class.longest_common_call_number_prefix('throne', '', 'throne')).to eq ''
      expect(described_class.longest_common_call_number_prefix('cheese')).to eq 'cheese'
      expect(described_class.longest_common_call_number_prefix('')).to eq ''
      expect(described_class.longest_common_call_number_prefix).to eq ''
      expect(described_class.longest_common_call_number_prefix('prefix', 'suffix')).to eq ''
      expect(described_class.longest_common_call_number_prefix('foo', 'foobar')).to eq 'foo'
    end

    it 'returns the prefix before whitespace or punctuation' do
      expect(described_class.longest_common_call_number_prefix('HE 20.3002:D 56 /V.3/PT.1', 'HE 20.3002:D 56 /V.1/PT.3')).to eq 'HE 20.3002:D 56'
      expect(described_class.longest_common_call_number_prefix('S 1.1:873/V.1', 'S 1.1:917/SUPPL.2/V.2')).to eq 'S 1.1'
    end
  end
end
