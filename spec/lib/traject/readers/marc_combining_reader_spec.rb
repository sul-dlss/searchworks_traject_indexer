# frozen_string_literal: true

require 'spec_helper'

describe Traject::MarcCombiningReader do
  subject(:reader) { described_class.new(file_fixture(fixture_name).open, 'marc_source.type' => 'json') }
  let(:fixture_name) { 'splitItemsTest.jsonl' }
  let(:results) { reader.each.to_a }

  describe '#each' do
    it 'merges MARC records when their 001 fields match' do
      expect(results.length).to eq 5

      expect(results.map { |x| x['001'].value }).to eq %w[anotSplit1 anotSplit2 asplit1 asplit2 asplit3]

      asplit1 = results.find { |r| r['001'].value == 'asplit1' }
      expect(asplit1.fields('008').length).to eq 1
      expect(asplit1.fields('245').length).to eq 1
      expect(asplit1.fields('999').length).to eq 5
      expect(asplit1.fields('999').map do |x|
               x['a']
             end).to eq ['A1 .B2 V.1', 'A1 .B2 V.2', 'A1 .B2 V.3', 'A1 .B2 V.4', 'A1 .B2 V.5']
    end
  end
end
