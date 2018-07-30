RSpec.describe 'Author config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end

  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }
  let(:fixture_name) { 'authorTests.mrc' }
  subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }

  describe 'author_1xx_search' do
    let(:field) { 'author_1xx_search' }

    it 'has all subfields from 100' do
      result = select_by_id('100search')[field]
      expect(result).to eq ['100a 100b 100c 100d 100g 100j 100q 100u']
      expect(results).not_to include hash_including(field => ['100e'])
      expect(results).not_to include hash_including(field => ['none'])
    end

    it 'has all subfields from 110' do
      result = select_by_id('110search')[field]
      expect(result).to eq ['110a 110b 110c 110d 110g 110n 110u']
      expect(results).not_to include hash_including(field => ['110e'])
      expect(results).not_to include hash_including(field => ['110f'])
      expect(results).not_to include hash_including(field => ['110k'])
      expect(results).not_to include hash_including(field => ['none'])
    end

    it 'has all subfields from 111' do
      result = select_by_id('111search')[field]
      expect(result).to eq ['111a 111c 111d 111e 111g 111j 111n 111q 111u']
      expect(results).not_to include hash_including(field => ['111i'])
      expect(results).not_to include hash_including(field => ['none'])
    end
  end

  describe 'vern_author_1xx_search' do
    let(:fixture_name) { 'vernacularSearchTests.mrc' }
    let(:field) { 'vern_author_1xx_search' }
    it 'has all subfields from linked 100' do
      result = select_by_id('100VernSearch')[field]
      expect(result).to eq ['vern100a vern100b vern100c vern100d vern100g vern100j vern100q vern100u']
      expect(results).not_to include hash_including(field => ['vern100e'])
      expect(results).not_to include hash_including(field => ['none'])
    end

    it 'has all subfields from linked 110' do
      result = select_by_id('110VernSearch')[field]
      expect(result).to eq ['vern110a vern110b vern110c vern110d vern110g vern110n vern110u']
      expect(results).not_to include hash_including(field => ['vern110e'])
      expect(results).not_to include hash_including(field => ['vern110f'])
      expect(results).not_to include hash_including(field => ['vern110k'])
      expect(results).not_to include hash_including(field => ['none'])
    end

    it 'has all subfields from linked 111' do
      result = select_by_id('111VernSearch')[field]
      expect(result).to eq ['vern111a vern111c vern111d vern111e vern111g vern111j vern111n vern111q vern111u']
      expect(results).not_to include hash_including(field => ['vern111i'])
      expect(results).not_to include hash_including(field => ['none'])
    end
  end

  describe 'author_7xx_search' do
    let(:field) { 'author_7xx_search' }

    it 'has all subfields from 700, 720, and 796' do
      result = select_by_id('7xxPersonSearch')[field]
      expect(result).to eq ['700a 700b 700c 700d 700g 700j 700q 700u', '720a 720e', '796a 796b 796c 796d 796g 796j 796q 796u']
      expect(results).not_to include hash_including(field => ['700e'])
      expect(results).not_to include hash_including(field => ['796e'])
      expect(results).not_to include hash_including(field => ['none'])
    end
  end

  describe 'vern_author_7xx_search' do
    let(:fixture_name) { 'vernacularSearchTests.mrc' }
    let(:field) { 'vern_author_7xx_search' }

    context 'personal name fields' do
      it 'has all subfields from linked 700, 720, and 796' do
        result = select_by_id('7xxVernPersonSearch')[field]
        expect(result).to eq ['vern700a vern700b vern700c vern700d vern700g vern700j vern700q vern700u',
                              'vern720a vern720e',
                              'vern796a vern796b vern796c vern796d vern796g vern796j vern796q vern796u']
        expect(results).not_to include hash_including(field => ['vern700e'])
        expect(results).not_to include hash_including(field => ['vern796e'])
        expect(results).not_to include hash_including(field => ['none'])
      end

      it 'has subfields that overlap with title', pending: :fixme do
        result = select_by_id('7xxLowVernSearch')[field][0]
        expect(result).to eq 'vern700g vern700j'

        ['7xxLowVernSearch', '7xxVernPersonSearch'].each do |id|
          expect(select_by_id(id)[field].first).to include 'vern700g vern700j'
        end

        expect(select_by_id('79xVernSearch')[field].first).to include 'vern796g vern796j'
      end
    end

    context 'corporate name fields' do
      it 'has all subfields from linked 710 and 797' do
        result = select_by_id('7xxVernCorpSearch')[field]
        expect(result).to eq ['vern710a vern710b vern710c vern710d vern710g vern710n vern710u',
                              'vern797a vern797b vern797c vern797d vern797g vern797n vern797u']
        expect(results).not_to include hash_including(field => ['vern710e'])
        expect(results).not_to include hash_including(field => ['vern710f'])
        expect(results).not_to include hash_including(field => ['vern710k'])
        expect(results).not_to include hash_including(field => ['vern797e'])
        expect(results).not_to include hash_including(field => ['vern797f'])
        expect(results).not_to include hash_including(field => ['vern797k'])
        expect(results).not_to include hash_including(field => ['none'])
      end

      it 'has subfields that overlap with title' do
        result = select_by_id('7xxLowVernSearch')[field][1]
        expect(result).to eq 'vern710d vern710g vern710n'

        result = select_by_id('79xVernSearch')[field][1]
        expect(result).to eq 'vern797d vern797g vern797n'
      end
    end

    context 'meeting name fields' do
      it 'has all subfields from linked 711 and 798' do
        result = select_by_id('7xxVernMeetingSearch')[field]
        expect(result).to eq ['vern711a vern711c vern711d vern711e vern711g vern711j vern711n vern711q vern711u',
                              'vern798a vern798c vern798d vern798e vern798g vern798j vern798n vern798q vern798u']
        expect(results).not_to include hash_including(field => ['vern711i'])
        expect(results).not_to include hash_including(field => ['vern798i'])
        expect(results).not_to include hash_including(field => ['none'])
      end

      it 'has subfields that overlap with title', pending: :fixme do
        result = select_by_id('7xxLowVernSearch')[field][2]
        expect(result).to eq 'vern711g vern711n'

        result = select_by_id('79xVernSearch')[field][2]
        expect(result).to eq 'vern798e vern798g vern798n'
      end
    end
  end
end
