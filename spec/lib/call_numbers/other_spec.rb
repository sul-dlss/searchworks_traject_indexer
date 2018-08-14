require 'call_numbers/other'

describe CallNumbers::Other do
  describe '#to_shelfkey' do
    let(:shelfkey) { described_class.new('ZDVD 1234').to_shelfkey }

    it 'Normalizes the call nubmer into a shelfey' do
      expect(shelfkey).to start_with('other')
      expect(shelfkey).to include('zdvd')
      expect(shelfkey).to end_with('001234')
    end
  end

  describe '#to_reverse_shelfkey' do
    let(:reverse_shelfkey) { described_class.new('ZDVD 1234').to_reverse_shelfkey }

    it 'uses CallNumbers::Shelfkey.reverse to reverse' do
      expect(reverse_shelfkey).to start_with('b6il8')
      expect(reverse_shelfkey).to include('0m4m')
      expect(reverse_shelfkey).to include('zzyxwv')
      expect(reverse_shelfkey).to end_with('~~~')
    end
  end

  describe '#scheme' do
    it 'is "sudoc" when "SUDOC" is passed' do
      expect(described_class.new('ZDVD 1234', scheme: 'SUDOC').scheme).to eq 'sudoc'
    end

    it 'is "other" for any other value or nil' do
      expect(described_class.new('ZDVD 1234', scheme: 'LITERALLY ANYTHING ELSE').scheme).to eq 'other'
      expect(described_class.new('ZDVD 1234').scheme).to eq 'other'
    end
  end
end
