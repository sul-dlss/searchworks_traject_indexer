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

  it 'indexes folio course IDs' do
    expect(result['courses_folio_id_ssim']).to eq %w[32f1eff1-8560-4854-b8dc-82ad06da6377 edee91dc-7617-45fc-bf8d-705468378ac6
                                                     f3b772be-5d5e-4823-a624-ff23150e66d3 af56597c-afe8-4e71-8645-a520807d2dec
                                                     86b00ffa-d126-4069-8b99-0c08e3ee1335 b72594a9-8d48-40e6-9190-f994d8000517]
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

  it 'indexes course info as a structured field' do
    expect(result['courses_json_struct']).to match_array [
      { 'course_name' => 'Legal Writing', 'course_id' => 'LAW-219-01', 'folio_course_id' => 'f3b772be-5d5e-4823-a624-ff23150e66d3', 'instructors' => ['Marc Fagel', 'Tyler Valeska'], 'reserve_desk' => 'LAW-CRES' }.to_json,
      { 'course_name' => 'Legal Writing', 'course_id' => 'LAW-219-02', 'folio_course_id' => '86b00ffa-d126-4069-8b99-0c08e3ee1335', 'instructors' => ['Nicholas Handler', 'Robin Linsenmayer'], 'reserve_desk' => 'LAW-CRES' }.to_json,
      { 'course_name' => 'Legal Writing', 'course_id' => 'LAW-219-03', 'folio_course_id' => 'b72594a9-8d48-40e6-9190-f994d8000517', 'instructors' => ['Alicia Thesing'], 'reserve_desk' => 'LAW-CRES' }.to_json,
      { 'course_name' => 'Legal Writing', 'course_id' => 'LAW-219-04', 'folio_course_id' => '32f1eff1-8560-4854-b8dc-82ad06da6377', 'instructors' => ['Brandi Lupo'], 'reserve_desk' => 'LAW-CRES' }.to_json,
      { 'course_name' => 'Legal Writing', 'course_id' => 'LAW-219-05', 'folio_course_id' => 'edee91dc-7617-45fc-bf8d-705468378ac6', 'instructors' => ['Seema Patel'], 'reserve_desk' => 'LAW-CRES' }.to_json,
      { 'course_name' => 'Legal Writing', 'course_id' => 'LAW-219-06', 'folio_course_id' => 'af56597c-afe8-4e71-8645-a520807d2dec', 'instructors' => ['Susan Yorke'], 'reserve_desk' => 'LAW-CRES' }.to_json
    ]
  end
end
