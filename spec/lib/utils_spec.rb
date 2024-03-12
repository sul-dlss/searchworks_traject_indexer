# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Utils do
  describe '.encoding_cleanup' do
    it 'encodes cyrilic correctly' do
      expect(described_class.encoding_cleanup('Strategii︠a︡ planirovanii︠a︡ izbiratelʹnoĭ kampanii')).to eq('Strategii͡a planirovanii͡a izbiratelʹnoĭ kampanii')
    end

    it 'returns unencoded string without change' do
      expect(described_class.encoding_cleanup('https://link.gale.com/apps/ECCO?u=stan90222')).to eq('https://link.gale.com/apps/ECCO?u=stan90222')
    end

    it 'returns encoded string without change' do
      expect(described_class.encoding_cleanup('Strategiii︠a planirovaniia︡ izbiratelʹnoĭ kampanii')).to eq('Strategiii︠a planirovaniia︡ izbiratelʹnoĭ kampanii')
    end
  end

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
      expect(described_class.longest_common_call_number_prefix('throne', 'dungeon')).to eq ''
      expect(described_class.longest_common_call_number_prefix('throne', '', 'throne')).to eq ''
      expect(described_class.longest_common_call_number_prefix('')).to eq ''
      expect(described_class.longest_common_call_number_prefix).to eq ''
      expect(described_class.longest_common_call_number_prefix('prefix', 'suffix')).to eq ''
      expect(described_class.longest_common_call_number_prefix('foo', 'foobar')).to eq 'foo'
    end

    it 'returns the prefix before whitespace or punctuation' do
      expect(described_class.longest_common_call_number_prefix('HE 20.3002:D 56 /V.3/PT.1', 'HE 20.3002:D 56 /V.1/PT.3')).to eq 'HE 20.3002:D 56'
      expect(described_class.longest_common_call_number_prefix('S 1.1:873/V.1', 'S 1.1:917/SUPPL.2/V.2')).to eq 'S 1.1'
    end

    it 'returns an empty string if there is only one' do
      expect(described_class.longest_common_call_number_prefix('HE 20.3002:D 56 /V.3/PT.1')).to eq ''
    end

    it 'returns an empty string if the values are all the same' do
      expect(described_class.longest_common_call_number_prefix('HE 20.3002:D 56 /V.3/PT.1', 'HE 20.3002:D 56 /V.3/PT.1')).to eq ''
    end
  end
end
