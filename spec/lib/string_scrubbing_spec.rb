require 'spec_helper'
require 'utils'

describe StringScrubbing do
  describe '.balance_parentheses' do
    it 'works' do
      expect(StringScrubbing.balance_parentheses('abc')).to eq 'abc'
      expect(StringScrubbing.balance_parentheses('a(bc')).to eq 'abc'
      expect(StringScrubbing.balance_parentheses('a(b)c')).to eq 'a(b)c'
      expect(StringScrubbing.balance_parentheses('abc)')).to eq 'abc'
      expect(StringScrubbing.balance_parentheses('(a(bc))')).to eq '(a(bc))'
    end
  end
end
