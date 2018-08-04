require 'sirsi_holding'

RSpec.describe SirsiHolding do
  let(:field) { double('MarcField') }
  subject(:holding) { described_class.new(field) }

  describe 'class methods' do
    describe '#dewey_call_number?' do
      it 'is true when it is a dewey call number' do
        expect(described_class.dewey_call_number?('012.12 .W123')).to be true
      end
    end
  end
end
