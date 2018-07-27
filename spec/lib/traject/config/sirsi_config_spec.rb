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
      result = select_by_id('245allSubs')[field]
      expect(result).to eq ['245a']

      expect(results).not_to include hash_including(field => ['electronic'])
      expect(results).not_to include hash_including(field => ['john'])
      expect(results).not_to include hash_including(field => ['handbook'])

      result = select_by_id('2xx')[field]
      expect(result).to eq ['2xx fields']
    end
  end
  describe 'vern_title_245a_search' do
    let(:fixture_name) { 'vernacularSearchTests.mrc' }
    let(:field) { 'vern_title_245a_search' }
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    it 'has the correct titles' do
      expect(select_by_id('2xxVernSearch')[field].first).to match(/vern245a/)
      expect(results).not_to include hash_including(field => ['vern245b'])
      expect(results).not_to include hash_including(field => ['vern245p'])
    end
  end
  describe 'title_245_search' do
    let(:fixture_name) { 'titleTests.mrc' }
    let(:field) { 'title_245_search' }
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    it 'has the correct titles' do
      result = select_by_id('245allSubs')[field]
      expect(result).to eq [
        '245a 245b 245p1 245s 245k1 245f 245n1 245g 245p2 245k2 245n2'
      ]

      result = select_by_id('245pNotn')[field]
      expect(result.first).to include 'handbook'

      result = select_by_id('245pThenn')[field]
      expect(result.first).to include 'Verzeichnis'

      result = select_by_id('245nAndp')[field]
      expect(result.first).to include 'humanities'
    end
  end
  describe 'vern_title_245_search' do
    let(:fixture_name) { 'vernacularSearchTests.mrc' }
    let(:field) { 'vern_title_245_search' }
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    it 'has the correct titles' do
      expect(select_by_id('2xxVernSearch')[field].first)
        .to eq 'vern245a vern245b vern245f vern245g vern245k vern245n vern245p vern245s'
      expect(results).not_to include hash_including(field => ['nope'])
    end
  end
  describe 'title_uniform_search' do
    let(:fixture_name) { 'titleTests.mrc' }
    let(:field) { 'title_uniform_search' }
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    it 'has the correct titles' do
      expect(select_by_id('130240')[field]).to eq ['Hoos Foos']
      expect(select_by_id('130')[field]).to eq ['The Snimm.']

      expect(results).not_to include hash_including(field => ['balloon'])
      expect(results).not_to include hash_including(field => ['130'])
    end
  end
end
