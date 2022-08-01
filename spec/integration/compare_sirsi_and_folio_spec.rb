require 'spec_helper'

describe 'comparing against a well-known location full of documents generated by solrmarc' do
  skip unless ENV['OKAPI_URL']

  let(:folio_indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:sirsi_indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end

  let(:marc_record) do
    MARC::XMLReader.new(StringIO.new(HTTP.get("https://searchworks.stanford.edu/view/#{catkey}.marcxml").body.to_s)).to_a.first
  end

  shared_examples 'records match' do
    let(:sirsi_record) { sirsi_indexer.map_record(marc_record) }
    let(:folio_record) { folio_indexer.map_record(FolioRecord.fetch(catkey)) }
    let(:mapped_fields) do
      path = File.expand_path('../../lib/traject/config/sirsi_config.rb', __dir__)
      File.read(path).scan(/to_field ["']([^"']+)["']/).map(&:first).uniq
    end

    let(:skipped_fields) do
      [
        'marcxml', # FOLIO records have slightly different MARC records
        'all_search', # FOLIO records have slightly different MARC records
        'item_display', # handled separately because item types are mapped different
        'building_location_facet_ssim', # item types are different; internal use only so this is fine.
        'date_cataloged', # Comes out of a 9xx field
        'context_marc_fields_ssim' # different 9xx fields
      ]
    end
    it 'matches' do
      aggregate_failures "testing response" do
        mapped_fields.each do |key|
          next if skipped_fields.include? key
          expect(folio_record[key]).to eq(sirsi_record[key]), "expected #{key} to match \n\nSIRSI:\n#{sirsi_record[key].inspect}\nFOLIO:\n#{folio_record[key].inspect}"
        end

        sirsi_record['item_display'].each_with_index do |item_display, index|
          # require 'byebug'; byebug

          item_display_parts = item_display.split('-|-')
          folio_display_parts = folio_record.fetch('item_display', [])[index]&.split('-|-') || []

          # we're not mapping item types
          item_display_parts[4] = folio_display_parts[4] = ''

          expect(folio_display_parts).to eq item_display_parts
        end
      end
    end
  end

  context 'catkey provided as envvar' do
    let(:catkey) { ENV['catkey'] }

    before do
      puts "FOLIO record: "
      pp folio_record
    end
    it_behaves_like 'records match'
  end if ENV['catkey']

  %w[
    1004359
    10269181
    10173326
    10779956
    12857777
    1759444
    303651
    304635
  ].each do |catkey|
    context "catkey #{catkey}" do
      let(:catkey) { catkey }

      it_behaves_like 'records match'
    end
  end
end
