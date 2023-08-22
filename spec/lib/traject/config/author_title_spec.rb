# frozen_string_literal: true

RSpec.describe 'Author-title config' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }
  let(:fixture_name) { 'authorTitleMappingTests.mrc' }
  let(:field) { 'author_title_search' }
  subject(:results) { records.map { |rec| indexer.map_record(stub_record_from_marc(rec)) }.to_a }

  # rubocop:disable Layout/LineLength
  describe 'maps search field values from 100, 110, 111 with data from the 240 or 245' do
    it 'maps the right data' do
      expect(select_by_id('100240')[field]).to eq ['100a 100b 100c 100d 100f 100g 100j 100k 100l 100n 100p 100q 100t 100u 240a 240d 240f 240g 240h 240k 240l 240m 240n 240o 240p 240r 240s']
      expect(select_by_id('110240')[field]).to eq ['110a 110b 110c 110d 110f 110g 110k 110l 110n 110p 110t 110u 240a 240d 240f 240g 240h 240k 240l 240m 240n 240o 240p 240r 240s']
      expect(select_by_id('111240')[field]).to eq ['111a 111c 111d 111e 111f 111g 111j 111k 111l 111n 111p 111q 111t 111u 240a 240d 240f 240g 240h 240k 240l 240m 240n 240o 240p 240r 240s']

      expect(select_by_id('100no240')[field]).to eq ['100a 100b 100c 100d 100f 100g 100j 100k 100l 100n 100p 100q 100t 100u 245a']
      expect(select_by_id('110no240')[field]).to eq ['110a 110b 110c 110d 110f 110g 110k 110l 110n 110p 110t 110u 245a']
      expect(select_by_id('111no240')[field]).to eq ['111a 111c 111d 111e 111f 111g 111j 111k 111l 111n 111p 111q 111t 111u 245a']
    end
  end

  describe 'maps search field values from 700, 710, 711 should only have a value if there is a subfield t' do
    it 'maps the right data' do
      expect(select_by_id('700')[field]).to include '700a 700b 700c 700d 700f 700g 700h 700j 700k 700l 700m 700n 700o 700p 700q 700r 700s 700t 700u'
      expect(select_by_id('710')[field]).to include '710a 710b 710c 710d 710f 710g 710h 710k 710l 710m 710n 710o 710p 710r 710s 710t 710u'
      expect(select_by_id('711')[field]).to include '711a 711c 711d 711e 711f 711g 711h 711j 711k 711l 711n 711p 711q 711s 711t 711u'
    end

    it 'skips the 7xx field if there is no subfield t' do
      expect(select_by_id('700nosubt')[field]).to eq nil
      expect(select_by_id('710nosubt')[field]).to eq nil
      expect(select_by_id('711nosubt')[field]).to eq nil
    end
  end

  describe 'maps search field values from 800, 810, 811 should only have a value if there is a subfield t' do
    it 'maps the right data' do
      expect(select_by_id('800')[field]).to include '800a 800b 800c 800d 800f 800g 800h 800j 800k 800l 800m 800n 800o 800p 800q 800r 800s 800t 800u'
      expect(select_by_id('810')[field]).to include '810a 810b 810c 810d 810f 810g 810h 810j 810k 810l 810m 810n 810o 810p 810r 810s 810t 810u'
      expect(select_by_id('811')[field]).to include '811a 811c 811d 811f 811g 811h 811j 811k 811l 811n 811p 811q 811s 811t 811u'
    end

    it 'skips the 8xx field if there is no subfield t' do
      expect(select_by_id('800nosubt')[field]).to eq nil
      expect(select_by_id('810nosubt')[field]).to eq nil
      expect(select_by_id('811nosubt')[field]).to eq nil
    end
  end

  describe 'maps search field values from vernacular 100, 110, 111 with data from the 240 or 245' do
    it 'maps the right data' do
      expect(select_by_id('vern100vern240')[field]).to include 'vern100a vern100b vern100c vern100d vern100f vern100g vern100j vern100k vern100l vern100n vern100p vern100q vern100t vern100u vern240a vern240d vern240f vern240g vern240h vern240k vern240l vern240m vern240n vern240o vern240p vern240r vern240s'
      expect(select_by_id('vern100vern245')[field]).to include 'vern100a vern100b vern100c vern100d vern100f vern100g vern100j vern100k vern100l vern100n vern100p vern100q vern100t vern100u vern245a'
    end

    it 'does something with a minimal 100 field to link to 880' do
      expect(select_by_id('vern100no240')[field]).to eq ['100a 245a']
      expect(select_by_id('vern100plain240')[field]).to eq ['100a 240a 240d 240f 240g 240h 240k 240l 240m 240n 240o 240p 240r 240s']

      expect(select_by_id('vern110vern240')[field]).to include 'vern110a vern110b vern110c vern110d vern110f vern110g vern110k vern110l vern110n vern110p vern110t vern110u vern240a vern240d vern240f vern240g vern240h vern240k vern240l vern240m vern240n vern240o vern240p vern240r vern240s'
      expect(select_by_id('vern110vern245')[field]).to include 'vern110a vern110b vern110c vern110d vern110f vern110g vern110k vern110l vern110n vern110p vern110t vern110u vern245a'

      expect(select_by_id('vern110no240')[field]).to eq ['110a 245a']

      expect(select_by_id('vern111vern240')[field]).to include 'vern111a vern111c vern111d vern111e vern111f vern111g vern111j vern111k vern111l vern111n vern111p vern111q vern111t vern111u vern240a vern240d vern240f vern240g vern240h vern240k vern240l vern240m vern240n vern240o vern240p vern240r vern240s'
      expect(select_by_id('vern111vern245')[field]).to include 'vern111a vern111c vern111d vern111e vern111f vern111g vern111j vern111k vern111l vern111n vern111p vern111q vern111t vern111u vern245a'
      expect(select_by_id('vern111no240')[field]).to eq ['111a 245a']
    end
  end

  describe 'maps search field values from vernacular 700, 710, 711 should only have a value if there is a subfield t' do
    it 'maps the right data' do
      expect(select_by_id('vern700')[field]).to include 'vern700a vern700b vern700c vern700d vern700f vern700g vern700h vern700j vern700k vern700l vern700m vern700n vern700o vern700p vern700q vern700r vern700s vern700t vern700u'
      expect(select_by_id('vern710')[field]).to include 'vern710a vern710b vern710c vern710d vern710f vern710g vern710h vern710k vern710l vern710m vern710n vern710o vern710p vern710r vern710s vern710t vern710u'
      expect(select_by_id('vern711')[field]).to include 'vern711a vern711c vern711d vern711e vern711f vern711g vern711h vern711j vern711k vern711l vern711n vern711p vern711q vern711s vern711t vern711u'
    end

    it 'skips the vern7xx field if there is no subfield t' do
      expect(select_by_id('vern700nosubt')[field]).to eq nil
      expect(select_by_id('vern710nosubt')[field]).to eq nil
      expect(select_by_id('vern711nosubt')[field]).to eq nil
    end
  end

  describe 'maps search field values from vern800, vern810, vern811 should only have a value if there is a subfield t' do
    it 'maps the right data' do
      expect(select_by_id('vern800')[field]).to include 'vern800a vern800b vern800c vern800d vern800f vern800g vern800h vern800j vern800k vern800l vern800m vern800n vern800o vern800p vern800q vern800r vern800s vern800t vern800u'
      expect(select_by_id('vern810')[field]).to include 'vern810a vern810b vern810c vern810d vern810f vern810g vern810h vern810k vern810l vern810m vern810n vern810o vern810p vern810r vern810s vern810t vern810u'
      expect(select_by_id('vern811')[field]).to include 'vern811a vern811c vern811d vern811f vern811g vern811h vern811j vern811k vern811l vern811n vern811p vern811q vern811s vern811t vern811u'
    end

    it 'skips the vern8xx field if there is no subfield t' do
      expect(select_by_id('vern800nosubt')[field]).to eq nil
      expect(select_by_id('vern810nosubt')[field]).to eq nil
      expect(select_by_id('vern811nosubt')[field]).to eq nil
    end
  end
  # rubocop:enable Layout/LineLength
end
