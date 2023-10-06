# frozen_string_literal: true

require 'spec_helper'
require 'folio/holdings'

RSpec.describe Folio::Holdings do
  describe '.find_latest' do
    subject(:latest) { described_class.find_latest(options) }
    let(:options) { [{}, {}] }

    context 'when chronology has a YYYY' do
      let(:target) { { 'chronology' => '2025' } }
      let(:options) { [{ 'chronology' => '2020' }, target, { 'chronology' => '1999' }] }

      it 'selects the target' do
        expect(latest).to include(target)
      end
    end

    context 'when chronology has a MON YYYY' do
      let(:target) { { 'chronology' => 'Oct 2025' } }
      let(:options) { [{ 'chronology' => 'Feb 2025' }, target, { 'chronology' => 'Jan 1999' }] }

      it 'selects the target' do
        expect(latest).to include(target)
      end
    end

    context 'when chronology has a YYYY/YYYY' do
      let(:target) { { 'chronology' => '2020/2021' } }
      let(:options) { [{ 'chronology' => '2016/2017' }, target, { 'chronology' => '2018/2019' }] }

      it 'selects the target' do
        expect(latest).to include(target)
      end
    end

    context 'when using enumeration as a tie breaker' do
      let(:target) { { 'chronology' => '2025', 'enumeration' => 'Episode 8' } }
      let(:options) { [{ 'chronology' => '2025', 'enumeration' => 'Episode 7' }, target, { 'chronology' => '2025', 'enumeration' => 'Episode 2' }] }

      it 'selects the target' do
        expect(latest).to include(target)
      end
    end

    context 'when chronology is an empty string' do
      let(:target) { { 'chronology' => '', 'enumeration' => 'Episode 8' } }
      let(:options) { [{ 'chronology' => '', 'enumeration' => 'Episode 7' }, target, { 'chronology' => '', 'enumeration' => 'Episode 2' }] }

      it 'selects the target' do
        expect(latest).to include(target)
      end
    end

    context 'when comparing chronology with a date to one that is an empty string' do
      let(:target) { { 'chronology' => '2003', 'enumeration' => '' } }
      let(:options) { [{ 'chronology' => '', 'enumeration' => '' }, target, { 'chronology' => '', 'enumeration' => '' }] }

      it 'selects the target' do
        expect(latest).to include(target)
      end
    end

    # Multiple dates in chronology field
    context 'when chronology has a MON YYYY/YYYY pattern' do
      let(:target) { { 'chronology' => 'Sep 2020/2021' } }
      let(:options) { [{ 'chronology' => 'Dec 2016/2017' }, target, { 'chronology' => 'Feb 2018/2019' }] }

      it 'selects the target by correctly parsing mon yyyy/yyyy' do
        expect(latest).to include(target)
      end
    end

    context 'when chronology has a MON/MON YYYY pattern' do
      let(:target) { { 'chronology' => 'Aug/Sep 2021' } }
      let(:options) { [{ 'chronology' => 'Nov/Dec 2017' }, target, { 'chronology' => 'Feb/Mar 2019' }] }

      it 'selects the target by correctly parsing mon/mon yyyy' do
        expect(latest).to include(target)
      end
    end

    context 'when chronology has a MON/MON YYYY/YYYY pattern' do
      let(:target) { { 'chronology' => 'Aug/Sep 2021/2022' } }
      let(:options) { [{ 'chronology' => 'Nov/Dec 2017/2018' }, target, { 'chronology' => 'Feb/Mar 2018/2019' }] }

      it 'selects the target by correctly parsing mon/mon yyyy/yyyy' do
        expect(latest).to include(target)
      end
    end

    context 'when chronology has a mon dd/dd YYYY pattern' do
      let(:target) { { 'chronology' => 'Aug 20/25 2022' } }
      let(:options) { [{ 'chronology' => 'Aug 10/11 2022' }, target, { 'chronology' => 'Feb 2/3 2022' }] }

      it 'selects the target by correctly parsing mon/mon yyyy/yyyy' do
        expect(latest).to include(target)
      end
    end

    context 'when enumeration has multiple integers' do
      let(:target) { { 'chronology' => '', 'enumeration' => 'bd.54 t.2' } }
      let(:options) { [{ 'chronology' => '', 'enumeration' => 'bd.54 t.1' }, target, { 'chronology' => '', 'enumeration' => 'bd.53 t.1' }] }

      it 'selects the target' do
        expect(latest).to include(target)
      end
    end

    context 'when enumeration is text' do
      let(:target) { { 'chronology' => '', 'enumeration' => 'ccc' } }
      let(:options) { [{ 'chronology' => '', 'enumeration' => 'bbb' }, target, { 'chronology' => '', 'enumeration' => 'aaa' }] }

      it 'selects the target' do
        expect(latest).to include(target)
      end
    end

    context 'when enumeration is mixed' do
      let(:target) { { 'chronology' => '', 'enumeration' => '52' } }
      let(:options) { [{ 'chronology' => '', 'enumeration' => 'bbb' }, target, { 'chronology' => '', 'enumeration' => 'aaa' }] }

      it 'selects the target' do
        expect(latest).to include(target)
      end
    end
  end
end
