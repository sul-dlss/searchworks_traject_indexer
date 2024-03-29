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
          'MUSIC -|- MUS-STACKS -|-  -|- v.1 -|- ',
          'MUSIC -|- MUS-STACKS -|-  -|- v.2 -|- '
        ]
      }
    end

    context 'for a9012' do
      let(:fixture_file) { 'a9012.json' }

      it {
        is_expected.to eq [
          'SAL3 -|- SAL3-STACKS -|-  -|- 1948,1965-1967,1974-1975 -|- '
        ]
      }
    end

    context 'for a1572' do
      let(:fixture_file) { 'a1572.json' }

      it {
        is_expected.to eq [
          'SAL3 -|- SAL3-STACKS -|-  -|- Heft 1-2 <v.568-569 in series> -|- '
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
