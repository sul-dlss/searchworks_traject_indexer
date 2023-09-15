# frozen_string_literal: true

RSpec.describe 'Holdings config' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:folio_record) { FolioRecord.new(folio_data, instance_double(FolioClient)) }
  let(:result) { indexer.map_record(folio_record) }
  let(:folio_data) { JSON.parse(file_fixture(fixture_file).read) }

  describe 'mhld_display' do
    let(:field) { 'mhld_display' }
    subject(:value) { result[field] }
    context 'for a2499' do
      let(:fixture_file) { 'a2499.json' }

      it {
        is_expected.to eq [
          'MUSIC -|- STACKS -|-  -|- v.1 -|- ',
          'MUSIC -|- STACKS -|-  -|- v.2 -|- '
        ]
      }
    end

    context 'for a9012' do
      let(:fixture_file) { 'a9012.json' }

      it {
        is_expected.to eq [
          'SAL3 -|- STACKS -|-  -|- 1948,1965-1967,1974-1975 -|- '
        ]
      }
    end

    context 'for a1572' do
      let(:fixture_file) { 'a1572.json' }

      it {
        is_expected.to eq [
          'SAL3 -|- STACKS -|-  -|- Heft 1-2 <v.568-569 in series> -|- '
        ]
      }
    end

    context 'for a7770475' do
      let(:fixture_file) { 'a7770475.json' }

      it "doesn't raise an error" do
        expect { value }.not_to raise_error
      end
    end
  end

  describe 'mhld_display_struct' do
    let(:field) { 'mhld_display_struct' }
    subject(:value) { result[field].map { |row| JSON.parse(row) } }

    context 'for a2499' do
      let(:fixture_file) { 'a2499.json' }

      it {
        is_expected.to eq [
          {
            'MUSIC' => {
              'location_holdings' => {
                'MUS-STACKS' => {
                  'holdings' => [
                    { 'library_has' => 'v.1' },
                    { 'library_has' => 'v.2' }
                  ],
                  'latest' => nil,
                  'symphony_location' => 'STACKS'
                }
              },
              'symphony_library' => 'MUSIC'
            }
          }
        ]
      }
    end

    context 'for a9012' do
      let(:fixture_file) { 'a9012.json' }

      it {
        is_expected.to eq [
          {
            'SAL3' => {
              'location_holdings' => {
                'SAL3-STACKS' => {
                  'holdings' => [
                    { 'library_has' => '1948,1965-1967,1974-1975' }
                  ],
                  'latest' => nil,
                  'symphony_location' => 'STACKS'
                }
              },
              'symphony_library' => 'SAL3'
            }
          }
        ]
      }
    end

    context 'for a1572' do
      let(:fixture_file) { 'a1572.json' }

      it {
        is_expected.to eq [
          {
            'SAL3' => {
              'location_holdings' => {
                'SAL3-STACKS' => {
                  'holdings' => [
                    { 'library_has' => 'Heft 1-2 <v.568-569 in series>' }
                  ],
                  'latest' => nil,
                  'symphony_location' => 'STACKS'
                }
              },
              'symphony_library' => 'SAL3'
            }
          }
        ]
      }
    end

    context 'for a7770475' do
      let(:fixture_file) { 'a7770475.json' }

      it "doesn't raise an error" do
        expect { value }.not_to raise_error
      end
    end
  end
end
