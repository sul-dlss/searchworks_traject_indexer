# frozen_string_literal: true

RSpec.describe 'Subject config' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:records) { MARC::JSONLReader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }
  let(:fixture_name) { 'subjectSearchTests.jsonl' }
  let(:results) { records.map { |rec| indexer.map_record(marc_to_folio(rec)) }.to_a }
  subject(:result) { indexer.map_record(marc_to_folio(record)) }

  describe 'topic_search' do
    let(:field) { 'topic_search' }

    it 'has all subfields except v, x, y, and z from 650' do
      result = select_by_id('650search')[field]
      expect(result).to eq ['650a 650b 650c 650d 650e']

      result = select_by_id('Vern650search')[field]

      expect(result).to eq ['650a']

      expect(results).not_to include hash_including(field => ['650v'])
      expect(results).not_to include hash_including(field => ['650x'])
      expect(results).not_to include hash_including(field => ['650y'])
      expect(results).not_to include hash_including(field => ['650z'])
    end

    it 'has all subfields except v, x, y, and z from 690' do
      result = select_by_id('690search')[field]
      expect(result).to eq ['690a 690b 690c 690d 690e']

      result = select_by_id('Vern690search')[field]

      expect(result).to eq ['690a']

      expect(results).not_to include hash_including(field => ['690v'])
      expect(results).not_to include hash_including(field => ['690x'])
      expect(results).not_to include hash_including(field => ['690y'])
      expect(results).not_to include hash_including(field => ['690z'])
    end

    it 'has all subfields except v, x, y, and z from 653' do
      result = select_by_id('653search')[field]
      expect(result).to eq ['653a']

      result = select_by_id('Vern653search')[field]

      expect(result).to eq ['653a']

      expect(results).not_to include hash_including(field => ['653v'])
      expect(results).not_to include hash_including(field => ['653x'])
      expect(results).not_to include hash_including(field => ['653y'])
      expect(results).not_to include hash_including(field => ['653z'])
    end

    it 'has all subfields except v, x, y, and z from 654' do
      result = select_by_id('654search')[field]
      expect(result).to eq ['654a 654b 654c 654e']

      result = select_by_id('Vern654search')[field]

      expect(result).to eq ['654a']

      expect(results).not_to include hash_including(field => ['654v'])
      expect(results).not_to include hash_including(field => ['654x'])
      expect(results).not_to include hash_including(field => ['654y'])
      expect(results).not_to include hash_including(field => ['654z'])
    end

    context 'real data' do
      let(:fixture_name) { 'subjectTests.jsonl' }

      it 'has the right transforms' do
        result = select_by_id('1261173')[field]
        expect(result).to eq ['Standing army']

        result = select_by_id('4698973')[field]
        expect(result).to eq ['Missions', 'Multiculturalism', 'Flyby missions.', 'Christianity and culture.']

        result = select_by_id('919006')[field]
        expect(result).to eq ['Literature, Comparative.']

        result = select_by_id('229800')[field]
        expect(result).to eq ['Commodity exchanges.', 'Foreign exchange.']

        expect(results).not_to include hash_including(field => include('nasat'))
      end
    end
  end

  describe 'vern_topic_search' do
    let(:field) { 'vern_topic_search' }

    it 'has all subfields except v, x, y, and z from 650' do
      result = select_by_id('Vern650search')[field]
      expect(result).to eq ['vern650a vern650b vern650c vern650d vern650e']

      expect(results).not_to include hash_including(field => ['vern650v'])
      expect(results).not_to include hash_including(field => ['vern650x'])
      expect(results).not_to include hash_including(field => ['vern650y'])
      expect(results).not_to include hash_including(field => ['vern650z'])
    end

    it 'has all subfields except v, x, y, and z from 690' do
      result = select_by_id('Vern690search')[field]
      expect(result).to eq ['vern690a vern690b vern690c vern690d vern690e']

      expect(results).not_to include hash_including(field => ['vern690v'])
      expect(results).not_to include hash_including(field => ['vern690x'])
      expect(results).not_to include hash_including(field => ['vern690y'])
      expect(results).not_to include hash_including(field => ['vern690z'])
    end

    it 'has all subfields except v, x, y, and z from 653' do
      result = select_by_id('Vern653search')[field]
      expect(result).to eq ['vern653a']

      expect(results).not_to include hash_including(field => ['vern653v'])
      expect(results).not_to include hash_including(field => ['vern653x'])
      expect(results).not_to include hash_including(field => ['vern653y'])
      expect(results).not_to include hash_including(field => ['vern653z'])
    end

    it 'has all subfields except v, x, y, and z from 654' do
      result = select_by_id('Vern654search')[field]
      expect(result).to eq ['vern654a vern654b vern654c vern654e']

      expect(results).not_to include hash_including(field => ['vern654v'])
      expect(results).not_to include hash_including(field => ['vern654x'])
      expect(results).not_to include hash_including(field => ['vern654y'])
      expect(results).not_to include hash_including(field => ['vern654z'])
    end
  end

  describe 'topic_subx_search' do
    let(:field) { 'topic_subx_search' }

    it 'has subfield x from all subject fields' do
      expect(results).to include hash_including('id' => ['600search'], field => ['600x']),
                                 hash_including('id' => ['610search'], field => ['610x']),
                                 hash_including('id' => ['611search'], field => ['611x']),
                                 hash_including('id' => ['630search'], field => ['630x']),
                                 hash_including('id' => ['650search'], field => ['650x']),
                                 hash_including('id' => ['651search'], field => ['651x']),
                                 # no sub x in 654, 654
                                 hash_including('id' => ['655search'], field => ['655x']),
                                 hash_including('id' => ['656search'], field => ['656x']),
                                 hash_including('id' => ['657search'], field => ['657x']),
                                 # no sub x in 658
                                 hash_including('id' => ['690search'], field => ['690x']),
                                 hash_including('id' => ['691search'], field => ['691x']),
                                 hash_including('id' => ['696search'], field => ['696x']),
                                 hash_including('id' => ['697search'], field => ['697x']),
                                 hash_including('id' => ['698search'], field => ['698x']),
                                 hash_including('id' => ['699search'], field => ['699x'])

      expect(results).not_to include hash_including(field => /a$/)
    end
  end

  describe 'vern_topic_subx_search' do
    let(:field) { 'vern_topic_subx_search' }

    it 'has subfield x from all subject fields' do
      expect(results).to include hash_including('id' => ['Vern600search'], field => ['vern600x']),
                                 hash_including('id' => ['Vern610search'], field => ['vern610x']),
                                 hash_including('id' => ['Vern611search'], field => ['vern611x']),
                                 hash_including('id' => ['Vern630search'], field => ['vern630x']),
                                 hash_including('id' => ['Vern650search'], field => ['vern650x']),
                                 hash_including('id' => ['Vern651search'], field => ['vern651x']),
                                 # no sub x in 654, 654
                                 hash_including('id' => ['Vern655search'], field => ['vern655x']),
                                 hash_including('id' => ['Vern656search'], field => ['vern656x']),
                                 hash_including('id' => ['Vern657search'], field => ['vern657x']),
                                 # no sub x in 658
                                 hash_including('id' => ['Vern690search'], field => ['vern690x']),
                                 hash_including('id' => ['Vern691search'], field => ['vern691x']),
                                 hash_including('id' => ['Vern696search'], field => ['vern696x']),
                                 hash_including('id' => ['Vern697search'], field => ['vern697x']),
                                 hash_including('id' => ['Vern698search'], field => ['vern698x']),
                                 hash_including('id' => ['Vern699search'], field => ['vern699x'])

      expect(results).not_to include hash_including(field => /a$/)
    end
  end

  describe 'geographic_search' do
    let(:field) { 'geographic_search' }

    it 'has all subfields except v, x, y, z from  651' do
      result = select_by_id('651search')[field]
      expect(result).to eq ['651a 651e']

      result = select_by_id('Vern651search')[field]

      expect(result).to eq ['651a']

      expect(results).not_to include hash_including(field => ['651v'])
      expect(results).not_to include hash_including(field => ['651x'])
      expect(results).not_to include hash_including(field => ['651y'])
      expect(results).not_to include hash_including(field => ['651z'])
    end
    it 'has all subfields except v, x, y, z from  691' do
      result = select_by_id('691search')[field]
      expect(result).to eq ['691a 691e']

      result = select_by_id('Vern691search')[field]

      expect(result).to eq ['691a']

      expect(results).not_to include hash_including(field => ['691v'])
      expect(results).not_to include hash_including(field => ['691x'])
      expect(results).not_to include hash_including(field => ['691y'])
      expect(results).not_to include hash_including(field => ['691z'])
    end

    context 'real(ish) data' do
      let(:fixture_name) { 'subjectTests.jsonl' }

      it 'has the right transforms' do
        result = select_by_id('651a')[field]
        expect(result).to eq ['Muppets.']
        result = select_by_id('651again')[field]
        expect(result).to eq ['Muppets']

        # geographic punctuation shouldn't matter
        result = select_by_id('651numPeriod')[field]
        expect(result).to eq ['7.150.']
        result = select_by_id('651parens')[field]
        expect(result).to eq ['Syracuse (N.Y.)']
        result = select_by_id('651siberia')[field]
        expect(result).to eq ['Siberia (Russia).']
        # 651a
        result = select_by_id('6280316')[field]
        expect(result).to match_array %w[Tennessee Arkansas]
      end
    end
  end

  describe 'vern_geographic_search' do
    let(:field) { 'vern_geographic_search' }

    it 'has all subfields except v, x, y, z from  651' do
      result = select_by_id('Vern651search')[field]
      expect(result).to eq ['vern651a vern651e']

      expect(results).not_to include hash_including(field => ['vern651v'])
      expect(results).not_to include hash_including(field => ['vern651x'])
      expect(results).not_to include hash_including(field => ['vern651y'])
      expect(results).not_to include hash_including(field => ['vern651z'])
    end
    it 'has all subfields except v, x, y, z from  691' do
      result = select_by_id('Vern691search')[field]
      expect(result).to eq ['vern691a vern691e']

      expect(results).not_to include hash_including(field => ['vern691v'])
      expect(results).not_to include hash_including(field => ['vern691x'])
      expect(results).not_to include hash_including(field => ['vern691y'])
      expect(results).not_to include hash_including(field => ['vern691z'])
    end
  end

  describe 'geographic_subz_search' do
    let(:field) { 'geographic_subz_search' }

    it 'has subfield z from all subject fields' do
      expect(results).to include hash_including('id' => ['600search'], field => ['600z']),
                                 hash_including('id' => ['610search'], field => ['610z']),
                                 hash_including('id' => ['630search'], field => ['630z']),
                                 hash_including('id' => ['650search'], field => ['650z']),
                                 hash_including('id' => ['651search'], field => ['651z']),
                                 hash_including('id' => ['654search'], field => ['654z']),
                                 hash_including('id' => ['655search'], field => ['655z']),
                                 hash_including('id' => ['656search'], field => ['656z']),
                                 hash_including('id' => ['657search'], field => ['657z']),
                                 # no sub z in 658
                                 hash_including('id' => ['690search'], field => ['690z']),
                                 hash_including('id' => ['691search'], field => ['691z']),
                                 hash_including('id' => ['696search'], field => ['696z']),
                                 hash_including('id' => ['697search'], field => ['697z']),
                                 hash_including('id' => ['698search'], field => ['698z']),
                                 hash_including('id' => ['699search'], field => ['699z'])

      expect(results).not_to include hash_including(field => /a$/)
    end
  end

  describe 'vern_geographic_subz_search' do
    let(:field) { 'vern_geographic_subz_search' }

    it 'has subfield z from all subject fields' do
      expect(results).to include hash_including('id' => ['Vern600search'], field => ['vern600z']),
                                 hash_including('id' => ['Vern610search'], field => ['vern610z']),
                                 hash_including('id' => ['Vern630search'], field => ['vern630z']),
                                 hash_including('id' => ['Vern650search'], field => ['vern650z']),
                                 hash_including('id' => ['Vern651search'], field => ['vern651z']),
                                 hash_including('id' => ['Vern654search'], field => ['vern654z']),
                                 hash_including('id' => ['Vern655search'], field => ['vern655z']),
                                 hash_including('id' => ['Vern656search'], field => ['vern656z']),
                                 hash_including('id' => ['Vern657search'], field => ['vern657z']),
                                 # no sub z in 658
                                 hash_including('id' => ['Vern690search'], field => ['vern690z']),
                                 hash_including('id' => ['Vern691search'], field => ['vern691z']),
                                 hash_including('id' => ['Vern696search'], field => ['vern696z']),
                                 hash_including('id' => ['Vern697search'], field => ['vern697z']),
                                 hash_including('id' => ['Vern698search'], field => ['vern698z']),
                                 hash_including('id' => ['Vern699search'], field => ['vern699z'])

      expect(results).not_to include hash_including(field => /a$/)
    end
  end

  describe 'subject_other_search' do
    let(:field) { 'subject_other_search' }

    it 'has all subfields except v, x, y, z from  600' do
      result = select_by_id('600search')[field]
      expect(result).to eq ['600a 600b 600c 600d 600e 600f 600g 600h 600j 600k 600l 600m 600n 600o 600p 600q 600r 600s 600t 600u']

      result = select_by_id('Vern600search')[field]

      expect(result).to eq ['600a']

      expect(results).not_to include hash_including(field => ['600v'])
      expect(results).not_to include hash_including(field => ['600x'])
      expect(results).not_to include hash_including(field => ['600y'])
      expect(results).not_to include hash_including(field => ['600z'])
    end

    it 'has all subfields except v, x, y, z from  610' do
      result = select_by_id('610search')[field]
      expect(result).to eq ['610a 610b 610c 610d 610e 610f 610g 610h 610k 610l 610m 610n 610o 610p 610r 610s 610t 610u']

      result = select_by_id('Vern610search')[field]

      expect(result).to eq ['610a']

      expect(results).not_to include hash_including(field => ['610v'])
      expect(results).not_to include hash_including(field => ['610x'])
      expect(results).not_to include hash_including(field => ['610y'])
      expect(results).not_to include hash_including(field => ['610z'])
    end

    it 'has all subfields except v, x, y, z from  611' do
      result = select_by_id('611search')[field]
      expect(result).to eq ['611a 611c 611d 611e 611f 611g 611h 611j 611k 611l 611n 611p 611q 611s 611t 611u']

      result = select_by_id('Vern611search')[field]

      expect(result).to eq ['611a']

      expect(results).not_to include hash_including(field => ['611v'])
      expect(results).not_to include hash_including(field => ['611x'])
      expect(results).not_to include hash_including(field => ['611y'])
      expect(results).not_to include hash_including(field => ['611z'])
    end

    it 'has all subfields except v, x, y, z from  630' do
      result = select_by_id('630search')[field]
      expect(result).to eq ['630a 630d 630e 630f 630g 630h 630k 630l 630m 630n 630o 630p 630r 630s 630t']

      result = select_by_id('Vern630search')[field]

      expect(result).to eq ['630a']

      expect(results).not_to include hash_including(field => ['630v'])
      expect(results).not_to include hash_including(field => ['630x'])
      expect(results).not_to include hash_including(field => ['630y'])
      expect(results).not_to include hash_including(field => ['630z'])
    end

    it 'has all subfields except v, x, y, z from  655' do
      result = select_by_id('655search')[field]
      expect(result).to eq ['655a 655b 655c']

      result = select_by_id('Vern655search')[field]

      expect(result).to eq ['655a']

      expect(results).not_to include hash_including(field => ['655v'])
      expect(results).not_to include hash_including(field => ['655x'])
      expect(results).not_to include hash_including(field => ['655y'])
      expect(results).not_to include hash_including(field => ['655z'])
    end

    it 'has all subfields except v, x, y, z from  656' do
      result = select_by_id('656search')[field]
      expect(result).to eq ['656a 656k']

      result = select_by_id('Vern656search')[field]

      expect(result).to eq ['656a']

      expect(results).not_to include hash_including(field => ['656v'])
      expect(results).not_to include hash_including(field => ['656x'])
      expect(results).not_to include hash_including(field => ['656y'])
      expect(results).not_to include hash_including(field => ['656z'])
    end

    it 'has all subfields except v, x, y, z from  657' do
      result = select_by_id('657search')[field]
      expect(result).to eq ['657a']

      result = select_by_id('Vern657search')[field]

      expect(result).to eq ['657a']

      expect(results).not_to include hash_including(field => ['657v'])
      expect(results).not_to include hash_including(field => ['657x'])
      expect(results).not_to include hash_including(field => ['657y'])
      expect(results).not_to include hash_including(field => ['657z'])
    end

    it 'has all subfields except v, x, y, z from  658' do
      result = select_by_id('658search')[field]
      expect(result).to eq ['658a 658b 658c 658d']

      result = select_by_id('Vern658search')[field]

      expect(result).to eq ['658a']

      expect(results).not_to include hash_including(field => ['658v'])
      expect(results).not_to include hash_including(field => ['658x'])
      expect(results).not_to include hash_including(field => ['658y'])
      expect(results).not_to include hash_including(field => ['658z'])
    end

    it 'has all subfields except v, x, y, z from  696' do
      result = select_by_id('696search')[field]
      expect(result).to eq ['696a 696b 696c 696d 696e 696f 696g 696h 696j 696k 696l 696m 696n 696o 696p 696q 696r 696s 696t 696u']

      result = select_by_id('Vern696search')[field]

      expect(result).to eq ['696a']

      expect(results).not_to include hash_including(field => ['696v'])
      expect(results).not_to include hash_including(field => ['696x'])
      expect(results).not_to include hash_including(field => ['696y'])
      expect(results).not_to include hash_including(field => ['696z'])
    end

    it 'has all subfields except v, x, y, z from  697' do
      result = select_by_id('697search')[field]
      expect(result).to eq ['697a 697b 697c 697d 697e 697f 697g 697h 697j 697k 697l 697m 697n 697o 697p 697q 697r 697s 697t 697u']

      result = select_by_id('Vern697search')[field]

      expect(result).to eq ['697a']

      expect(results).not_to include hash_including(field => ['697v'])
      expect(results).not_to include hash_including(field => ['697x'])
      expect(results).not_to include hash_including(field => ['697y'])
      expect(results).not_to include hash_including(field => ['697z'])
    end

    it 'has all subfields except v, x, y, z from  698' do
      result = select_by_id('698search')[field]
      expect(result).to eq ['698a 698b 698c 698d 698e 698f 698g 698h 698j 698k 698l 698m 698n 698o 698p 698q 698r 698s 698t 698u']

      result = select_by_id('Vern698search')[field]

      expect(result).to eq ['698a']

      expect(results).not_to include hash_including(field => ['698v'])
      expect(results).not_to include hash_including(field => ['698x'])
      expect(results).not_to include hash_including(field => ['698y'])
      expect(results).not_to include hash_including(field => ['698z'])
    end

    it 'has all subfields except v, x, y, z from  699' do
      result = select_by_id('699search')[field]
      expect(result).to eq ['699a 699b 699c 699d 699e 699f 699g 699h 699j 699k 699l 699m 699n 699o 699p 699q 699r 699s 699t 699u']

      result = select_by_id('Vern699search')[field]

      expect(result).to eq ['699a']

      expect(results).not_to include hash_including(field => ['699v'])
      expect(results).not_to include hash_including(field => ['699x'])
      expect(results).not_to include hash_including(field => ['699y'])
      expect(results).not_to include hash_including(field => ['699z'])
    end

    context 'real data' do
      let(:fixture_name) { 'subjectTests.jsonl' }

      it 'has the right transforms' do
        result = select_by_id('3743949')[field]
        expect(result).to eq ['García Lorca, Federico, 1898-1936.']

        result = select_by_id('7233951')[field]
        expect(result).to eq ['Internet Resource', 'Lectures']

        result = select_by_id('919006')[field]
        expect(result).to eq ['Heliodorus, of Emesa.']

        result = select_by_id('115472')[field]
        expect(result).to eq ['European Economic Community', 'European Economic Community.']

        result = select_by_id('1261173')[field]
        expect(result).to eq [
          'Somers, John Somers, Baron, 1651-1716. Letter ballancing the necessity of keeping a land-force in times of peace, with the dangers that may follow on it.', 'England and Wales. Army.', 'Magna Carta.'
        ]

        result = select_by_id('6552')[field]
        expect(result).to eq ['Dictionaries']

        result = select_by_id('6553')[field]
        expect(result).to eq ['Photoprints', 'Fire Reports']

        result = select_by_id('610atpv')[field]
        expect(result).to eq ['United States Strategic Bombing Survey. Reports. Pacific war']

        expect(results).not_to include hash_including(field => include(/Zhongguo gong chan dang Party work./))
        expect(results).not_to include hash_including(field => include(/atlanta/i))
        expect(results).not_to include hash_including(field => include(/municipal/i))
      end
    end
  end

  describe 'vern_subject_other_search' do
    let(:field) { 'vern_subject_other_search' }

    it 'has all subfields except v, x, y, z from  vern600' do
      result = select_by_id('Vern600search')[field]
      expect(result).to eq ['vern600a vern600b vern600c vern600d vern600e vern600f vern600g vern600h vern600j vern600k vern600l vern600m vern600n vern600o vern600p vern600q vern600r vern600s vern600t vern600u']

      expect(results).not_to include hash_including(field => ['vern600v'])
      expect(results).not_to include hash_including(field => ['vern600x'])
      expect(results).not_to include hash_including(field => ['vern600y'])
      expect(results).not_to include hash_including(field => ['vern600z'])
    end

    it 'has all subfields except v, x, y, z from  vern610' do
      result = select_by_id('Vern610search')[field]
      expect(result).to eq ['vern610a vern610b vern610c vern610d vern610e vern610f vern610g vern610h vern610k vern610l vern610m vern610n vern610o vern610p vern610r vern610s vern610t vern610u']

      expect(results).not_to include hash_including(field => ['vern610v'])
      expect(results).not_to include hash_including(field => ['vern610x'])
      expect(results).not_to include hash_including(field => ['vern610y'])
      expect(results).not_to include hash_including(field => ['vern610z'])
    end

    it 'has all subfields except v, x, y, z from  vern611' do
      result = select_by_id('Vern611search')[field]
      expect(result).to eq ['vern611a vern611c vern611d vern611e vern611f vern611g vern611h vern611j vern611k vern611l vern611n vern611p vern611q vern611s vern611t vern611u']

      expect(results).not_to include hash_including(field => ['vern611v'])
      expect(results).not_to include hash_including(field => ['vern611x'])
      expect(results).not_to include hash_including(field => ['vern611y'])
      expect(results).not_to include hash_including(field => ['vern611z'])
    end

    it 'has all subfields except v, x, y, z from  vern630' do
      result = select_by_id('Vern630search')[field]
      expect(result).to eq ['vern630a vern630d vern630e vern630f vern630g vern630h vern630k vern630l vern630m vern630n vern630o vern630p vern630r vern630s vern630t']

      expect(results).not_to include hash_including(field => ['vern630v'])
      expect(results).not_to include hash_including(field => ['vern630x'])
      expect(results).not_to include hash_including(field => ['vern630y'])
      expect(results).not_to include hash_including(field => ['vern630z'])
    end

    it 'has all subfields except v, x, y, z from 655' do
      result = select_by_id('Vern655search')[field]
      expect(result).to eq ['vern655a vern655b vern655c']

      expect(results).not_to include hash_including(field => ['vern655v'])
      expect(results).not_to include hash_including(field => ['vern655x'])
      expect(results).not_to include hash_including(field => ['vern655y'])
      expect(results).not_to include hash_including(field => ['vern655z'])
    end

    it 'has all subfields except v, x, y, z from 656' do
      result = select_by_id('Vern656search')[field]
      expect(result).to eq ['vern656a vern656k']

      expect(results).not_to include hash_including(field => ['vern656v'])
      expect(results).not_to include hash_including(field => ['vern656x'])
      expect(results).not_to include hash_including(field => ['vern656y'])
      expect(results).not_to include hash_including(field => ['vern656z'])
    end

    it 'has all subfields except v, x, y, z from 657' do
      result = select_by_id('Vern657search')[field]
      expect(result).to eq ['vern657a']

      expect(results).not_to include hash_including(field => ['vern657v'])
      expect(results).not_to include hash_including(field => ['vern657x'])
      expect(results).not_to include hash_including(field => ['vern657y'])
      expect(results).not_to include hash_including(field => ['vern657z'])
    end

    it 'has all subfields except v, x, y, z from 658' do
      result = select_by_id('Vern658search')[field]
      expect(result).to eq ['vern658a vern658b vern658c vern658d']

      expect(results).not_to include hash_including(field => ['vern658v'])
      expect(results).not_to include hash_including(field => ['vern658x'])
      expect(results).not_to include hash_including(field => ['vern658y'])
      expect(results).not_to include hash_including(field => ['vern658z'])
    end

    it 'has all subfields except v, x, y, z from 696' do
      result = select_by_id('Vern696search')[field]
      expect(result).to eq ['vern696a vern696b vern696c vern696d vern696e vern696f vern696g vern696h vern696j vern696k vern696l vern696m vern696n vern696o vern696p vern696q vern696r vern696s vern696t vern696u']

      expect(results).not_to include hash_including(field => ['vern696v'])
      expect(results).not_to include hash_including(field => ['vern696x'])
      expect(results).not_to include hash_including(field => ['vern696y'])
      expect(results).not_to include hash_including(field => ['vern696z'])
    end

    it 'has all subfields except v, x, y, z from 697' do
      result = select_by_id('Vern697search')[field]
      expect(result).to eq ['vern697a vern697b vern697c vern697d vern697e vern697f vern697g vern697h vern697j vern697k vern697l vern697m vern697n vern697o vern697p vern697q vern697r vern697s vern697t vern697u']

      expect(results).not_to include hash_including(field => ['vern697v'])
      expect(results).not_to include hash_including(field => ['vern697x'])
      expect(results).not_to include hash_including(field => ['vern697y'])
      expect(results).not_to include hash_including(field => ['vern697z'])
    end

    it 'has all subfields except v, x, y, z from 698' do
      result = select_by_id('Vern698search')[field]
      expect(result).to eq ['vern698a vern698b vern698c vern698d vern698e vern698f vern698g vern698h vern698j vern698k vern698l vern698m vern698n vern698o vern698p vern698q vern698r vern698s vern698t vern698u']

      expect(results).not_to include hash_including(field => ['vern698v'])
      expect(results).not_to include hash_including(field => ['vern698x'])
      expect(results).not_to include hash_including(field => ['vern698y'])
      expect(results).not_to include hash_including(field => ['vern698z'])
    end

    it 'has all subfields except v, x, y, z from 699' do
      result = select_by_id('Vern699search')[field]
      expect(result).to eq ['vern699a vern699b vern699c vern699d vern699e vern699f vern699g vern699h vern699j vern699k vern699l vern699m vern699n vern699o vern699p vern699q vern699r vern699s vern699t vern699u']

      expect(results).not_to include hash_including(field => ['vern699v'])
      expect(results).not_to include hash_including(field => ['vern699x'])
      expect(results).not_to include hash_including(field => ['vern699y'])
      expect(results).not_to include hash_including(field => ['vern699z'])
    end
  end

  describe 'subject_other_subvy_search' do
    let(:field) { 'subject_other_subvy_search' }

    it 'has subfield v,y from all subject fields' do
      expect(results).to include hash_including('id' => ['600search'], field => ['600v 600y']),
                                 hash_including('id' => ['610search'], field => ['610v 610y']),
                                 hash_including('id' => ['611search'], field => ['611v 611y']),
                                 hash_including('id' => ['630search'], field => ['630v 630y']),
                                 hash_including('id' => ['650search'], field => ['650v 650y']),
                                 hash_including('id' => ['651search'], field => ['651v 651y']),
                                 hash_including('id' => ['654search'], field => ['654v 654y']),
                                 hash_including('id' => ['655search'], field => ['655v 655y']),
                                 hash_including('id' => ['656search'], field => ['656v 656y']),
                                 hash_including('id' => ['657search'], field => ['657v 657y']),
                                 # no sub v in 658
                                 hash_including('id' => ['690search'], field => ['690v 690y']),
                                 hash_including('id' => ['691search'], field => ['691v 691y']),
                                 hash_including('id' => ['696search'], field => ['696v 696y']),
                                 hash_including('id' => ['697search'], field => ['697v 697y']),
                                 hash_including('id' => ['698search'], field => ['698v 698y']),
                                 hash_including('id' => ['699search'], field => ['699v 699y'])

      expect(results).not_to include hash_including(field => /a$/)
    end
    context 'real data' do
      let(:fixture_name) { 'subjectTests.jsonl' }

      it 'has the right transforms' do
        # 651v
        result = select_by_id('6280316')[field]
        expect(result).to eq ['Maps.']
      end
    end

    context 'real era data' do
      let(:fixture_name) { 'eraTests.jsonl' }

      it 'has the right transforms' do
        result = select_by_id('650y')[field]
        expect(result).to eq ['20th century.']

        result = select_by_id('666')[field]
        expect(result).to eq ['20th century']

        result = select_by_id('111')[field]
        expect(result).to eq ['449-1066.']

        result = select_by_id('222')[field]
        expect(result).to eq ['1921-']

        result = select_by_id('777')[field]
        expect(result).to eq ['Roman period, 55 B.C.-449 A.D.']

        result = select_by_id('888')[field]
        expect(result).to eq ['To 449.']

        result = select_by_id('999')[field]
        expect(result).to eq ['To 449 Congresses.']
      end
    end
  end

  describe 'vern_subject_other_subvy_search' do
    let(:field) { 'vern_subject_other_subvy_search' }

    it 'has subfield v,y from all subject fields' do
      expect(results).to include hash_including('id' => ['Vern600search'], field => ['vern600v vern600y']),
                                 hash_including('id' => ['Vern610search'], field => ['vern610v vern610y']),
                                 hash_including('id' => ['Vern611search'], field => ['vern611v vern611y']),
                                 hash_including('id' => ['Vern630search'], field => ['vern630v vern630y']),
                                 hash_including('id' => ['Vern650search'], field => ['vern650v vern650y']),
                                 hash_including('id' => ['Vern651search'], field => ['vern651v vern651y']),
                                 hash_including('id' => ['Vern654search'], field => ['vern654v vern654y']),
                                 hash_including('id' => ['Vern655search'], field => ['vern655v vern655y']),
                                 hash_including('id' => ['Vern656search'], field => ['vern656v vern656y']),
                                 hash_including('id' => ['Vern657search'], field => ['vern657v vern657y']),
                                 # no sub v in 658
                                 hash_including('id' => ['Vern690search'], field => ['vern690v vern690y']),
                                 hash_including('id' => ['Vern691search'], field => ['vern691v vern691y']),
                                 hash_including('id' => ['Vern696search'], field => ['vern696v vern696y']),
                                 hash_including('id' => ['Vern697search'], field => ['vern697v vern697y']),
                                 hash_including('id' => ['Vern698search'], field => ['vern698v vern698y']),
                                 hash_including('id' => ['Vern699search'], field => ['vern699v vern699y'])

      expect(results).not_to include hash_including(field => /a$/)
    end
  end

  describe 'Lane Blacklists' do
    let(:fixture_name) { 'subjectLaneBlacklistTests.jsonl' }
    let(:folio_records) { records.map { |rec| marc_to_folio(rec) } }
    let(:results) { folio_records.map { |rec| indexer.map_record(rec) }.to_a }
    before do
      # Give a LANE-MED holding to all of the records except for a655keepme
      folio_records.each do |folio_record|
        allow(folio_record).to receive(:folio_holdings).and_return([build(:lc_holding, library: 'LANE-MED')]) if folio_record['001'].value != 'a655keepme'
      end
    end

    it 'removes 650a/655a "nomesh", "nomesh." and "nomeshx" from topic_search and topic_facet' do
      expect(results).not_to include hash_including('topic_search' => include(/nomesh/))
      expect(results).not_to include hash_including('topic_facet' => include(/nomesh/))

      result = select_by_id('650a')
      expect(result).to include 'topic_search' => ['I am a rock'], 'topic_facet' => ['I am a rock']
    end

    it 'removes 655a fields from subject_other_search and topic_facet' do
      expect(results).not_to include hash_including('subject_other_search' => include(/internet/i))
      expect(results).not_to include hash_including('subject_other_search' => include(/resource/i))
      expect(results).not_to include hash_including('subject_other_search' => include(/fulltext/i))
      expect(results).not_to include hash_including('subject_other_search' => include(/noexport/i))

      # TODO: does it, though? the solrmarc code doesn't have us mapping that data into topic_facet in the first place
      expect(results).not_to include hash_including('topic_facet' => include(/internet/i))
      expect(results).not_to include hash_including('topic_facet' => include(/resource/i))
      expect(results).not_to include hash_including('topic_facet' => include(/fulltext/i))
      expect(results).not_to include hash_including('topic_facet' => include(/noexport/i))

      expect(select_by_id('655b')).to include 'subject_other_search' => include(/be bee be/)
      expect(select_by_id('655keepme')).to include 'subject_other_search' => include(/keep me/)
    end

    # TODO: does it, though? the solrmarc code doesn't have us mapping that data into topic_facet in the first place
    it 'removes 655b fields from topic_facet' do
      expect(results).not_to include hash_including('topic_facet' => include(/be bee be/))
      expect(results).not_to include hash_including('topic_facet' => include(/keep me/))
    end
  end

  describe 'topic_facet' do
    let(:field) { 'topic_facet' }
    let(:fixture_name) { 'subjectTests.jsonl' }

    it 'has the right transforms' do
      # 600a, trailing period removed
      result = select_by_id('345228')[field]
      expect(result).to eq ['Zemnukhov, Ivan', 'World War, 1939-1945', 'Guerrillas']
      result = select_by_id('11552426')[field]
      expect(result).to eq ["'Abdu'l-Bahá"]
      # 600acd, trailing period removed
      expect(select_by_id('1261173')[field]).to include 'Somers, John Somers, Baron, 1651-1716'
      # 600ad, trailing comma removed
      expect(select_by_id('600trailingComma')[field]).to eq ['Monroe, Marilyn, 1926-1962']
      # 600q now bundled with abcdq
      expect(select_by_id('600aqdx')[field]).to eq ['Kennedy, John F. (John Fitzgerald), 1917-1963']
      # 600t, too few letters at end to remove trailing period
      expect(select_by_id('1261173')[field]).to include 'Letter ballancing the necessity of keeping a land-force in times of peace, with the dangers that may follow on it.' # 630
      # 600ad
      expect(select_by_id('600adtpof')[field]).to include 'Hindemith, Paul, 1895-1963'
      # 600t separate
      expect(select_by_id('600adtpof')[field]).to include 'Nobilissima visione'
      # 610ab, trailing period removed
      expect(select_by_id('1261173')[field]).to include 'England and Wales. Army'
      expect(select_by_id('610trailing')[field]).to eq ['Augusta (Ga.)']
      # 610t separate
      expect(select_by_id('610atpv')[field]).to eq ['United States Strategic Bombing Survey', 'Reports']
      # 630a, trailing period
      expect(select_by_id('1261173')[field]).to include 'Magna Carta'
      # 650a, trailing period
      expect(select_by_id('919006')[field]).to include 'Literature, Comparative'
      # 650a, trailing comma
      expect(select_by_id('650trailingComma')[field]).to eq ['Seabiscuit (Race horse)']
      # 650a, trailing paren left in
      expect(select_by_id('650trailing')[field]).to eq ['BASIC (Computer program language)']
      # 650a, starting percent sign stripped
      expect(select_by_id('1976918')[field]).to eq ['PRIN796', 'Lichfield, Leonard, d. 1657']
      # 650a, redundant-occuring punctuation collapsed
      expect(select_by_id('11623157')[field]).to eq ['(Das) Numinose']
      expect(select_by_id('971078')[field]).to eq ['!Ko (African tribe)']
      # 650a, missing opening or closing parenthesis removed
      expect(select_by_id('9335854')[field]).to eq ['Numerical analysis', 'Ocean waves']
      # 650a, starting asterisk removed
      expect(select_by_id('11146347')[field]).to eq ['2x Devices-- Adiabatic Processes',
                                                     'N70500* --Physics--Controlled Thermonuclear Research-- Kinetics (Theoretical)']

      # 655a, trailing period
      expect(results).not_to include hash_including(field => include(/bust\.?/))
    end
  end

  describe 'geographic_facet' do
    let(:fixture_name) { 'subjectTests.jsonl' }
    let(:field) { 'geographic_facet' }

    context 'a record with multiple 6xx subfield z' do
      let(:records) { [record] }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01952cid  2200457Ia 4500'
          r.append(MARC::DataField.new('600', ' ', ' ',
                                       MARC::Subfield.new('z', 'Stanford'),
                                       MARC::Subfield.new('z', 'Berkeley')))
          r.append(MARC::DataField.new('600', ' ', ' ', MARC::Subfield.new('z', 'San Jose')))
        end
      end

      it 'takes only the first subfield z from a field' do
        expect(results.first[field]).to eq ['Stanford', 'San Jose']
      end
    end

    it 'strips trailing periods' do
      result = select_by_id('651a')[field]
      expect(result).to eq ['Muppets']
      result = select_by_id('651again')[field]
      expect(result).to eq ['Muppets']

      # geographic punctuation shouldn't matter
      result = select_by_id('651numPeriod')[field]
      expect(result).to eq ['7.150']
      result = select_by_id('651parens')[field]
      expect(result).to eq ['Syracuse (N.Y.)']
      result = select_by_id('651siberia')[field]
      expect(result).to eq ['Siberia (Russia)']
    end
  end

  describe 'era_facet' do
    let(:fixture_name) { 'eraTests.jsonl' }
    let(:field) { 'era_facet' }

    it 'removes trailing periods' do
      result = select_by_id('650y')[field]
      expect(result).to eq ['20th century']

      result = select_by_id('666')[field]
      expect(result).to eq ['20th century']
    end

    it 'removes trailing periods after a 3 digit year' do
      result = select_by_id('888')[field]
      expect(result).to eq ['To 449']

      result = select_by_id('999')[field]
      expect(result).to eq ['To 449']
    end

    it 'removes trailing periods after a 4 digit year' do
      result = select_by_id('111')[field]
      expect(result).to eq ['449-1066']
    end

    it 'does not strip trailing dash' do
      result = select_by_id('222')[field]
      expect(result).to eq ['1921-']
    end

    it 'does not strip a trailing period' do
      result = select_by_id('777')[field]
      expect(result).to eq ['Roman period, 55 B.C.-449 A.D.']
    end
  end

  describe 'subject_all_search' do
    let(:field) { 'subject_all_search' }

    it 'contains a single string of all the alphabetic subfields concatenated together' do
      result = select_by_id('600search')[field]
      expect(result).to eq ['600a 600b 600c 600d 600e 600f 600g 600h 600j 600k 600l 600m 600n 600o 600p 600q 600r 600s 600t 600u 600v 600x 600y 600z']

      result = select_by_id('610search')[field]
      expect(result).to eq ['610a 610b 610c 610d 610e 610f 610g 610h 610k 610l 610m 610n 610o 610p 610r 610s 610t 610u 610v 610x 610y 610z']

      result = select_by_id('611search')[field]
      expect(result).to eq ['611a 611c 611d 611e 611f 611g 611h 611j 611k 611l 611n 611p 611q 611s 611t 611u 611v 611x 611y']

      result = select_by_id('630search')[field]
      expect(result).to eq ['630a 630d 630e 630f 630g 630h 630k 630l 630m 630n 630o 630p 630r 630s 630t 630v 630x 630y 630z']

      result = select_by_id('648search')[field]
      expect(result).to eq ['648a 648v 648x 648y 648z']

      result = select_by_id('650search')[field]
      expect(result).to eq ['650a 650b 650c 650d 650e 650v 650x 650y 650z']

      result = select_by_id('651search')[field]
      expect(result).to eq ['651a 651e 651v 651x 651y 651z']

      result = select_by_id('653search')[field]
      expect(result).to eq ['653a']

      result = select_by_id('654search')[field]
      expect(result).to eq ['654a 654b 654c 654e 654v 654y 654z']

      result = select_by_id('655search')[field]
      expect(result).to eq ['655a 655b 655c 655v 655x 655y 655z']

      result = select_by_id('656search')[field]
      expect(result).to eq ['656a 656k 656v 656x 656y 656z']

      result = select_by_id('657search')[field]
      expect(result).to eq ['657a 657v 657x 657y 657z']

      result = select_by_id('658search')[field]
      expect(result).to eq ['658a 658b 658c 658d']

      result = select_by_id('662search')[field]
      expect(result).to eq ['662a 662b 662c 662d 662e 662f 662g 662h']

      result = select_by_id('690search')[field]
      expect(result).to eq ['690a 690b 690c 690d 690e 690v 690x 690y 690z']

      result = select_by_id('691search')[field]
      expect(result).to eq ['691a 691e 691v 691x 691y 691z']

      result = select_by_id('696search')[field]
      expect(result).to eq ['696a 696b 696c 696d 696e 696f 696g 696h 696j 696k 696l 696m 696n 696o 696p 696q 696r 696s 696t 696u 696v 696x 696y 696z']

      result = select_by_id('697search')[field]
      expect(result).to eq ['697a 697b 697c 697d 697e 697f 697g 697h 697j 697k 697l 697m 697n 697o 697p 697q 697r 697s 697t 697u 697v 697x 697y 697z']

      result = select_by_id('698search')[field]
      expect(result).to eq ['698a 698b 698c 698d 698e 698f 698g 698h 698j 698k 698l 698m 698n 698o 698p 698q 698r 698s 698t 698u 698v 698x 698y 698z']

      result = select_by_id('699search')[field]
      expect(result).to eq ['699a 699b 699c 699d 699e 699f 699g 699h 699j 699k 699l 699m 699n 699o 699p 699q 699r 699s 699t 699u 699v 699x 699y 699z']
    end
  end

  describe 'vern_subject_all_search' do
    let(:field) { 'vern_subject_all_search' }

    it 'contains a single string of all the alphabetic subfields concatenated together' do
      result = select_by_id('Vern600search')[field]
      expect(result).to eq ['vern600a vern600b vern600c vern600d vern600e vern600f vern600g vern600h vern600j vern600k vern600l vern600m vern600n vern600o vern600p vern600q vern600r vern600s vern600t vern600u vern600v vern600x vern600y vern600z']

      result = select_by_id('Vern610search')[field]
      expect(result).to eq ['vern610a vern610b vern610c vern610d vern610e vern610f vern610g vern610h vern610k vern610l vern610m vern610n vern610o vern610p vern610r vern610s vern610t vern610u vern610v vern610x vern610y vern610z']

      result = select_by_id('Vern611search')[field]
      expect(result).to eq ['vern611a vern611c vern611d vern611e vern611f vern611g vern611h vern611j vern611k vern611l vern611n vern611p vern611q vern611s vern611t vern611u vern611v vern611x vern611y']

      result = select_by_id('Vern630search')[field]
      expect(result).to eq ['vern630a vern630d vern630e vern630f vern630g vern630h vern630k vern630l vern630m vern630n vern630o vern630p vern630r vern630s vern630t vern630v vern630x vern630y vern630z']

      result = select_by_id('Vern648search')[field]
      expect(result).to eq ['vern648a vern648v vern648x vern648y vern648z']

      result = select_by_id('Vern650search')[field]
      expect(result).to eq ['vern650a vern650b vern650c vern650d vern650e vern650v vern650x vern650y vern650z']

      result = select_by_id('Vern651search')[field]
      expect(result).to eq ['vern651a vern651e vern651v vern651x vern651y vern651z']

      result = select_by_id('Vern653search')[field]
      expect(result).to eq ['vern653a']

      result = select_by_id('Vern654search')[field]
      expect(result).to eq ['vern654a vern654b vern654c vern654e vern654v vern654y vern654z']

      result = select_by_id('Vern655search')[field]
      expect(result).to eq ['vern655a vern655b vern655c vern655v vern655x vern655y vern655z']

      result = select_by_id('Vern656search')[field]
      expect(result).to eq ['vern656a vern656k vern656v vern656x vern656y vern656z']

      result = select_by_id('Vern657search')[field]
      expect(result).to eq ['vern657a vern657v vern657x vern657y vern657z']

      result = select_by_id('Vern658search')[field]
      expect(result).to eq ['vern658a vern658b vern658c vern658d']

      result = select_by_id('Vern662search')[field]
      expect(result).to eq ['vern662a vern662b vern662c vern662d vern662e vern662f vern662g vern662h']

      result = select_by_id('Vern690search')[field]
      expect(result).to eq ['vern690a vern690b vern690c vern690d vern690e vern690v vern690x vern690y vern690z']

      result = select_by_id('Vern691search')[field]
      expect(result).to eq ['vern691a vern691e vern691v vern691x vern691y vern691z']

      result = select_by_id('Vern696search')[field]
      expect(result).to eq ['vern696a vern696b vern696c vern696d vern696e vern696f vern696g vern696h vern696j vern696k vern696l vern696m vern696n vern696o vern696p vern696q vern696r vern696s vern696t vern696u vern696v vern696x vern696y vern696z']

      result = select_by_id('Vern697search')[field]
      expect(result).to eq ['vern697a vern697b vern697c vern697d vern697e vern697f vern697g vern697h vern697j vern697k vern697l vern697m vern697n vern697o vern697p vern697q vern697r vern697s vern697t vern697u vern697v vern697x vern697y vern697z']

      result = select_by_id('Vern698search')[field]
      expect(result).to eq ['vern698a vern698b vern698c vern698d vern698e vern698f vern698g vern698h vern698j vern698k vern698l vern698m vern698n vern698o vern698p vern698q vern698r vern698s vern698t vern698u vern698v vern698x vern698y vern698z']

      result = select_by_id('Vern699search')[field]
      expect(result).to eq ['vern699a vern699b vern699c vern699d vern699e vern699f vern699g vern699h vern699j vern699k vern699l vern699m vern699n vern699o vern699p vern699q vern699r vern699s vern699t vern699u vern699v vern699x vern699y vern699z']
    end
  end

  describe 'marc_collection_title_ssim' do
    let(:field) { 'marc_collection_title_ssim' }
    let(:record) do
      MARC::Record.new.tap do |r|
        r.append(MARC::DataField.new('795', ' ', ' ', MARC::Subfield.new('a', 'Main title'),
                                     MARC::Subfield.new('p', 'A subtitle')))
      end
    end

    it 'includes the title and subtitle from the 795' do
      expect(result[field]).to eq ['Main title A subtitle']
    end
  end

  describe 'vern_marc_collection_title_ssim' do
    let(:field) { 'vern_marc_collection_title_ssim' }
    let(:record) do
      MARC::Record.new.tap do |r|
        r.append(MARC::DataField.new('880', ' ', ' ', MARC::Subfield.new('6', '795-00'),
                                     MARC::Subfield.new('a', 'Main title'), MARC::Subfield.new('p', 'A subtitle')))
      end
    end

    it 'includes the title and subtitle from the 795' do
      expect(result[field]).to eq ['Main title A subtitle']
    end
  end

  describe 'collection_struct' do
    let(:field) { 'collection_struct' }

    let(:record) do
      MARC::Record.new.tap do |r|
        r.append(MARC::DataField.new('795', ' ', ' ', MARC::Subfield.new('a', 'Main title'),
                                     MARC::Subfield.new('p', 'A subtitle')))
        r.append(MARC::DataField.new('880', ' ', ' ', MARC::Subfield.new('6', '795-00'),
                                     MARC::Subfield.new('a', 'Vernacular title')))
      end
    end

    it 'includes the collection title and subtitle' do
      expect(result[field]).to eq [{ title: 'Main title A subtitle', source: 'sirsi' },
                                   { source: 'sirsi', vernacular: 'Vernacular title' }].map(&:to_json)
    end
  end
end
