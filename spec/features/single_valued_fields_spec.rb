RSpec.describe 'Single valued fields' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end
  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }
  let(:single_valued_fields) do
    %w[title_245a_search title_245_search title_uniform_search vern_title_uniform_search title_full_display all_search vern_all_search]
  end

  context 'Arabic example' do
    let(:fixture_name) { '41022.marc' }
    it 'fields are all single valued' do
      single_valued_fields.each do |field|
        expect(result[field].length).to eq 1
      end
    end
    it { expect(result['title_245a_search'].first).to eq "Epître sur l'unité et la Trinité :" }
    it { expect(result['title_245_search'].first).to eq "Epître sur l'unité et la Trinité : Traité sur l'intellect, Fragment sur l'ame /" }
    it { expect(result['title_uniform_search'].first).to eq "Ashraf al-ḥadīth fī sharaf al-tawḥīd wa-al-tathlīth" }
    it { expect(result['vern_title_uniform_search'].first).to eq "أشرف الحديث في شرف التوحيد والتثليث" }
    it { expect(result['title_full_display'].first).to eq "Epître sur l'unité et la Trinité : Traité sur l'intellect, Fragment sur l'ame / texte arabe édité, traduit et annoté par M. Allard et G. Troupeau." }
  end
  context 'Japanese example' do
    let(:fixture_name) { '44794.marc' }
    it 'fields are all single valued' do
      single_valued_fields.each do |field|
        expect(result[field].length).to eq 1
      end
    end
    it { expect(result['title_245a_search'].first).to eq "Annotated economic statistics of Japan for postwar years up to 1958 /" }
    it { expect(result['title_245_search'].first).to eq "Annotated economic statistics of Japan for postwar years up to 1958 /" }
    it { expect(result['title_uniform_search'].first).to eq "Kaisetsu Nihon keizai tōkei" }
    it { expect(result['vern_title_uniform_search'].first).to eq "解說日本経済統計" }
    it { expect(result['title_full_display'].first).to eq "Annotated economic statistics of Japan for postwar years up to 1958 / The Institute of Economic Research, Hitotusubashi University." }
  end
end
