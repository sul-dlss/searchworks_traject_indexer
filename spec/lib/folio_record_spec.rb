# frozen_string_literal: true

require 'folio_record'

RSpec.describe FolioRecord do
  subject(:folio_record) { described_class.new_from_source_record(record) }
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
end
