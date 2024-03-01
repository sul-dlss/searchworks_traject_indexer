# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CallNumbers::DeweyShelfkey do
  describe 'sorting by generated key' do
    it 'sorts classifications properly' do
      call_number_strings = [
        '1 .M32 2002',
        '12 .M32 2002',
        '123 .M32 2002',
        '1.1 .M32 2002',
        '1.12 .M32 2002',
        '1.123 .M32 2002'
      ].shuffle

      sorted_call_numbers = call_number_strings.map { |x| CallNumbers::Dewey.new(x) }.sort_by { |x| x.shelfkey.forward }.map(&:call_number)

      expect(sorted_call_numbers).to eq(
        [
          '1 .M32 2002',
          '1.1 .M32 2002',
          '1.12 .M32 2002',
          '1.123 .M32 2002',
          '12 .M32 2002',
          '123 .M32 2002'
        ]
      )
    end

    it 'sorts cutters properly' do
      call_number_strings = [
        '123 .M3 2002',
        '123 .MSA32 2002',
        '123 .M321 2002',
        '123 .MS32 2002'
      ].shuffle

      sorted_call_numbers = call_number_strings.map { |x| CallNumbers::Dewey.new(x) }.sort_by { |x| x.shelfkey.forward }.map(&:call_number)

      expect(sorted_call_numbers).to eq(
        [
          '123 .M3 2002',
          '123 .M321 2002',
          '123 .MS32 2002',
          '123 .MSA32 2002'
        ]
      )
    end
  end
end
