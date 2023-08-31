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

  let(:fixture_name) { 'a11384345.json' }
  let(:record) { FolioRecord.new(JSON.parse(file_fixture(fixture_name).read)) }

  it 'indexes instructor names for searching' do
    expect(result['crez_instructor_search']).to eq ['Alicia Thesing', 'Brandi Lupo', 'Marc Fagel', 'Nicholas Handler', 'Robin Linsenmayer', 'Seema Patel', 'Susan Yorke', 'Tyler Valeska']
  end

  it 'indexes course names for searching' do
    expect(result['crez_course_name_search']).to eq ['Legal Writing']
  end

  it 'indexes course IDs for searching' do
    expect(result['crez_course_id_search']).to eq %w[LAW-219-01 LAW-219-02 LAW-219-03 LAW-219-04 LAW-219-05 LAW-219-06]
  end

  it 'indexes course info by individual instructor and ID' do
    expect(result['crez_course_info']).to eq [
      'LAW-219-01 -|- Legal Writing -|- Marc Fagel',
      'LAW-219-01 -|- Legal Writing -|- Tyler Valeska',
      'LAW-219-02 -|- Legal Writing -|- Nicholas Handler',
      'LAW-219-02 -|- Legal Writing -|- Robin Linsenmayer',
      'LAW-219-03 -|- Legal Writing -|- Alicia Thesing',
      'LAW-219-04 -|- Legal Writing -|- Brandi Lupo',
      'LAW-219-05 -|- Legal Writing -|- Seema Patel',
      'LAW-219-06 -|- Legal Writing -|- Susan Yorke'
    ]
  end

  describe 'the items in the item_display_struct field' do
    # Filter to an item that's on reserve so we can check its item_display
    subject(:item_display) do
      item_displays = result['item_display_struct'].map { |item| JSON.parse(item) }
      item_displays.find { |item| item['barcode'] == '36105230980901' }
    end

    it 'adds the course ID, reserve desk, and loan period' do
      expect(item_display).to include('course_id' => 'LAW-219-04',
                                      'reserve_desk' => 'LAW-CRES',
                                      'loan_period' => '2-hour loan')
    end
  end
end
