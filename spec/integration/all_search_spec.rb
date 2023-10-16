# frozen_string_literal: true

RSpec.describe 'All_search integration' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end
  let(:record) { MARC::Record.new_from_hash(JSON.parse(data)) }
  let(:data) do
    <<~JSON
      {"leader":"01971nam a2200409 a 4500","fields":[{"001":"a100017"},{"003":"SIRSI"},{"005":"20180217050003.0"},{"008":"850308m19719999is h     b    001 0 heb  "},
        {"010":{"ind1":" ","ind2":" ","subfields":[{"a":"   72953874"}]}},
        {"020":{"ind1":" ","ind2":" ","subfields":[{"a":"9789655361896 (Index volume)"}]}},
        {"020":{"ind1":" ","ind2":" ","subfields":[{"a":"9655361896"}]}},
        {"040":{"ind1":" ","ind2":" ","subfields":[{"a":"DLC"},{"c":"TYC"},{"d":"TYC"},{"d":"m"},{"d":"STF/c"},{"d":"OrLoB"},{"d":"CSt"}]}},
        {"049":{"ind1":" ","ind2":" ","subfields":[{"a":"STFA"},{"c":"1"},{"v":"1"}]}},
        {"050":{"ind1":"0","ind2":" ","subfields":[{"a":"BM525.A55"},{"b":"T522"}]}},
        {"130":{"ind1":"0","ind2":" ","subfields":[{"a":"Zohar"},{"k":"Selections."},{"l":"Hebrew."},{"=":"^A968827"}]}},
        {"245":{"ind1":"1","ind2":"0","subfields":[{"6":"880-01"},{"a":"Mishnat ha-Zohar :"},{"b":"gufe maʼamare ha-Zohar /"},{"c":"mesudarim le-fi ha-ʻinyanim u-meturgamim ʻivrit bi-yede F. Laḥover ṿi-Yeshʻayah Tishbi ; be-tseruf beʼurim mevoʼot ṿe-ḥilufe nusḥaʼot meʼet Yeshʻayah Tishbi."}]}},
        {"246":{"ind1":"3","ind2":" ","subfields":[{"a":"Wisdom of the Zohar : texts from the Book of Splendour"}]}},{"246":{"ind1":"3","ind2":" ","subfields":[{"a":"Mishnat ha-Zohar : gufe maʼamare ha-Zohar : kerekh ha-maftehot /  ʻarakh: Avriʼel Bar-Levav"}]}},
        {"250":{"ind1":" ","ind2":" ","subfields":[{"a":"Mahad. 3, metuḳenet u-murḥevet."}]}},{"260":{"ind1":" ","ind2":" ","subfields":[{"a":"Yerushalayim :"},{"b":"Mosad Byaliḳ,"},{"c":"731-   [1971-"}]}},
        {"300":{"ind1":" ","ind2":" ","subfields":[{"a":"v. :"},{"b":"facsim. ;"},{"c":"25 cm."}]}},
        {"500":{"ind1":" ","ind2":" ","subfields":[{"a":"On verso of t.p.: The wisdom of the Zohar."}]}},{"504":{"ind1":" ","ind2":" ","subfields":[{"a":"Includes bibliographical references."}]}},{"596":{"ind1":" ","ind2":" ","subfields":[{"a":"31"}]}},
        {"630":{"ind1":"0","ind2":"0","subfields":[{"a":"Bible."},{"p":"Pentateuch"},{"x":"Commentaries."},{"=":"^A945653"}]}},
        {"650":{"ind1":" ","ind2":"0","subfields":[{"a":"Cabala."},{"=":"^A1000298"}]}},
        {"700":{"ind1":"1","ind2":" ","subfields":[{"a":"Tishby, Isaiah."},{"=":"^A366320"}]}},
        {"035":{"ind1":" ","ind2":" ","subfields":[{"a":"(OCoLC-M)11781160"}]}},
        {"035":{"ind1":" ","ind2":" ","subfields":[{"a":"(OCoLC-I)272585591"}]}},
        {"880":{"ind1":"1","ind2":"0","subfields":[{"6":"245-01"},{"a":"משנת זוהר :"},{"b":"גופי מאמרי הזוהר /"},{"c":"מסודרים לפי העניינים ומתורגמים עברית בידי פ. לחובר וישעיה תשבי ; בצירוף ביאורים, מובאות וחילופי נוסחאות מאת ישעיה תשבי."}]}},
        {"916":{"ind1":" ","ind2":" ","subfields":[{"a":"DATE CATALOGED"},{"b":"19900915"}]}},
        {"852":{"ind1":" ","ind2":" ","subfields":[{"a":"CSt"},{"b":"SAL3"},{"c":"STACKS"},{"t":"1"}]}},{"866":{"ind1":"4","ind2":"1","subfields":[{"8":"0"},{"a":"v. 1"}]}},{"868":{"ind1":"4","ind2":"1","subfields":[{"8":"0"},{"a":"1 v."}]}}
        ]}
    JSON
  end

  subject(:value) { indexer.map_record(marc_to_folio(record))[field][0] }

  describe 'all_search' do
    let(:field) { 'all_search' }
    it { is_expected.to eq 'Zohar Selections. Hebrew. ^A968827 880-01 Mishnat ha-Zohar : gufe maʼamare ha-Zohar / mesudarim le-fi ha-ʻinyanim u-meturgamim ʻivrit bi-yede F. Laḥover ṿi-Yeshʻayah Tishbi ; be-tseruf beʼurim mevoʼot ṿe-ḥilufe nusḥaʼot meʼet Yeshʻayah Tishbi. Wisdom of the Zohar : texts from the Book of Splendour Mishnat ha-Zohar : gufe maʼamare ha-Zohar : kerekh ha-maftehot /  ʻarakh: Avriʼel Bar-Levav Mahad. 3, metuḳenet u-murḥevet. Yerushalayim : Mosad Byaliḳ, 731-   [1971- v. : facsim. ; 25 cm. On verso of t.p.: The wisdom of the Zohar. Includes bibliographical references. 31 Bible. Pentateuch Commentaries. ^A945653 Cabala. ^A1000298 Tishby, Isaiah. ^A366320 245-01 משנת זוהר : גופי מאמרי הזוהר / מסודרים לפי העניינים ומתורגמים עברית בידי פ. לחובר וישעיה תשבי ; בצירוף ביאורים, מובאות וחילופי נוסחאות מאת ישעיה תשבי.' } # rubocop:disable Layout/LineLength
  end

  describe 'vern_all_search' do
    let(:field) { 'vern_all_search' }
    it { is_expected.to eq 'משנת זוהר : גופי מאמרי הזוהר / מסודרים לפי העניינים ומתורגמים עברית בידי פ. לחובר וישעיה תשבי ; בצירוף ביאורים, מובאות וחילופי נוסחאות מאת ישעיה תשבי.' }
  end
end
