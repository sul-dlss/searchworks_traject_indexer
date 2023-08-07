# frozen_string_literal: true

RSpec.describe 'FOLIO course reserves config' do
  include ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.settings['reader_class_name'] = 'Traject::FolioJsonReader'
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:fixture_name) { 'whodunit.json' }
  let(:record) { FolioRecord.new(JSON.parse(file_fixture(fixture_name).read)) }

  it 'indexes instructor names for searching' do
    expect(result['crez_instructor_search']).to eq ['Emily Levine', 'Mitchell Stevens']
  end

  it 'indexes course names for searching' do
    expect(result['crez_course_name_search']).to eq ['Stanford and Its Worlds: 1885-present']
  end

  it 'indexes course IDs for searching' do
    expect(result['crez_course_id_search']).to eq %w[HISTORY-58E-01 EDUC-147-01]
  end

  it 'indexes course info by individual instructor and ID' do
    expect(result['crez_course_info']).to eq [
      'HISTORY-58E-01 -|- Stanford and Its Worlds: 1885-present -|- Emily Levine',
      'HISTORY-58E-01 -|- Stanford and Its Worlds: 1885-present -|- Mitchell Stevens',
      'EDUC-147-01 -|- Stanford and Its Worlds: 1885-present -|- Emily Levine',
      'EDUC-147-01 -|- Stanford and Its Worlds: 1885-present -|- Mitchell Stevens'
    ]
  end

  describe 'the items in the item_display_struct field' do
    # Filter to the item that's on reserve so we can check its item_display
    subject(:item_display) do
      item_displays = result['item_display_struct'].map { |item| JSON.parse(item) }
      item_displays.find { |item| item['barcode'] == '36105232609540' }
    end

    it 'adds the course ID, reserve desk, and loan period' do
      expect(item_display).to include('course_id' => 'HISTORY-58E-01',
                                      'reserve_desk' => 'GRE-CRES',
                                      'loan_period' => '2-hour loan')
    end
  end
end
