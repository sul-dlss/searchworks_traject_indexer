# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CallNumbers::CaldocShelfkey do
  describe 'sorting by generated key' do
    it 'sorts CalDoc call numbers with volume info' do
      call_numbers_data = [
        { base: 'CALIF E200 .E9', volume_info: 'Region 2' },
        { base: 'CALIF E200 .E9', volume_info: 'Region III' },
        { base: 'CALIF E200 .E9', volume_info: 'Region iv' },
        { base: 'CALIF E200 .E9', volume_info: 'Region 7' },
        { base: 'CALIF G105 .B9', volume_info: '' },
        { base: 'CALIF G105 .B9', volume_info: '1965' },
        { base: 'CALIF G105 .B9', volume_info: '1966-1967' },
        { base: 'CALIF G105 .B9', volume_info: '1968-1973' }
      ]

      unsorted_data = call_numbers_data.shuffle

      sorted_call_numbers = unsorted_data
                            .map { |data| described_class.new(data[:base], data[:volume_info], serial: data[:serial]) }
                            .sort_by(&:forward)
                            .map { |obj| { base: obj.base_call_number, volume_info: obj.volume_info } }
      expect(sorted_call_numbers).to eq(call_numbers_data)

      reversed_call_numbers = unsorted_data
                              .map { |data| described_class.new(data[:base], data[:volume_info], serial: data[:serial]) }
                              .sort_by(&:reverse)
                              .map { |obj| { base: obj.base_call_number, volume_info: obj.volume_info } }
      expect(reversed_call_numbers).to eq(call_numbers_data.reverse)
    end

    it 'sorts CalDoc base call numbers' do
      call_numbers = [
        # These fixtures are from real Folio data (maybe with a tweak).
        'CALIF H990 .W68 1985/86',
        # Sometimes the year is included in the base call number, sometimes it's in the volume info
        # Sometimes there is a range ending in a two digit year
        'CALIF H997 .C62 1983-84',
        # Sometimes a four digit year
        'CALIF H997 .C62 1983-1986',
        'CALIF H997 .C62 1983-90',
        'CALIF I250 .R4m',
        'CALIF I250 .R4s',
        'CALIF I625   .R4L',
        'CALIF I625 .R4Lc',
        # Might not exist in real data but Librarians warned us about leading garbage
        '[folio] CALIF I625 .R4v',
        'CALIF I625 .R42',
        'CALIF I625 .R63 2000',
        'CALIF I625 .R63 2002',
        'CALIF I625.R63 2004',
        # Sometimes there's a number in the base call number. Most of the time it's in the volume info
        'CALIF L500.P685 1990 NO.1',
        'CALIF L500 .P685 1990 NO.2',
        'CALIF L500.P685 1990 NO.12',
        'CALIF P2200 .M5DC',
        'CALIF P2200 .M59',
        # These "DRAFT" types properties seem to normally be in the volume info
        'CALIF R960 .C42 DRAFT',
        'CALIF R960 .C42 FINAL',
        'CALIF R960 .E76',
        # Note that we have "work letters" that are more than one character
        'CALIF R960 .M36DR CD',
        'CALIF R960 .P6S',
        'CALIF S930 .L4A NO.01',
        'CALIF S930 .L4A NO. 02',
        'CALIF S930 .L4A NO.48',
        'CALIF S930 .L4A NO.48 AMEND.'
      ]
      unsorted_call_numbers = call_numbers.shuffle
      sorted_call_numbers = unsorted_call_numbers.map { |x| described_class.new(x) }
                                                 .sort_by(&:forward)
                                                 .map(&:base_call_number)

      expect(sorted_call_numbers).to eq(call_numbers)

      reversed_call_numbers = unsorted_call_numbers.map { |x| described_class.new(x) }
                                                   .sort_by(&:reverse)
                                                   .map(&:base_call_number)
      expect(reversed_call_numbers).to eq(call_numbers.reverse)
    end
  end
end
