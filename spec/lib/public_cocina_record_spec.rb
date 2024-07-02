# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PublicCocinaRecord do
  subject(:cocina_record) { described_class.new(druid, record) }

  let(:druid) { 'vv853br8653' }
  let(:record) { file_fixture("#{druid}.json").read }

  it 'parses the JSON document' do
    expect(cocina_record.public_cocina_doc).to eq JSON.parse(record)
  end

  describe 'dates' do
    it 'parses the created date' do
      expect(cocina_record.created).to eq Time.parse('2014-02-03T18:33:02Z')
    end

    it 'parses the modified date' do
      expect(cocina_record.modified).to eq Time.parse('2022-09-28T21:48:32Z')
    end

    context 'when the dates are not present' do
      let(:record) { '{"created": null, "modified": null}' }

      it 'returns nil' do
        expect(cocina_record.created).to be_nil
        expect(cocina_record.modified).to be_nil
      end
    end
  end
end
