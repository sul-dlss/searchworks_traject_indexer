require 'spec_helper'

describe Traject::DeleteReader do
  subject(:reader) { described_class.new(File.new(file), {}) }
  let(:file) { file_fixture(fixture_name).to_s }
  let(:fixture_name) { 'ckeys_delete.del' }
  let(:results) { reader.each.to_a }

  describe '#each' do
    it 'just sends to the input_stream' do
      expect(results.length).to eq 10
    end
  end
end
