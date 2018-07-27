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
  describe 'vern_title_uniform_search' do
    let(:fixture_name) { 'vernacularSearchTests.mrc' }
    let(:field) { 'vern_title_uniform_search' }
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    it 'has the correct titles' do
      expect(select_by_id('2xxVernSearch')[field].first)
        .to eq 'vern130a vern130d vern130f vern130g vern130k vern130l vern130m'\
          ' vern130n vern130o vern130p vern130r vern130s vern130t'
      expect(select_by_id('240VernSearch')[field].first)
        .to eq 'vern240a vern240d vern240f vern240g vern240k vern240l vern240m'\
          ' vern240n vern240o vern240p vern240r vern240s'
      expect(results).not_to include hash_including(field => ['nope'])
    end
  end
  describe 'title_variant_search' do
    let(:fixture_name) { 'titleTests.mrc' }
    let(:field) { 'title_variant_search' }
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    it 'has the correct titles' do
      expect(select_by_id('2xx')[field][0]).to eq '210a 210b'
      expect(select_by_id('2xx')[field][1]).to eq '222a 222b'
      expect(select_by_id('2xx')[field][2]).to eq '242a 242b 242n 242p'
      expect(select_by_id('2xx')[field][3]).to eq '243a 243d 243f 243g 243k '\
        '243l 243m 243n 243o 243p 243r 243s'
      expect(select_by_id('2xx')[field][4]).to eq '246a 246b 246f 246g 246n 246p'
      expect(select_by_id('2xx')[field][5]).to eq '247a 247b 247f 247g 247n 247p'

      expect(results).not_to include hash_including(field => ['nope'])
    end
  end
  describe 'vern_title_variant_search' do
    let(:fixture_name) { 'vernacularSearchTests.mrc' }
    let(:field) { 'vern_title_variant_search' }
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    it 'has the correct titles' do
      expect(select_by_id('2xxVernSearch')[field][0]).to eq 'vern210a vern210b'
      expect(select_by_id('2xxVernSearch')[field][1]).to eq 'vern222a vern222b'
      expect(select_by_id('2xxVernSearch')[field][2]).to eq 'vern242a vern242b'\
        ' vern242n vern242p'
      expect(select_by_id('2xxVernSearch')[field][3]).to eq 'vern243a vern243d'\
        ' vern243f vern243g vern243k vern243l vern243m vern243n vern243o'\
        ' vern243p vern243r vern243s'
      expect(select_by_id('2xxVernSearch')[field][4]).to eq 'vern246a vern246b'\
        ' vern246f vern246g vern246n vern246p'
      expect(select_by_id('2xxVernSearch')[field][5]).to eq 'vern247a vern247b'\
        ' vern247f vern247g vern247n vern247p'

      expect(results).not_to include hash_including(field => ['nope'])
      expect(results).not_to include hash_including(field => ['vern243'])
    end
  end
  describe 'title_related_search' do
    let(:fixture_name) { 'titleTests.mrc' }
    let(:field) { 'title_related_search' }
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    it 'has the correct titles' do
      expect(select_by_id('505')[field]).to eq ['505t']
      expect(results).not_to include hash_including(field => ['nope'])

      expect(select_by_id('700')[field][0]).to eq '700f 700g 700k 700l 700m 70'\
        '0n 700o 700p 700r 700s 700t'

      expect(select_by_id('710')[field][0]).to eq '710d 710f 710g 710k 710l 71'\
        '0m 710n 710o 710p 710r 710s 710t'

      expect(select_by_id('711')[field][0]).to eq '711f 711g 711k 711l 711n 71'\
        '1p 711s 711t'

      expect(select_by_id('730')[field][0]).to eq '730a 730d 730f 730g 730k 73'\
        '0l 730m 730n 730o 730p 730r 730s 730t'

      expect(select_by_id('740')[field][0]).to eq '740a 740n 740p'

      expect(select_by_id('246aAnd740')[field][0]).to eq '740 subfield a'

      expect(select_by_id('76x')[field]).to eq [
        '760s 760t', '762s 762t', '765s 765t', '767s 767t'
      ]

      expect(select_by_id('77x')[field]).to eq [
        '770s 770t', '772s 772t', '773s 773t', '774s 774t', '775s 775t',
        '776s 776t', '777s 777t'
      ]

      expect(select_by_id('78x')[field]).to eq [
        '780s 780t', '785s 785t', '786s 786t', '787s 787t'
      ]

      ['780tNota', '780aAndt', '780tNota'].each do |id|
        expect(select_by_id(id)[field].first).to include '780 subfield t'
      end

      ['785tNota', '785aAndt'].each do |id|
        expect(select_by_id(id)[field].first).to include '785 subfield t'
      end

      ['780tNota', '785tNota'].each do |id|
        expect(select_by_id(id)[field].first).to include 'only'
      end

      expect(select_by_id('785aNott')[field]).to be_nil
    end
  end
  describe 'vern_title_related_search' do
    let(:field) { 'vern_title_related_search' }
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    context 'with summaryTests' do
      let(:fixture_name) { 'summaryTests.mrc' }
      it 'has the correct titles' do
        expect(select_by_id('505')[field]).to eq ['vern505t']
        expect(results).not_to include hash_including(field => ['nope'])
      end
    end
    context 'with vernacularSearchTests.mrc' do
      let(:fixture_name) { 'vernacularSearchTests.mrc' }
      it 'has the correct titles' do
        expect(select_by_id('7xxLowVernSearch')[field][0]).to eq 'vern700f ver'\
          'n700g vern700k vern700l vern700m vern700n vern700o vern700p vern700'\
          'r vern700s vern700t'

        ['7xxLowVernSearch', '7xxVernPersonSearch'].each do |id|
          expect(select_by_id(id)[field].first).to include 'vern700g'
        end

        expect(results).not_to include hash_including(field => ['vern700j'])
        expect(results).not_to include hash_including(field => ['nope'])
      end
    end
  end
end
