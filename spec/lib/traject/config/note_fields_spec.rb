RSpec.describe 'Sirsi config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end
  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }

  describe 'toc_search' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    let(:fixture_name) { 'summaryTests.mrc' }
    let(:field) { 'toc_search'}

    it 'maps the right fields' do
      result = select_by_id('505')[field]
      expect(result).to eq ['505a 505r 505t']

      expect(results).not_to include hash_including(field => ['nope'])
    end

    context 'with Nielson data' do
      let(:fixture_name) { 'nielsenTests.mrc' }

      it 'indexes both the 505 and 905 fields' do
        result = select_by_id('505')[field]
        expect(result).to eq ['505a 505r 505t']

        result = select_by_id('905')[field]
        expect(result).to eq ['905a 905r 905t']

        result = select_by_id('bothx05')[field]
        expect(result).to eq ['505a 505r 505t', '905a 905r 905t']

        expect(results).not_to include hash_including(field => include(/505g/))
        expect(results).not_to include hash_including(field => include(/505u/))
        expect(results).not_to include hash_including(field => include(/905g/))
        expect(results).not_to include hash_including(field => include(/905u/))
      end
    end
  end

  describe 'vern_toc_search' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    let(:fixture_name) { 'summaryTests.mrc' }
    let(:field) { 'vern_toc_search'}

    it 'maps the right fields' do
      result = select_by_id('505')[field]
      expect(result).to eq ['vern505a vern505r vern505t']

      expect(results).not_to include hash_including(field => ['nope'])
    end
  end

  describe 'context_search' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    let(:fixture_name) { 'summaryTests.mrc' }
    let(:field) { 'context_search'}

    it 'maps the right fields' do
      result = select_by_id('518')[field]
      expect(result).to eq ['518a']

      expect(results).not_to include hash_including(field => ['nope'])
    end
  end

  describe 'vern_context_search' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    let(:fixture_name) { 'summaryTests.mrc' }
    let(:field) { 'vern_context_search'}

    it 'maps the right fields' do
      result = select_by_id('518')[field]
      expect(result).to eq ['vern518a']

      expect(results).not_to include hash_including(field => ['nope'])
    end
  end

  describe 'summary_search' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    let(:fixture_name) { 'summaryTests.mrc' }
    let(:field) { 'summary_search'}

    it 'maps the right fields' do
      result = select_by_id('520')[field]
      expect(result).to eq ['520a 520b']

      expect(results).not_to include hash_including(field => ['nope'])
    end

    context 'with Nielson data' do
      let(:fixture_name) { 'nielsenTests.mrc' }

      it 'indexes both the 505 and 905 fields' do
        result = select_by_id('520')[field]
        expect(result).to eq ['520a 520b']

        result = select_by_id('920')[field]
        expect(result).to eq ['920a 920b']

        result = select_by_id('bothx20')[field]
        expect(result).to eq ['520a 520b', '920a 920b']

        expect(results).not_to include hash_including(field => include(/520c/))
        expect(results).not_to include hash_including(field => include(/520u/))
        expect(results).not_to include hash_including(field => include(/920c/))
        expect(results).not_to include hash_including(field => include(/920u/))
      end
    end
  end

  describe 'vern_summary_search' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    let(:fixture_name) { 'summaryTests.mrc' }
    let(:field) { 'vern_summary_search'}

    it 'maps the right fields' do
      result = select_by_id('520')[field]
      expect(result).to eq ['vern520a vern520b']

      expect(results).not_to include hash_including(field => ['nope'])
    end
  end

  describe 'award_search' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    let(:fixture_name) { 'nielsenTests.mrc' }
    let(:field) { 'award_search'}

    it 'maps the right fields' do
      result = select_by_id('586')[field]
      expect(result).to eq ['New Zealand Post book awards winner', '586 second award']

      result = select_by_id('986')[field]
      expect(result).to eq ['Shortlisted for Montana New Zealand Book Awards: History Category 2006.', '986 second award']

      result = select_by_id('one586two986')[field]
      expect(result).to eq ['586 award', '986 award1', '986 award2']

      result = select_by_id('two586one986')[field]
      expect(result).to eq ['586 1award', '586 2award', '986 single award']
    end
  end
end
