# frozen_string_literal: true

RSpec.describe 'All_search config' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end
  let(:records) { MARC::JSONLReader.new(file_fixture(fixture_name).to_s).to_a }
  let(:fixture_name) { 'allfieldsTests.jsonl' }
  let(:record) { records.first }
  subject(:results) { records.map { |rec| indexer.map_record(marc_to_folio(rec)) }.to_a }
  let(:field) { 'all_search' }

  describe 'all_search' do
    it do
      expect(select_by_id('allfields1')[field]).to include(/should/)
      # 0xx fields are not included except 024, 027, 028
      expect(select_by_id('allfields1')[field]).to include(/2777802000/)
      expect(select_by_id('allfields1')[field]).to include(/90620/)
      expect(select_by_id('allfields1')[field]).to include(/technical/i)
      expect(select_by_id('allfields1')[field]).to include(/vibrations/i)
      expect(select_by_id('allfields1')[field]).not_to include(/ocolcm/)
      expect(select_by_id('allfields1')[field]).not_to include(/orlobrs/)

      # 3xx fields ARE include(
      expect(select_by_id('allfields1')[field]).to include(/sound/)
      expect(select_by_id('allfields1')[field]).to include(/annual/i)

      # 9xx fields are NOT included
      expect(select_by_id('allfields1')[field]).not_to include(/EDATA/)
      expect(select_by_id('allfields1')[field]).not_to include(/pamphlet/)
      expect(select_by_id('allfields1')[field]).not_to include(/stacks/)

      # Except for 905, 920 and 986 (SW-814)
      # SKIP: No test with actual mrc data, only using contrived
      # all_search should include 033a
    end
  end
end
