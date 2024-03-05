# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CallNumbers::LcShelfkey do
  describe 'sorting by generated key' do
    it 'sorts classifications properly' do
      call_number_strings = [
        'A1 .M32 2002', 'A12 .M32 2002', 'A123 .M32 2002',
        'AB123 .M32 2002', 'ABC123 .M32 2002', 'A1.1 .M32 2002',
        'A1.12 .M32 2002', 'A1.123 .M32 2002'
      ].shuffle

      sorted_call_numbers = call_number_strings.map { |x| described_class.new(x) }.sort_by(&:forward).map(&:base_call_number)

      expect(sorted_call_numbers).to eq(
        [
          'A1 .M32 2002',
          'A1.1 .M32 2002',
          'A1.12 .M32 2002',
          'A1.123 .M32 2002',
          'A12 .M32 2002',
          'A123 .M32 2002',
          'AB123 .M32 2002',
          'ABC123 .M32 2002'
        ]
      )
    end

    it 'sorts cutters properly' do
      call_number_strings = [
        'A123 .M3 2002', 'A123 .M321 2002',
        'A123 .MS32 2002', 'A123 .MSA32 2002',
        'A123 .MS32AB 2002', 'A123 .MS32A 2002', 'A123 .MS32ABA 2002'
      ].shuffle

      sorted_call_numbers = call_number_strings.map { |x| described_class.new(x) }.sort_by(&:forward).map(&:base_call_number)

      expect(sorted_call_numbers).to eq(
        [
          'A123 .M3 2002',
          'A123 .M321 2002',
          'A123 .MS32 2002',
          'A123 .MS32A 2002',
          'A123 .MS32AB 2002',
          'A123 .MS32ABA 2002',
          'A123 .MSA32 2002'
        ]
      )
    end
  end
end
