# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CallNumbers::SudocShelfkey do
  describe 'sorting by generated key' do
    it 'handles whitespace variations properly' do
      call_numbers = [
        'Y4.ED 8/1:117-48',
        'Y 4.ED 8/1:117-49',
        'Y 4.ED8/1:117-50',
        'Y4.ED8/1:117-53'
      ]

      unsorted_call_numbers = call_numbers.shuffle
      sorted_call_numbers = unsorted_call_numbers.map { |x| described_class.new(x) }
                                                 .sort_by(&:forward)
                                                 .map(&:base_call_number)

      expect(sorted_call_numbers).to eq(call_numbers)
    end

    it 'is case insensitive' do
      call_numbers = [
        'Y4.ED 8/1:117-48',
        'y4.ED 8/1:117-49',
        'Y 4.ed8/1:117-50'
      ]

      unsorted_call_numbers = call_numbers.reverse
      sorted_call_numbers = unsorted_call_numbers.map { |x| described_class.new(x) }
                                                 .sort_by(&:forward)
                                                 .map(&:base_call_number)

      expect(sorted_call_numbers).to eq(call_numbers)
    end

    it 'handles three digit years' do
      call_numbers = [
        'I 29.21:M 75/2/1996',
        'I 29.21:M 75/2/998',
        'I 29.21:M 75/2/2019',
        'I 29.21:M 75/2/2021',
        'I 29.21:M 75/2/10',
        'Y 4.F 76/2:S.HRG.115-747',
        'Y 4.F 76/2:S.HRG.115-830',
        'Y 4.F 76/2:S.HRG.115-831',
        'Y 4.F 76/2:S.HRG.116-105'
      ]
      unsorted_call_numbers = call_numbers.shuffle
      sorted_call_numbers = unsorted_call_numbers.map { |x| described_class.new(x) }
                                                 .sort_by(&:forward)
                                                 .map(&:base_call_number)

      expect(sorted_call_numbers).to eq(call_numbers)
    end

    it 'considers periods in the suffix a significant delimiter only when involving numbers' do
      call_numbers = [
        'SSA 1.2:AG 8/SWEDEN',
        'SSA 1.2:AG 8/SWITZ.',
        'SSA 1.2:AG 8/SWITZ/996',
        'SSA 1.2:AG 8/SWITZ./997',
        'SSA 1.2:AG 8/U.K./996',
        'SSA 1.2:AG 8/UK/997',
        'SSA 1.2:AG 8/U.K./998',
        'SSA 1.2:AG 8/USA',
        'SSA 1.2:AG 8/USA/VERISON 1.2',
        'SSA 1.2:AG 8/USA/VERISON 1.3',
        'SSA 1.2:AG 8/USA/VERISON 12',
        'SSA 1.2:AG 8/USA/VERISON 12 No. 1',
        'SSA 1.2:AG 8/USA/VERISON 12 No.2',
        'SSA 1.2:AG 8/USA/VERISON 12 No 2.1',
        'SSA 1.2:AG 8/USA/VERISON 12 No. 3'
      ]
      unsorted_call_numbers = call_numbers.shuffle
      sorted_call_numbers = unsorted_call_numbers.map { |x| described_class.new(x) }
                                                 .sort_by(&:forward)
                                                 .map(&:base_call_number)
      expect(sorted_call_numbers).to eq(call_numbers)
    end

    it 'sorts this list of sudoc call numbers' do
      call_numbers = [
        'A 13.2:T 73/4',
        'A 93.2:N 95/3',
        'A 93.73:76',
        'A 93.73:89',
        'A 93.73/2:62',
        'C 13.58:7564',
        'C 13.58:7611',
        'EP 1.23:600/998-103',
        'EP 1.23:600/R-98-23',
        'HE 20.4002:AD 9/2',
        'HE 20.4002:AD9/5',
        'HE 20.4002:F 94',
        'I 29.2:W 58/12/2022/FALL',
        'I 29.2:W 58/12/2022/SPRING',
        'I 53.11/4:36121-E 1-TM-100/2022',
        'I 53.11/4:38102-E 1-TM-100/2022',
        'I 53.11/4:39102-A 1-TM-100/2022',
        'I 53.11/4:39108-A 1-TM-100/2020',
        'I 53.11/4:39108-A 1-TM-100/2021',
        'I 53.11/4:39121-A 1-TM-100/2021',
        'I 53.11/4:42112-A 1-TM-100/2022',
        'I 53.59:P 87/2/FINAL/V.1',
        'I 53.59:P 87/2/FINAL/V.1 3-4',
        'I 53.59:P 87/2/FINAL/V.1 5-7',
        'I 53.59:P 87/2/FINAL/V.2',
        'I 53.59:P 87/2/FINAL/V.10',
        'ITC 1.12:731-TA-1054-1055/FINAL',
        'ITC 1.12:731-TA-1054-1055/PRELIM.',
        'J 32.2:C 43/CHILD',
        'J 32.2:C 43/EARLY',
        'J 32.21:999',
        'J 32.21:M',
        'NAS 1.83:NP-2019-06-2726-HQ',
        'NAS 1.83:NP-2019-07-2735-HQ',
        'NAS 1.83:NP-2019-07-2739-HQ',
        'PM 1.10:RI 83-3/989',
        'PM 1.10:RI 83-4/989-2',
        'PM 1.10:RI 83-4/989-12',
        'PM 1.10:RI 83-4/995',
        'PM 1.10:RI 83-5/989-2',
        'PREX 3.10/4-5:POLIT.',
        'PREX 3.10/4-5:RELIEF',
        'PREX 3.10/4-8:',
        'PREX 28.2:H 34',
        'Y 1.1/7:110-27',
        'Y 1.1/8:110-934',
        'Y 3.L 71:2 C 43/BIRTH',
        'Y 3.L 71:2 C 43/BIRTH/2003',
        'Y 3.L 71:2 C 43/KINDER.',
        'Y 3.L 71:2 C 43/KINDER./2003',
        'Y 3.N 88:10/0586/SUPP.1/VOL .1/FINAL',
        'Y 3.N 88:10/0586/SUPP.1/VOL .2/FINAL',
        'Y 4.AG 8:S.HRG.110-403',
        'Y 4.AG 8:S.HRG.110-404',
        'Y 4.AP 6/1:AP 6/10/2018/BK .1',
        'Y 4.AP 6/1:AP 6/10/2018/BK .2',
        'Y 4.C 73/8:115-11',
        'Y 4.C 73/8:115-110',
        'Y 4.C 73/8:115-116+ERRATA',
        'Y 4.C 73/8:115-117',
        'Y 4.J 89/2:S.HRG.108-257',
        'Y 4.J 89/2:S.HRG.108-257/ERRATA',
        'Y 4.W 36:WMCP 108-2',
        'Y 4.W 36:WMCP 108-12',
        'Y 4.W 36:115-TR 01',
        'Y 4.W 36:115-TR 02'
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
