# frozen_string_literal: true

RSpec.describe 'Sirsi config' do
  subject(:result) { indexer.map_record(marc_to_folio_with_stubbed_holdings(record)) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end
  let(:records) { MARC::JSONLReader.new(file_fixture(fixture_name).to_s).to_a }
  let(:fixture_name) { 'idTests.jsonl' }
  let(:record) { records.first }

  describe 'id' do
    subject(:results) { records.map { |rec| indexer.map_record(marc_to_folio_with_stubbed_holdings(rec)) }.to_a }
    it do
      expect(results).to include hash_including('id' => ['001suba'])
      expect(results).to include hash_including('id' => ['001subaAnd004nosub'])
      expect(results).to include hash_including('id' => ['001subaAnd004suba'])
      expect(results).not_to include hash_including('id' => ['004noSuba'])
      expect(results).not_to include hash_including('id' => ['004suba'])
      pending 'failed assertion'
      expect(results).not_to include hash_including('id' => ['001noSubNo004'])
      expect(results).not_to include hash_including('id' => ['001and004nosub'])
    end
  end

  describe 'hashed_id_ssi' do
    subject(:results) { records.map { |rec| indexer.map_record(marc_to_folio_with_stubbed_holdings(rec)) }.to_a }
    it do
      expect(results).to include hash_including('id' => ['001suba'],
                                                'hashed_id_ssi' => ['f00f2f3999440420ee1cb0fbfaf6dd25'])
    end
  end

  describe 'marc_json_struct' do
    let(:fixture_name) { 'fieldOrdering.jsonl' }
    it do
      ix650 = result['marc_json_struct'].first.index '650first'
      ix600 = result['marc_json_struct'].first.index '600second'
      expect(ix650 < ix600).to be true
    end

    it 'has the MARC leader' do
      expect(JSON.parse(result['marc_json_struct'].first)['leader']).to eq record.leader
    end
  end

  describe 'context_marc_fields_ssim' do
    subject(:result) { indexer.map_record(marc_to_folio_with_stubbed_holdings(record)) }

    it 'indexes field counts' do
      expect(result['context_marc_fields_ssim']).to include '008', '245'
    end

    it 'index subfield counts' do
      expect(result['context_marc_fields_ssim']).to include '245a'
    end

    context 'for a record with multiple subfields' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01952cas  2200457Ia 4500'
          r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 0 eng d'))
          r.append(MARC::DataField.new('999', ' ', ' ',
                                       MARC::Subfield.new('a', 'QE538.8 .N36 1975-1977'),
                                       MARC::Subfield.new('w', 'LC'),
                                       MARC::Subfield.new('i', 'LCbarcode'),
                                       MARC::Subfield.new('m', 'GREEN')))
        end
      end
      it 'indexes individual subfields' do
        expect(result['context_marc_fields_ssim']).to include '?999a', '?999w', '?999i', '?999m'
      end
    end
  end
end
