# frozen_string_literal: true

RSpec.describe 'Skips records' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.settings(
        'solr.url' => 'http://127.0.0.1:8983/solr/fake',
        'writer_class_name' => 'Traject::ArrayWriter',
        'skip_empty_item_display' => 1
      )
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:record) { MARC::Record.new }
  let(:folio_record) { marc_to_folio(record) }
  subject(:result) { indexer.map_record(folio_record) }

  context 'with a **REQUIRED FILE** title' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.append(
          MARC::DataField.new(
            '245',
            '1',
            '0',
            MARC::Subfield.new('a', '**REQUIRED FIELD**')
          )
        )
      end
    end

    it { is_expected.to be nil }
  end
end
