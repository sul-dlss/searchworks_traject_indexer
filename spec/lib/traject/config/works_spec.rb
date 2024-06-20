# frozen_string_literal: true

RSpec.describe 'Author config' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:records) { MARC::XMLReader.new(file_fixture(fixture_name).to_s).to_a }
  let(:fixture_name) { 'linked_related_works_fixture.xml' }
  subject(:results) { records.map { |rec| indexer.map_record(marc_to_folio(rec)) }.to_a }

  describe 'works_struct' do
    let(:field) { 'works_struct' }
    let(:data) { JSON.parse(results.first[field].first, symbolize_names: true)[:included].first }

    it '#pre_text' do
      expect(data[:pre_text]).to include 'i1_subfield_text: i2_subfield_text:' # in order
    end

    it '#link' do
      %w[a d f k l h m n o p r s t].each do |code|
        expect(data[:link]).to include "#{code}_subfield_text"
      end
      %w[i1 i2 x1 x2].each do |code|
        expect(data[:link]).not_to include "#{code}_subfield_text"
      end
    end

    it '#search' do
      %w[a d f k l m n o p r s t].each do |code|
        expect(data[:search]).to include "#{code}_subfield_text"
      end
    end

    it '#post_text' do
      text = 'x1_subfield_text. x2_subfield_text. 3_subfield_text' # in order
      expect(data[:post_text]).to include text
      %w[0 5 8].each do |code| # always excluded
        expect(data[:post_text]).not_to include "#{code}_subfield_text"
      end
    end

    context 'when there are no linked works' do
      let(:marc_record) do
        MARC::Record.new.tap do |r|
          r.leader = '15069nam a2200409 a 4500'
          r.append(MARC::ControlField.new('008', '091123s2014    si a    sb    101 0 eng d'))
          r.append(MARC::DataField.new('650', ' ', '0',
                                       MARC::Subfield.new('a', 'subject'),
                                       MARC::Subfield.new('v', 'Congresses')))
        end
      end

      let(:records) { [marc_record] }

      it 'is blank' do
        expect(results.first[field]).to be_blank
      end
    end
  end
end
