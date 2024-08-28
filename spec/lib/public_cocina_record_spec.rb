# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PublicCocinaRecord do
  subject(:record) { described_class.new(druid, cocina_json) }

  let(:druid) { 'vv853br8653' }
  let(:cocina_json) { File.read(file_fixture("#{druid}.json")) }

  describe '#created' do
    it 'returns the parsed created date' do
      expect(record.created).to eq(Time.parse('2014-02-03T18:33:02.000+00:00'))
    end

    context 'when the created date is missing' do
      let(:druid) { 'cb601kb6593' }

      it 'returns nil' do
        expect(record.created).to be_nil
      end
    end
  end

  describe '#modified' do
    it 'returns the parsed modified date' do
      expect(record.modified).to eq(Time.parse('2022-09-28T21:48:32.000+00:00'))
    end

    context 'when the modified date is missing' do
      let(:druid) { 'cb601kb6593' }

      it 'returns nil' do
        expect(record.modified).to be_nil
      end
    end
  end
end
