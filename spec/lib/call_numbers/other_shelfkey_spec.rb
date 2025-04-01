# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CallNumbers::OtherShelfkey do
  describe '#shelfkey' do
    before { I18n.config.available_locales = :en } # No idea why this is needed
    let(:shelfkey) { described_class.new('ZDVD 1234').forward }
    let(:reverse_shelfkey) { described_class.new('ZDVD 1234').reverse }

    it 'Normalizes the call nubmer into a shelfey' do
      expect(shelfkey).to start_with('other')
      expect(shelfkey).to include('zdvd')
      expect(shelfkey).to end_with('001234')
    end

    it 'uses CallNumbers::ShelfkeyBase.reverse to reverse' do
      expect(reverse_shelfkey).to start_with('b6il8')
      expect(reverse_shelfkey).to include('0m4m')
      expect(reverse_shelfkey).to include('zzyxwv')
      expect(reverse_shelfkey).to end_with('~~~')
    end
  end

  describe '#shelfkey_scheme' do
    it 'is "other" for any other value or nil' do
      expect(described_class.new('ZDVD 1234', scheme: 'LITERALLY ANYTHING ELSE').forward).to start_with 'other'
      expect(described_class.new('ZDVD 1234').forward).to start_with 'other'
    end
  end
end
