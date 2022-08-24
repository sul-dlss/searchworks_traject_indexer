# frozen_string_literal: true

require 'folio_client'
require 'folio_record'

RSpec.describe FolioRecord do
  subject(:folio_record) { described_class.new_from_source_record(record, client) }
  let(:client) { instance_double(FolioClient) }
  let(:record) do
    {
      'parsedRecord' => {
        'id' => '0e050e3f-b160-5f5d-9fdb-2d49305fbb0d',
        'content' => {
          'fields' => [
            { '001' => 'a14154194' },
            { '918' => {
              'subfields' => [
                { 'a' => '14154194' }
              ]
            } }
          ]
        }
      }
    }
  end

  describe '#marc_record' do
    it 'strips junk tags' do
      expect(folio_record.marc_record['918']).to be_nil
    end

    it 'preserves non-junk tags' do
      expect(folio_record.marc_record['001']).to have_attributes(tag: '001', value: 'a14154194')
    end
  end

  describe '#deleted?' do
    subject(:folio_record) { described_class.new(record, client) }

    context 'when not suppressed or deleted' do
      let(:record) do
        {
          'source_record' => [{
            'fields' => [],
            'leader' => '00000cam a2200000 a 4500'
          }],
          'deleted' => false,
          'additionalInfo' => { 'suppressDiscovery' => false }
        }
      end
      it 'is false' do
        expect(folio_record.deleted?).to be false
      end
    end

    context 'when the record is suppressed from discovery in folio' do
      let(:record) do
        {
          'source_record' => [{ 'fields' => [] }],
          'additionalInfo' => { 'suppressDiscovery' => true }
        }
      end

      it 'is true' do
        expect(folio_record.deleted?).to be true
      end
    end

    context 'when the record is marked as deleted in folio' do
      let(:record) do
        {
          'source_record' => [{ 'fields' => [] }],
          'deleted' => true
        }
      end

      it 'is true' do
        expect(folio_record.deleted?).to be true
      end
    end

    context 'when the MARC leader 05 is set to mark a deletion' do
      let(:record) do
        {
          'source_record' => [{
            'fields' => [],
            'leader' => '00000dam a2200000 a 4500'
          }]
        }
      end

      it 'is true' do
        expect(folio_record.deleted?).to be true
      end
    end
  end
end
