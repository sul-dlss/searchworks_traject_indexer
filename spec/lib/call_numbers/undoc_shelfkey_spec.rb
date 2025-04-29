# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CallNumbers::UndocShelfkey do
  describe 'sorting by generated key' do
    it 'sorts UN document call numbers' do
      call_numbers = [
        'A/HRC/7/3/ADD.2',
        'A/HRC/7/28/ADD.1',
        'E/1ST YR./JOUR.1-30',
        'E/1ST YR. 1ST SESS.',
        'E/1ST YR. 2ND SESS.',
        'E/CN.12/CCE/14 3RD IN VOL',
        'E/CN.12/CCE/157',
        # Shelfkeys are built assuming that each slash delimited part is significant for that position.
        # This does mean we're depending on call number convention for things like 2006-2007 here.
        'E/ESCWA /ED/SER.Z/2/2005/2006-2007/2008',
        'E/ESCWA/ED/SER.Z/2/2009/2010',
        'E/ESCWA/EDID/2017/2',
        'E/ESCWA/EDID/2018/4',
        # There are two digit years. It is not always clear what is a two digit year and what is a sessional number.
        'HR/PUB/96/3',
        'HR/PUB/1998/1',
        'HR/PUB/98/2',
        'HR/PUB/1998/3',
        'HR/PUB/22/6',
        # ICAO commonly has its leading prefixes omitted, to the point where they don't look like UN doc call numbers.
        'ICAO DOC 8071 V.2',
        'ICAO DOC 9161',
        'LC/G.2367(SES.32/3)',
        'LC/G.2368 (SES.32/4)',
        'OEA/SER.L/V/2',
        'OEA/SER.L/V/III',
        'OEA/SER.L/V/ IV',
        'OEA/SER.L/V/5',
        'ST/ESCAP/ASIAN POP./47',
        'ST/ESCAP/ASIAN POP./131-A',
        'ST/ESCAP/ASIAN POP./131-E',
        'ST/ODA/SER.Z/1/39',
        'ST/SG/AC.10/30/REV.9',
        'ST/SG/AC.10/30/REV.10',
        'ST/SG/SER.B 1971-1973',
        'ST/SG/SER.F/BULL ./35-37/5',
        'ST/SG/SER .F/BULL./35-37/6',
        'ST/SG/SER.F/SPEC.BULL ./2001-2010',
        'ST/SG/SER.Y/10/V.1',
        'ST/SG/SER.Y/10/V.2',
        'ST/SG/SER.Y/10/V.11',
        'ST/SOA/45-51',
        'ST/SOA /47-48, ETC.',
        # Technically UNCTAD should be under TD (https://digitallibrary.un.org/record/955333?ln=en).
        # There are many possible similar situations (e.g., HR/PUB could be ST/HR/PUB prior to 1996).
        # We have been advised that in general UN documents are shelved with the call number "as written"
        'UNCTAD/ALDC/AFRICA/2023',
        'UNCTAD/DTL/TIKD/2022/1',
        # The 23 here isn't a two digit year.
        'UNEP/SER.Y/23/2015',
        'UNEP/SER.Y/44/2015',
        # The 99 is made up, using it to verify we aren't confusing it with a year (1999 < 2023)
        'UNEP/SER.Y/99/2015'
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

    it 'expands two digit years only if there is a possible sessional component and no other identifiable year' do
      expect(described_class.new('HR/PUB/98/2').forward).to eq 'undoc hr pub 001998 000002'
      expect(described_class.new('ST/SG/SER.Y/10/V.1').forward).to eq 'undoc st sg sery 000010 v000001'
      expect(described_class.new('ST/SG/SER.Y/10/V.1').forward).to eq 'undoc st sg sery 000010 v000001'
    end

    it 'converts roman numerals' do
      expect(described_class.new('OEA/SER.L/V/ III').forward).to eq 'undoc oea serl 000005 000003'
      expect(described_class.new('TD/B(S-XIX)/7').forward).to eq 'undoc td b s-000019 000007'
    end

    it 'does not covert UN document symbols that look like roman numerals' do
      expect(described_class.new('LC/G.2367(SES.32/3)').forward).to eq 'undoc lc g002367 ses000032 000003'
    end

    it 'respects scoping of slashes within parens' do
      expect(described_class.new('LC/G.2367(SES.32/3)').forward).to eq 'undoc lc g002367 ses000032 000003'
    end
  end
end
