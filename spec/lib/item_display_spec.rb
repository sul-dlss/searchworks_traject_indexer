# frozen_string_literal: true

require 'sirsi_holding'
require 'item_display'
require 'call_numbers/shelfkey'

RSpec.describe ItemDisplay do
  subject(:item_display) { described_class.new(record, holding, context) }

  let(:record) { nil }
  let(:holding) { nil }
  let(:context) { nil }

  describe '#call_number' do
    context 'holding call number is not ignored and holding is not shelved by location' do
      let(:holding) do
        instance_double(SirsiHolding,
                        ignored_call_number?: false,
                        shelved_by_location?: false,
                        e_call_number?: false,
                        call_number: 'E184.S75 R47A')
      end

      before do
        allow(item_display).to receive(:call_number_object).and_return(double)
      end

      it 'returns the holding call number' do
        expect(item_display.call_number).to eq 'E184.S75 R47A'
      end
    end

    context 'holding call number is not ignored and holding is shelved by location' do
      let(:holding) do
        instance_double(SirsiHolding,
                        ignored_call_number?: false,
                        shelved_by_location?: true,
                        e_call_number?: false,
                        home_location: 'LOCATION',
                        current_location: 'LOCATION',
                        call_number: 'E184.S75 R47A Vol. 1')
      end

      before do
        allow(item_display).to receive(:call_number_object).and_return(double(lopped: 'E184.S75 R47A'))
      end

      it 'returns the lopped call number with enumeration' do
        expect(item_display.call_number).to eq 'Shelved by title Vol. 1'
      end
    end

    context 'holding is an electronic callnumber' do
      let(:holding) do
        instance_double(SirsiHolding,
                        ignored_call_number?: false,
                        shelved_by_location?: false,
                        e_call_number?: true,
                        call_number: 'E184.S75 R47A')
      end

      before do
        allow(item_display).to receive(:call_number_object).and_return(double)
      end

      it 'returns the holding call number' do
        expect(item_display.call_number).to eq 'E184.S75 R47A'
      end
    end

    context 'none of the conditions are met' do
      let(:holding) do
        instance_double(SirsiHolding,
                        ignored_call_number?: true,
                        shelved_by_location?: false,
                        e_call_number?: false,
                        call_number: 'E184.S75 R47A')
      end

      before do
        allow(item_display).to receive(:call_number_object).and_return(double)
      end

      it 'returns nil' do
        expect(item_display.call_number).to be nil
      end
    end
  end

  describe '#lopped_call_number' do
    context 'holding is ignored and not shelved by location/title' do
      let(:holding) do
        instance_double(SirsiHolding,
                        ignored_call_number?: true,
                        shelved_by_location?: false)
      end

      it 'returns nil' do
        expect(item_display.lopped_call_number).to be nil
      end
    end

    context 'holding is shelved by series title' do
      let(:holding) do
        instance_double(SirsiHolding,
                        ignored_call_number?: false,
                        shelved_by_location?: true,
                        home_location: 'SHELBYSER',
                        current_location: 'SHELBYSER')
      end

      before do
        allow(item_display).to receive(:call_number_object).and_return(double)
      end

      it 'returns a case specific value' do
        expect(item_display.lopped_call_number).to eq 'Shelved by Series title'
      end
    end

    context 'holding is shelved by title/location' do
      let(:holding) do
        instance_double(SirsiHolding,
                        ignored_call_number?: false,
                        shelved_by_location?: true,
                        home_location: 'LOCATION',
                        current_location: 'LOCATION')
      end

      before do
        allow(item_display).to receive(:call_number_object).and_return(double)
      end

      it 'returns a case specific value' do
        expect(item_display.lopped_call_number).to eq 'Shelved by title'
      end
    end

    context 'the holding is the only item in the location' do
      let(:holding) do
        instance_double(SirsiHolding,
                        lost_or_missing?: false,
                        ignored_call_number?: false,
                        shelved_by_location?: false,
                        home_location: 'POPSCI',
                        library: 'SCIENCE',
                        call_number_type: 'LC')
      end
      let(:context) do
        double(
          clipboard: {
            non_skipped_or_ignored_holdings_by_library_location_call_number_type:
              { ['SCIENCE', 'Popular Science', 'LC'] => ['holding'] }
          }
        )
      end

      before do
        allow(item_display).to receive(:call_number_object).and_return(
          double(call_number: 'E184.S75 R47A')
        )
      end

      it 'returns the lopped call number of the call_number_object' do
        expect(item_display.lopped_call_number).to eq 'E184.S75 R47A'
      end
    end

    context 'the holding has multiple items in the same location' do
      let(:holding) do
        instance_double(SirsiHolding,
                        lost_or_missing?: false,
                        ignored_call_number?: false,
                        shelved_by_location?: false,
                        home_location: 'POPSCI',
                        library: 'SCIENCE',
                        call_number_type: 'LC',
                        call_number: 'E184.S75 R47A Vol. 1')
      end
      let(:context) do
        double(
          clipboard: {
            non_skipped_or_ignored_holdings_by_library_location_call_number_type:
              { ['SCIENCE', 'Popular Science', 'LC'] => %w[holding holding] }
          }
        )
      end

      before do
        allow(item_display).to receive(:call_number_object).and_return(
          double(lopped: 'E184.S75 R47A')
        )
      end
      it 'returns the lopped call number of the call number object with ellipses' do
        expect(item_display.lopped_call_number).to eq 'E184.S75 R47A ...'
      end
    end

    xcontext 'none of the other conditions are met' do
      it '' do
        expect(item_display.lopped_call_number).to eq ''
      end
    end
  end

  describe '#shelfkey' do
    context 'holding is lost or missing' do
      let(:holding) do
        instance_double(SirsiHolding,
                        lost_or_missing?: true)
      end

      it 'returns nil' do
        expect(item_display.shelfkey).to be nil
      end
    end

    context 'holding is shelved by location/title' do
      let(:holding) do
        instance_double(SirsiHolding,
                        lost_or_missing?: false,
                        ignored_call_number?: false,
                        shelved_by_location?: true,
                        home_location: 'LOCATION',
                        current_location: 'LOCATION')
      end

      before do
        allow(item_display).to receive(:call_number_object).and_return(double)
      end

      it 'returns a downcased lopped call number' do
        expect(item_display.shelfkey).to eq 'shelved by title'
      end
    end

    context 'the holding is the only item in the location' do
      let(:holding) do
        instance_double(SirsiHolding,
                        lost_or_missing?: false,
                        ignored_call_number?: false,
                        shelved_by_location?: false,
                        home_location: 'POPSCI',
                        library: 'SCIENCE',
                        call_number_type: 'LC')
      end
      let(:context) do
        double(
          clipboard: {
            non_skipped_or_ignored_holdings_by_library_location_call_number_type:
              { ['SCIENCE', 'Popular Science', 'LC'] => ['holding'] }
          }
        )
      end

      before do
        allow(item_display).to receive(:call_number_object).and_return(
          double(to_shelfkey: 'lc e   0184.000000 s0.750000 r0.470000a')
        )
      end

      it 'returns the shelfkey of the call_number_object' do
        expect(item_display.shelfkey).to eq 'lc e   0184.000000 s0.750000 r0.470000a'
      end
    end

    context 'the holding has multiple items in the same location' do
      let(:holding) do
        instance_double(SirsiHolding,
                        lost_or_missing?: false,
                        ignored_call_number?: false,
                        shelved_by_location?: false,
                        home_location: 'POPSCI',
                        library: 'SCIENCE',
                        call_number_type: 'LC',
                        call_number: 'E184.S75 R47A')
      end
      let(:context) do
        double(
          clipboard: {
            non_skipped_or_ignored_holdings_by_library_location_call_number_type:
              { ['SCIENCE', 'Popular Science', 'LC'] => %w[holding holding] }
          }
        )
      end

      before do
        allow(item_display).to receive(:call_number_object).and_return(
          double(to_lopped_shelfkey: 'lc e   0184.000000 s0.750000',
                 lopped: 'E184.S75')
        )
      end

      it 'returns the lopped shelfkey of the call_number_object with ellipses' do
        expect(item_display.shelfkey).to eq 'lc e   0184.000000 s0.750000 ...'
      end
    end
  end

  describe '#reverse_shelfkey' do
    context 'holding is lost or missing' do
      let(:holding) do
        instance_double(SirsiHolding,
                        lost_or_missing?: true)
      end

      it 'returns nil' do
        expect(item_display.reverse_shelfkey).to be nil
      end
    end

    context 'there is a shelfkey present' do
      let(:holding) do
        instance_double(SirsiHolding,
                        ignored_call_number?: false,
                        lost_or_missing?: false,
                        shelved_by_location?: true,
                        home_location: 'LOCATION',
                        current_location: 'LOCATION')
      end

      before do
        allow(item_display).to receive(:call_number_object).and_return(double)
      end

      it 'returns the reversed shelfkey' do
        expect(item_display.reverse_shelfkey).to eq '7ile4lm~o1~6h6el~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
      end
    end
  end

  describe '#volume_sort' do
    context 'call number is ignored and holding is not shelved by location/title' do
      let(:holding) do
        instance_double(SirsiHolding,
                        ignored_call_number?: true,
                        shelved_by_location?: false)
      end

      it 'returns nil' do
        expect(item_display.volume_sort).to be nil
      end
    end

    context 'holding is shelved by location/title' do
      let(:holding) do
        instance_double(SirsiHolding,
                        ignored_call_number?: false,
                        shelved_by_location?: true,
                        home_location: 'LOCATION',
                        current_location: 'LOCATION',
                        call_number: 'PS3537.A832.Z85')
      end

      before do
        allow(item_display).to receive(:call_number_object).and_return(double(lopped: 'PS3537.A832.Z85'))
      end

      it 'returns a value suitable for a shelved by location/title holdings' do
        expect(item_display.volume_sort).to eq(
          'shelved by title ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
        )
      end
    end

    context 'there are one or more items in the same location' do
      let(:holding) do
        instance_double(SirsiHolding,
                        ignored_call_number?: false,
                        shelved_by_location?: false,
                        home_location: 'POPSCI',
                        library: 'SCIENCE',
                        call_number_type: 'LC')
      end
      let(:context) do
        double(
          clipboard: {
            non_skipped_or_ignored_holdings_by_library_location_call_number_type:
              { ['SCIENCE', 'Popular Science', 'LC'] => ['holding'] }
          }
        )
      end

      before do
        allow(item_display).to receive(:call_number_object).and_return(
          double(to_volume_sort: 'lc pr  3724.000000 t0.300000')
        )
      end

      it 'returns a value if there are one or more items in the same location' do
        expect(item_display.volume_sort).to eq 'lc pr  3724.000000 t0.300000'
      end
    end

    context 'the conditions are not met' do
      let(:holding) do
        instance_double(SirsiHolding,
                        ignored_call_number?: false,
                        shelved_by_location?: false,
                        home_location: 'POPSCI',
                        library: 'SCIENCE',
                        call_number_type: 'LC')
      end
      let(:context) do
        double(
          clipboard: {
            non_skipped_or_ignored_holdings_by_library_location_call_number_type: {}
          }
        )
      end

      before do
        allow(item_display).to receive(:call_number_object).and_return(nil)
      end

      it 'returns nil' do
        expect(item_display.volume_sort).to be nil
      end
    end
  end

  describe '#scheme' do
    it 'returns an uppercase version of the scheme if call_number_object is present' do
      allow(item_display).to receive(:call_number_object).and_return(double(scheme: 'lc'))
      expect(item_display.scheme).to eq 'LC'
    end

    it 'returns nil if the call_number_object is not present' do
      allow(item_display).to receive(:call_number_object).and_return(nil)
      expect(item_display.scheme).to be nil
    end
  end
end
