RSpec.describe 'Sirsi config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end
  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:fixture_name) { 'idTests.mrc' }
  let(:record) { records.first }

  describe 'id' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
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
  describe 'marcxml' do
    let(:fixture_name) { 'fieldOrdering.mrc' }
    it do
      ix650 = result['marcxml'].first.index '650first'
      ix600 = result['marcxml'].first.index '600second'
      expect(ix650 < ix600).to be true
    end
  end
  describe 'title_245a_search' do
    let(:fixture_name) { 'titleTests.mrc' }
    let(:field) { 'title_245a_search' }
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    it 'has the correct titles' do
      assert_single_result('245allSubs', field, '245a')
      assert_zero_result(field, 'electronic')
      assert_zero_result(field, 'john')
      assert_zero_result(field, 'handbook')
      pending 'failed assertion'
      assert_single_result('2xx', field, '2xx')
    end
  end
  describe 'vern_title_245a_search' do
    let(:fixture_name) { 'vernacularSearchTests.mrc' }
    let(:field) { 'vern_title_245a_search' }
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    it 'has the correct titles' do
      assert_single_result('2xxVernSearch', field, 'vern245a')
      assert_zero_result(field, 'vern245b')
      assert_zero_result(field, 'vern245b')
    end
  end
end
