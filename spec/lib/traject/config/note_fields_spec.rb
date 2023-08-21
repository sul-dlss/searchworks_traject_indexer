# frozen_string_literal: true

RSpec.describe 'Sirsi config' do
  subject(:result) { indexer.map_record(stub_record_from_marc(record)) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/marc_config.rb')
    end
  end
  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }

  describe 'toc_search' do
    subject(:results) { records.map { |rec| indexer.map_record(stub_record_from_marc(rec)) }.to_a }
    let(:fixture_name) { 'summaryTests.mrc' }
    let(:field) { 'toc_search' }

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
    subject(:results) { records.map { |rec| indexer.map_record(stub_record_from_marc(rec)) }.to_a }
    let(:fixture_name) { 'summaryTests.mrc' }
    let(:field) { 'vern_toc_search' }

    it 'maps the right fields' do
      result = select_by_id('505')[field]
      expect(result).to eq ['vern505a vern505r vern505t']

      expect(results).not_to include hash_including(field => ['nope'])
    end

    context 'with vernacular in the 505' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(
            MARC::DataField.new(
              '505', '0', '0',
              MARC::Subfield.new('a', '本书在综合考察绘画,文人,禅学这三者相互关联的基础上.')
            )
          )
        end
      end

      it 'maps the data' do
        expect(result).to include field => ['本书在综合考察绘画,文人,禅学这三者相互关联的基础上.']
      end
    end
  end

  describe 'toc_struct' do
    subject(:results) { records.map { |rec| indexer.map_record(stub_record_from_marc(rec)) }.to_a }
    let(:fixture_name) { 'summaryTests.mrc' }
    let(:field) { 'toc_struct' }

    it 'maps the right fields' do
      result = select_by_id('505')[field].map { |x| JSON.parse(x, symbolize_names: true) }
      expect(result).to include hash_including(fields: [array_including('505a')], label: 'Contents',
                                               unmatched_vernacular: nil, vernacular: [array_including(/^vern505a/)])
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

      context 'with a partial indicator in the 505' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '505', '2', ' '
              )
            )
          end
        end

        it 'uses the label Partial contents' do
          expect(result_field.first[:label]).to eq 'Partial contents'
        end
      end

      context 'with an incomplete indicator in the 505' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '505', '1', ' '
              )
            )
          end
        end

        it 'uses the label Partial contents' do
          expect(result_field.first[:label]).to eq 'Partial contents'
        end
      end

      context 'with no indicator in the 505' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '505', ' ', ' '
              )
            )
          end
        end

        it 'uses the label Contents' do
          expect(result_field.first[:label]).to eq 'Contents'
        end
      end

      context 'with Nielsen-sourced data' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '905', ' ', ' ',
                MARC::Subfield.new('1', 'Nielsen'),
                MARC::Subfield.new('x', '12345678')
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
          expect(result_field.first[:fields].first).to eq %w[aaa bbb ccc]
        end
      end

      context 'with vernacular toc data' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(MARC::DataField.new(
                       '505', ' ', ' ',
                       MARC::Subfield.new('a', 'aaa -- bbb -- ccc'),
                       MARC::Subfield.new('6', '880-04')
                     ))
            r.append(MARC::DataField.new(
                       '880', ' ', ' ',
                       MARC::Subfield.new('a', 'v. 1. 土偶--v. 2. 仏像--v. 3. 銅器, 玉器.'),
                       MARC::Subfield.new('6', '505-04')
                     ))
          end
        end

        it 'structures the output' do
          expect(result_field.first[:fields].first).to eq %w[aaa bbb ccc]
          expect(result_field.first[:vernacular].first).to eq ['v. 1. 土偶--', 'v. 2. 仏像--', 'v. 3. 銅器, 玉器.']
        end
      end

      context 'with numbers that should not be split on in the data' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '505', ' ', ' ',
                MARC::Subfield.new('a', 'aaa -- Word 10 Another Word -- ccc')
              )
            )
          end
        end

        it 'does not split on a number that is not intended to be the beginning of a new chapter/line' do
          expect(result_field.first[:fields].first).to eq ['aaa', 'Word 10 Another Word', 'ccc']
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
          expect(result_field.first[:fields].first).to eq ['Basics of the law and legal system / Ronald Schouten',
                                                           'Civil commitment / Ronald Schouten and Philip J. Candilis']
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

      context 'with a CD liner' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '505', ' ', ' ',
                MARC::Subfield.new('a', <<-EOTOC
                  Op. 12, book 1. No. 1, Arietta (1:20) ; No. 2, Waltz (2:03) ; No. 6, Norwegian melody (0:52) ; No. 5, Folk melody (1:30) -- Op. 38, book 2. No. 8, Canon (4:57) ; No. 6, Elegy (2:18) ; No. 7, Waltz (1:05) -- Op. 47, book 4. No. 3, Melody (3:06) -- Op. 54, book 5. No. 3, March of the trolls (2:57) ; No. 4, Notturno (4:17) -- Op. 57, book 6. No. 2, Gade (2:59) ; No. 3, Illusion (3:37) ; No. 6, Homesickness (4:58) -- Op. 62, book 7. No. 6, Homeward (2:48) ; No. 4, The brook (1:26) ; No. 5, Phantom (2:30) ; No. 1, Sylph (1:22) -- Op. 68, book 9. No. 5, Cradle song (3:02) -- Op. 65, book 8. No. 6, Wedding day at Troldhaugen (6:25) -- Op. 68, book 9. No. 4, Evening in the mountains (3:52) ; No. 3, At your feet (3:24) -- Op. 71, book 10. No. 2, Summer evening (2:34) ; No. 6, Gone (2:48) ; No. 7, Remembrances (2:00).
                EOTOC
                )
              )
            )
          end
        end

        it 'splits only on the --' do
          expect(result_field.first[:fields].first).to include 'Op. 12, book 1. No. 1, Arietta (1:20) ; No. 2, Waltz (2:03) ; No. 6, Norwegian melody (0:52) ; No. 5, Folk melody (1:30)',
                                                               'Op. 38, book 2. No. 8, Canon (4:57) ; No. 6, Elegy (2:18) ; No. 7, Waltz (1:05)'
        end
      end

      context 'with an eresource' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '505', ' ', ' ',
                MARC::Subfield.new('a', toc)
              )
            )
          end
        end

        let(:toc) do
          '1 Introduction 9      1.1 Human Body - Kinematic Perspective 10      1.2 Musculoskeletal Injuries and Neurological Movement Disorders 11      1.2.1 Musculoskeletal injuries 11      '
        end

        it 'splits on chapter numbers' do
          expect(result_field.first[:fields].first).to include '1 Introduction 9',
                                                               '1.1 Human Body - Kinematic Perspective 10'
        end
      end

      context 'with chapters with colons' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '905', ' ', ' ',
                MARC::Subfield.new('a', toc)
              )
            )
          end
        end

        let(:toc) do
          'Preface  Part I: Fundamentals  1: Energy in Thermal Physics  2: The Second Law  3: Interactions and Implications  Part II: Thermodynamics  4: Engines and Refrigerators  5: Free Energy and Chemical Thermodynamics  Part III: Statistical Mechanics  6: Boltzmann Statistics  7: Quantum Statistics  8: Systems of Interacting Particles  Appendix A: Elements of Quantum Mechanics  Appendix B: Mathematical Results  Suggested Reading  Reference Data  Index.' # rubocop:disable Layout/LineLength
        end

        it 'splits on chapter numbers' do
          expect(result_field.first[:fields].first).not_to include '1:'
          expect(result_field.first[:fields].first).to include '1: Energy in Thermal Physics'
        end
      end

      context 'with a -- delimiter without a preceding whitespace character' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '505', ' ', ' ',
                MARC::Subfield.new('a', toc)
              )
            )
          end
        end

        let(:toc) do
          '7. Crusader art in the reign of Queen Melisende and King Baldwin III: 1143-1163: The church of the Holy Sepulchre in Jerusalem-- 8. Crusader art in the reign of Queen Melisende and King Baldwin III: 1143-1163: Jerusalem and the Latin Kingdom:' # rubocop:disable Layout/LineLength
        end

        it 'splits on chapter numbers' do
          expect(result_field.first[:fields].first).to include '7. Crusader art in the reign of Queen Melisende and King Baldwin III: 1143-1163: The church of the Holy Sepulchre in Jerusalem',
                                                               '8. Crusader art in the reign of Queen Melisende and King Baldwin III: 1143-1163: Jerusalem and the Latin Kingdom:'
        end
      end

      context 'with double-digit chapter numbers' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '505', ' ', ' ',
                MARC::Subfield.new('a', toc)
              )
            )
          end
        end

        let(:toc) do
          '9. Global Nonlinear Techniques 10. Closed Orbits and Limit Sets 11. Applications in Biology'
        end

        it 'splits on chapter numbers' do
          expect(result_field.first[:fields].first).to include '9. Global Nonlinear Techniques',
                                                               '10. Closed Orbits and Limit Sets', '11. Applications in Biology'
        end
      end
    end

    context 'with unmatched vernacular' do
      let(:records) { [record] }
      let(:record) { nil }
      let(:result) { results.first }
      let(:result_field) { result[field].map { |x| JSON.parse(x, symbolize_names: true) } }

      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(
            MARC::DataField.new(
              '880', '0', '0',
              MARC::Subfield.new('6', '505-00'),
              MARC::Subfield.new('g', '001-026.'),
              MARC::Subfield.new('t', '水浒传(全26册) --'),
              MARC::Subfield.new('g', '027-041.'),
              MARC::Subfield.new('t', '岳飞传(全15册) --'),
              MARC::Subfield.new('g', '042-046.'),
              MARC::Subfield.new('t', '杨家将(全5册) --')
            )
          )
        end
      end

      it 'maps the right fields' do
        expect(result_field.first[:unmatched_vernacular].first).to eq ['001-026. 水浒传(全26册)', '027-041. 岳飞传(全15册)',
                                                                       '042-046. 杨家将(全5册) --']
      end
    end
  end

  describe 'context_search' do
    subject(:results) { records.map { |rec| indexer.map_record(stub_record_from_marc(rec)) }.to_a }
    let(:fixture_name) { 'summaryTests.mrc' }
    let(:field) { 'context_search' }

    it 'maps the right fields' do
      result = select_by_id('518')[field]
      expect(result).to eq ['518a']

      expect(results).not_to include hash_including(field => ['nope'])
    end
  end

  describe 'vern_context_search' do
    subject(:results) { records.map { |rec| indexer.map_record(stub_record_from_marc(rec)) }.to_a }
    let(:fixture_name) { 'summaryTests.mrc' }
    let(:field) { 'vern_context_search' }

    it 'maps the right fields' do
      result = select_by_id('518')[field]
      expect(result).to eq ['vern518a']

      expect(results).not_to include hash_including(field => ['nope'])
    end
  end

  describe 'summary_search' do
    subject(:results) { records.map { |rec| indexer.map_record(stub_record_from_marc(rec)) }.to_a }
    let(:fixture_name) { 'summaryTests.mrc' }
    let(:field) { 'summary_search' }

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
    subject(:results) { records.map { |rec| indexer.map_record(stub_record_from_marc(rec)) }.to_a }
    let(:fixture_name) { 'summaryTests.mrc' }
    let(:field) { 'vern_summary_search' }

    it 'maps the right fields' do
      result = select_by_id('520')[field]
      expect(result).to eq ['vern520a vern520b']

      expect(results).not_to include hash_including(field => ['nope'])
    end

    context 'with vernacular in the 520' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(
            MARC::DataField.new(
              '520', '0', '0',
              MARC::Subfield.new('a', '本书在综合考察绘画,文人,禅学这三者相互关联的基础上.')
            )
          )
        end
      end

      it 'maps the data' do
        expect(result).to include field => ['本书在综合考察绘画,文人,禅学这三者相互关联的基础上.']
      end
    end
  end

  describe 'summary_struct' do
    subject(:results) { records.map { |rec| indexer.map_record(stub_record_from_marc(rec)) }.to_a }
    let(:fixture_name) { 'summaryTests.mrc' }
    let(:field) { 'summary_struct' }

    it 'maps the right fields' do
      result = select_by_id('520')[field].map { |x| JSON.parse(x, symbolize_names: true) }
      expect(result.first[:label]).to eq 'Summary'
      expect(result.first[:fields].first[:field]).to include '520a', '520b'
    end

    context 'with unmatched vernacular' do
      let(:records) { [record] }
      let(:record) { nil }
      let(:result) { results.first }
      let(:result_field) { result[field].map { |x| JSON.parse(x, symbolize_names: true) } }

      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(
            MARC::DataField.new(
              '880', '0', '0',
              MARC::Subfield.new('6', '520-00'),
              MARC::Subfield.new('a', '本书在综合考察绘画,文人,禅学这三者相互关联的基础上.')
            )
          )
        end
      end

      it 'maps the right fields' do
        expect(result_field.first[:unmatched_vernacular]).to eq ['本书在综合考察绘画,文人,禅学这三者相互关联的基础上.']
      end
    end

    context 'with Nielson data' do
      let(:fixture_name) { 'nielsenTests.mrc' }
      it 'maps the right fields' do
        result = select_by_id('920')[field].map { |x| JSON.parse(x, symbolize_names: true) }
        expect(result.first[:label]).to eq 'Publisher\'s summary'
        expect(result.first[:fields].first[:field]).to include '920a', '920b'
      end
    end

    context 'with a link in a $u' do
      subject(:result) { indexer.map_record(stub_record_from_marc(record)) }
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
        expect(result_field.first[:fields].first[:field]).to eq ['YUGOSLAV SERIAL 1973',
                                                                 { link: 'https://example.com' }]
      end
    end

    context 'with Nielsen-sourced data' do
      subject(:result) { indexer.map_record(stub_record_from_marc(record)) }
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

    context 'with content advice' do
      subject(:result) { indexer.map_record(stub_record_from_marc(record)) }
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(
            MARC::DataField.new(
              '520', '4', ' ',
              MARC::Subfield.new('a', 'Content warning: Contains horrible things')
            )
          )
        end
      end
      let(:result_field) { result[field].map { |x| JSON.parse(x, symbolize_names: true) } }

      it 'maps the right field values' do
        expect(result_field.last[:fields].first[:field]).to eq ['Content warning: Contains horrible things']
      end

      it 'sets the right label' do
        expect(result_field.last[:label]).to eq 'Content advice'
      end
    end
  end

  describe 'award_search' do
    subject(:results) { records.map { |rec| indexer.map_record(stub_record_from_marc(rec)) }.to_a }
    let(:fixture_name) { 'nielsenTests.mrc' }
    let(:field) { 'award_search' }

    it 'maps the right fields' do
      result = select_by_id('586')[field]
      expect(result).to eq ['New Zealand Post book awards winner', '586 second award']

      result = select_by_id('986')[field]
      expect(result).to eq ['Shortlisted for Montana New Zealand Book Awards: History Category 2006.',
                            '986 second award']

      result = select_by_id('one586two986')[field]
      expect(result).to eq ['586 award', '986 award1', '986 award2']

      result = select_by_id('two586one986')[field]
      expect(result).to eq ['586 1award', '586 2award', '986 single award']
    end
  end
end
