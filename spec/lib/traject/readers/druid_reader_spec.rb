# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Traject::DruidReader do
  subject(:reader) { described_class.new("a\nb\nc", settings) }
  let(:settings) { {} }

  describe '#each' do
    it 'returns objects from the purl-fetcher api' do
      expect(reader.each.map(&:druid)).to eq %w[a b c]
    end
  end
end
