# frozen_string_literal: true

require 'spec_helper'

describe 'comparing against a well-known location full of documents generated by solrmarc' do
  before do
    WebMock.enable_net_connect!
  end

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
    MARC::XMLReader.new(StringIO.new(HTTP.get("https://searchworks.stanford.edu/view/#{catkey.sub(/^a/,
                                                                                                  '')}.marcxml").body.to_s)).to_a.first
  end

  shared_examples 'records match' do
    let(:client) do
      FolioClient.new url: ENV['OKAPI_URL'], username: ENV.fetch('OKAPI_USER', nil),
                      password: ENV.fetch('OKAPI_PASSWORD', nil)
    end
    let(:folio_record) do
      if ENV['POSTGRES_URL']
        Traject::FolioPostgresReader.new(nil, 'postgres.url' => ENV['POSTGRES_URL'],
                                              'postgres.sql_filters' => "lower(sul_mod_inventory_storage.f_unaccent(vi.jsonb ->> 'hrid'::text)) = '#{catkey}'").first
      else
        client.source_record(instanceHrid: catkey)
      end
    end
    let(:sirsi_result) { sirsi_indexer.map_record(marc_record) }
    let(:folio_result) { folio_indexer.map_record(folio_record) }
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
        'context_marc_fields_ssim', # different 9xx fields
        'marc_json_struct',
        'context_source_ssi' # sirsi_config sets this to 'sirsi', and folio sets it to 'folio'
      ]
    end
    it 'matches' do
      aggregate_failures 'testing response' do
        mapped_fields.each do |key|
          next if skipped_fields.include? key

          expect(folio_result[key]).to eq(sirsi_result[key]),
                                       "expected #{key} to match \n\nSIRSI:\n#{sirsi_result[key].inspect}\nFOLIO:\n#{folio_result[key].inspect}"
        end

        sirsi_result['item_display'].each_with_index do |item_display, index|
          # require 'byebug'; byebug

          item_display_parts = item_display.split('-|-')
          folio_display_parts = folio_result.fetch('item_display', [])[index]&.split('-|-') || []

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
      puts 'FOLIO record: '
      pp folio_record
    end
    it_behaves_like 'records match'
  end if ENV['catkey']

  %w[
    a1004359
    a10269181
    a10173326
    a10779956
    a12857777
    a1759444
    a303651
    a304635
  ].each do |catkey|
    context "catkey #{catkey}" do
      let(:catkey) { catkey }

      it_behaves_like 'records match'
    end
  end
end if ENV['OKAPI_URL'] || ENV['POSTGRES_URL']
