# frozen_string_literal: true

RSpec.describe 'Holdings config' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end
  let(:records) { Traject::MarcCombiningReader.new(file_fixture(fixture_name).to_s, {}).to_a }
  let(:record) { records.first }
  let(:fixture_name) { '44794.marc' }
  subject(:results) { records.map { |rec| indexer.map_record(stub_record_from_marc(rec)) }.to_a }
  subject(:result) { indexer.map_record(stub_record_from_marc(record)) }

  describe 'on_order_library_ssim' do
    let(:field) { 'on_order_library_ssim' }

    it do
      expect(select_by_id('44794')[field]).to eq ['SAL3']
    end
  end

  describe 'bookplates_display' do
    let(:field) { 'bookplates_display' }
    describe 'population of bookplates_display' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::ControlField.new('001', 'aunitAfterYear'))
          r.append(MARC::DataField.new('979', ' ', ' ',
                                       MARC::Subfield.new('f', 'BAILEYT'),
                                       MARC::Subfield.new('b', 'druid:tf882hn2198'),
                                       MARC::Subfield.new('c', 'tf882hn2198_00_0001.jp2'),
                                       MARC::Subfield.new('d', 'Annie Nelson Bailey Memorial Book Fund')))
        end
      end
      it do
        expect(result[field]).to eq ['BAILEYT -|- tf882hn2198 -|- tf882hn2198_00_0001.jp2 -|- Annie Nelson Bailey Memorial Book Fund']
      end
    end
    describe 'multiple 979' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::ControlField.new('001', 'aunitAfterYear'))
          r.append(MARC::DataField.new('979', ' ', ' ',
                                       MARC::Subfield.new('f', 'BAILEYT'),
                                       MARC::Subfield.new('b', 'druid:tf882hn2198'),
                                       MARC::Subfield.new('c', 'tf882hn2198_00_0001.jp2'),
                                       MARC::Subfield.new('d', 'Annie Nelson Bailey Memorial Book Fund')))
          r.append(MARC::DataField.new('979', ' ', ' ',
                                       MARC::Subfield.new('f', 'HARRISL'),
                                       MARC::Subfield.new('b', 'druid:bm267dr4255'),
                                       MARC::Subfield.new('c', 'No content metadata'),
                                       MARC::Subfield.new('d', 'Lucie King Harris Fund')))
          r.append(MARC::DataField.new('979', ' ', ' ',
                                       MARC::Subfield.new('f', 'BENDERRM'),
                                       MARC::Subfield.new('b', 'druid:hd360gv1231'),
                                       MARC::Subfield.new('c', 'hd360gv1231_00_0001.jp2'),
                                       MARC::Subfield.new('d', 'Stanford Bookstore : Centennial')))
        end
      end
      it do
        expect(result[field].count).to eq 2
        expect(result[field][0]).to eq 'BAILEYT -|- tf882hn2198 -|- tf882hn2198_00_0001.jp2 -|- Annie Nelson Bailey Memorial Book Fund'
        expect(result[field][1]).to eq 'BENDERRM -|- hd360gv1231 -|- hd360gv1231_00_0001.jp2 -|- Stanford Bookstore : Centennial'
      end
    end
    describe 'no content' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::ControlField.new('001', 'aunitAfterYear'))
          r.append(MARC::DataField.new('979', ' ', ' ',
                                       MARC::Subfield.new('f', 'HARRISL'),
                                       MARC::Subfield.new('b', 'druid:bm267dr4255'),
                                       MARC::Subfield.new('c', 'No content metadata'),
                                       MARC::Subfield.new('d', 'Lucie King Harris Fund')))
        end
      end
      it do
        expect(result[field]).to be_nil
      end
    end
  end
  describe 'fund_facet' do
    let(:field) { 'fund_facet' }
    describe 'population of fund_facet' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::ControlField.new('001', 'aunitAfterYear'))
          r.append(MARC::DataField.new('979', ' ', ' ',
                                       MARC::Subfield.new('f', 'BENDERRM'),
                                       MARC::Subfield.new('b', 'druid:hd360gv1231'),
                                       MARC::Subfield.new('c', 'hd360gv1231_00_0001.jp2'),
                                       MARC::Subfield.new('d', 'Stanford Bookstore : Centennial')))
        end
      end
      it do
        expect(result[field]).to eq %w[BENDERRM hd360gv1231]
      end
    end
    describe 'multiple 979' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::ControlField.new('001', 'aunitAfterYear'))
          r.append(MARC::DataField.new('979', ' ', ' ',
                                       MARC::Subfield.new('f', 'BAILEYT'),
                                       MARC::Subfield.new('b', 'druid:tf882hn2198'),
                                       MARC::Subfield.new('c', 'tf882hn2198_00_0001.jp2'),
                                       MARC::Subfield.new('d', 'Annie Nelson Bailey Memorial Book Fund')))
          r.append(MARC::DataField.new('979', ' ', ' ',
                                       MARC::Subfield.new('f', 'HARRISL'),
                                       MARC::Subfield.new('b', 'druid:bm267dr4255'),
                                       MARC::Subfield.new('c', 'No content metadata'),
                                       MARC::Subfield.new('d', 'Lucie King Harris Fund')))
          r.append(MARC::DataField.new('979', ' ', ' ',
                                       MARC::Subfield.new('f', 'BENDERRM'),
                                       MARC::Subfield.new('b', 'druid:hd360gv1231'),
                                       MARC::Subfield.new('c', 'hd360gv1231_00_0001.jp2'),
                                       MARC::Subfield.new('d', 'Stanford Bookstore : Centennial')))
        end
      end
      it do
        expect(result[field]).to eq %w[BAILEYT tf882hn2198 BENDERRM hd360gv1231]
      end
    end
  end
end
