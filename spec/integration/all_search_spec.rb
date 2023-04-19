# frozen_string_literal: true

RSpec.describe 'All_search integration' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end
  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:fixture_name) { '100017.marc' }
  let(:record) { records.first }
  subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }

  describe 'all_search' do
    let(:field) { 'all_search' }
    it do
      expect(select_by_id('100017')[field][0]).to eq 'Zohar Selections. Hebrew. ^A968827 880-01 Mishnat ha-Zohar : gufe maʼamare ha-Zohar / mesudarim le-fi ha-ʻinyanim u-meturgamim ʻivrit bi-yede F. Laḥover ṿi-Yeshʻayah Tishbi ; be-tseruf beʼurim mevoʼot ṿe-ḥilufe nusḥaʼot meʼet Yeshʻayah Tishbi. Wisdom of the Zohar : texts from the Book of Splendour Mishnat ha-Zohar : gufe maʼamare ha-Zohar : kerekh ha-maftehot /  ʻarakh: Avriʼel Bar-Levav Mahad. 3, metuḳenet u-murḥevet. Yerushalayim : Mosad Byaliḳ, 731-   [1971- v. : facsim. ; 25 cm. On verso of t.p.: The wisdom of the Zohar. Includes bibliographical references. 31 Bible. Pentateuch Commentaries. ^A945653 Cabala. ^A1000298 Tishby, Isaiah. ^A366320 245-01 משנת זוהר : גופי מאמרי הזוהר / מסודרים לפי העניינים ומתורגמים עברית בידי פ. לחובר וישעיה תשבי ; בצירוף ביאורים, מובאות וחילופי נוסחאות מאת ישעיה תשבי. CSt SAL3 STACKS 1 0 v. 1 0 1 v.' # rubocop:disable Layout/LineLength
    end
  end
  describe 'vern_all_search' do
    let(:field) { 'vern_all_search' }
    it do
      expect(select_by_id('100017')[field][0]).to eq 'משנת זוהר : גופי מאמרי הזוהר / מסודרים לפי העניינים ומתורגמים עברית בידי פ. לחובר וישעיה תשבי ; בצירוף ביאורים, מובאות וחילופי נוסחאות מאת ישעיה תשבי.'
    end
  end
end
