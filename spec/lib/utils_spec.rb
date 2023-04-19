# frozen_string_literal: true

require 'spec_helper'
require 'utils'

describe Utils do
  describe '.balance_parentheses' do
    it 'works' do
      expect(described_class.balance_parentheses('abc')).to eq 'abc'
      expect(described_class.balance_parentheses('a(bc')).to eq 'abc'
      expect(described_class.balance_parentheses('a(b)c')).to eq 'a(b)c'
      expect(described_class.balance_parentheses('abc)')).to eq 'abc'
      expect(described_class.balance_parentheses('(a(bc))')).to eq '(a(bc))'
    end
  end

  describe '.longest_common_prefix' do
    it 'works' do
      expect(described_class.longest_common_prefix('interspecies', 'interstellar', 'interstate')).to eq 'inters'
      expect(described_class.longest_common_prefix('throne', 'throne')).to eq 'throne'
      expect(described_class.longest_common_prefix('throne', 'dungeon')).to eq ''
      expect(described_class.longest_common_prefix('throne', '', 'throne')).to eq ''
      expect(described_class.longest_common_prefix('cheese')).to eq 'cheese'
      expect(described_class.longest_common_prefix('')).to eq ''
      expect(described_class.longest_common_prefix).to eq ''
      expect(described_class.longest_common_prefix('prefix', 'suffix')).to eq ''
      expect(described_class.longest_common_prefix('foo', 'foobar')).to eq 'foo'
    end
  end
end
