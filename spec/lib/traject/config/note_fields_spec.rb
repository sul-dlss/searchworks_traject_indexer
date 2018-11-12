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

  describe 'toc_struct' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    let(:fixture_name) { 'summaryTests.mrc' }
    let(:field) { 'toc_struct'}

    it 'maps the right fields' do
      result = select_by_id('505')[field].map { |x| JSON.parse(x, symbolize_names: true) }
      expect(result).to include hash_including(fields: [array_including('505a')], label: 'Contents', unmatched_vernacular: nil, vernacular: [array_including(/^vern505a/)])
    end

    context 'with Nielson data' do
      let(:records) { [record] }
      let(:record) { nil }
      let(:result) { results.first }
      let(:result_field) { result[field].map { |x| JSON.parse(x, symbolize_names: true) } }

      context 'with a link in a $u' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '505', ' ', ' ',
                MARC::Subfield.new('a', 'YUGOSLAV SERIAL 1973'),
                MARC::Subfield.new('u', 'https://example.com')
              )
            )
          end
        end

        it 'structures the output' do
          expect(result_field.first[:fields].first).to eq ['YUGOSLAV SERIAL 1973', 'https://example.com']
        end
      end

      context 'with data in just the 905' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '905', ' ', ' ',
                MARC::Subfield.new('a', 'YUGOSLAV SERIAL 1973')
              )
            )
          end
        end

        it 'structures the output' do
          expect(result_field.first[:fields].first).to eq ['YUGOSLAV SERIAL 1973']
        end
      end

      context 'with incomplete data in the 505' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '505', ' ', ' ',
                MARC::Subfield.new('a', 'missing a $r or $t')
              )
            )
            r.append(
              MARC::DataField.new(
                '905', ' ', ' ',
                MARC::Subfield.new('a', 'YUGOSLAV SERIAL 1973')
              )
            )
          end
        end

        it 'structures the output' do
          expect(result_field.first[:fields].first).to eq ['YUGOSLAV SERIAL 1973']
        end
      end

      context 'with Nielsen-sourced data' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '905', ' ', ' ',
                MARC::Subfield.new('1', 'Nielsen'),
                MARC::Subfield.new('x', '12345678'),
              )
            )
          end
        end

        it 'structures the output and suppresses $x data' do
          expect(result_field.first[:fields].first).to eq ['(source: Nielsen Book Data)']
        end
      end

      context 'with delimited data' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '505', ' ', ' ',
                MARC::Subfield.new('a', 'aaa -- bbb -- ccc')
              )
            )
          end
        end

        it 'structures the output' do
          expect(result_field.first[:fields].first).to eq ['aaa', 'bbb', 'ccc']
        end
      end

      context 'with data in separate subfields' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '505', ' ', ' ',
                MARC::Subfield.new('t', 'Basics of the law and legal system /'),
                MARC::Subfield.new('r', 'Ronald Schouten --'),
                MARC::Subfield.new('t', 'Civil commitment /'),
                MARC::Subfield.new('r', 'Ronald Schouten and Philip J. Candilis --')
              )
            )
          end
        end

        it 'structures the output' do
          expect(result_field.first[:fields].first).to eq ['Basics of the law and legal system / Ronald Schouten', 'Civil commitment / Ronald Schouten and Philip J. Candilis']
        end
      end

      context 'with data in separate subfields separated by a $1' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '505', ' ', ' ',
                MARC::Subfield.new('t', 'first'),
                MARC::Subfield.new('1', 'Nielsen'),
                MARC::Subfield.new('r', 'last')
              )
            )
          end
        end

        it 'outputs the values in the order they appear' do
          expect(result_field.first[:fields].first).to eq ['first', '(source: Nielsen Book Data)', 'last']
        end
      end

      context 'with an unknown $1' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '505', ' ', ' ',
                MARC::Subfield.new('1', 'garbage value')
              )
            )
          end
        end

        it 'ignores the data' do
          expect(result_field.first[:fields].first).to eq []
        end
      end
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

  describe 'summary_struct' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    let(:fixture_name) { 'summaryTests.mrc' }
    let(:field) { 'summary_struct'}

    it 'maps the right fields' do
      result = select_by_id('520')[field].map { |x| JSON.parse(x, symbolize_names: true) }
      expect(result.first[:label]).to eq 'Summary'
      expect(result.first[:fields].first[:field]).to include '520a', '520b'
    end

    context 'with Nielson data' do
      let(:fixture_name) { 'nielsenTests.mrc' }
      it 'maps the right fields' do
        result = select_by_id('920')[field].map { |x| JSON.parse(x, symbolize_names: true) }
        expect(result.first[:label]).to eq 'Publisher\'s Summary'
        expect(result.first[:fields].first[:field]).to include '920a', '920b'
      end
    end

    context 'with a link in a $u' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(
            MARC::DataField.new(
              '520', ' ', ' ',
              MARC::Subfield.new('a', 'YUGOSLAV SERIAL 1973'),
              MARC::Subfield.new('u', 'https://example.com')
            )
          )
        end
      end
      let(:result_field) { result[field].map { |x| JSON.parse(x, symbolize_names: true) } }

      it 'structures the output' do
        expect(result_field.first[:fields].first[:field]).to eq ['YUGOSLAV SERIAL 1973', { link: 'https://example.com' }]
      end
    end

    context 'with Nielsen-sourced data' do
      subject(:result) { indexer.map_record(record) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(
            MARC::DataField.new(
              '920', ' ', ' ',
              MARC::Subfield.new('1', 'Nielsen')
            )
          )
        end
      end
      let(:result_field) { result[field].map { |x| JSON.parse(x, symbolize_names: true) } }

      it 'structures the output' do
        expect(result_field.first[:fields].first[:field]).to eq [{ source: '(source: Nielsen Book Data)' }]
      end
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
