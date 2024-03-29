# frozen_string_literal: true

RSpec.describe 'Language config' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:records) { MARC::JSONLReader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }
  let(:fixture_name) { 'langTests.jsonl' }
  subject(:results) { records.map { |rec| indexer.map_record(marc_to_folio(rec)) }.to_a }
  let(:field) { 'language' }

  it 'populates the language field' do
    expect(select_by_id('008mul041atha')[field]).to eq ['Thai']
    expect(select_by_id('008eng3041a')[field]).to eq %w[English German Russian]
    expect(select_by_id('008eng2041a041h')[field]).to eq ['English', 'Greek, Ancient (to 1453)']
    expect(select_by_id('008nor041ad')[field]).to match_array %w[Norwegian Swedish]
    expect(results).not_to include(hash_including(field => include('Italian')))

    expect(select_by_id('008spa')[field]).to eq ['Spanish']
    expect(select_by_id('008fre041d')[field]).to eq %w[French Spanish]
  end

  it 'parses out the 041a, which may have multiple languages smushed together', jira: 'SW-364' do
    expect(select_by_id('041aHas3')[field]).to match_array %w[Catalan French Spanish]
  end

  it 'contains values in subfields a, d, e, j  of 041.', jira: 'SW-392' do
    expect(select_by_id('041subfields')[field]).to match_array %w[Afar Abkhaz Adangme Adygei Afrikaans
                                                                  Ainu Amharic Angika]
  end
end
