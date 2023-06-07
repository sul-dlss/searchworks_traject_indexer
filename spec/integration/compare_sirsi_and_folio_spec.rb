# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'comparing records from sirsi and folio', if: ENV['OKAPI_URL'] || ENV['DATABASE_URL'] do # rubocop:disable Style/FetchEnvVar
  before do
    WebMock.enable_net_connect!
  end

  let(:folio_indexer) do
    Traject::Indexer.new.tap do |i|
      if ENV.key?('DATABASE_URL')
        i.settings do
          provide 'postgres.url', ENV.fetch('DATABASE_URL')
        end
      end
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:sirsi_indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end

  let(:marc_url) { "https://searchworks.stanford.edu/view/#{catkey.sub(/^a/, '')}.marcxml" }

  let(:marc_record) do
    MARC::XMLReader.new(StringIO.new(HTTP.get(marc_url).body.to_s)).to_a.first
  end

  shared_examples 'records match' do |*flags|
    before { pending } if flags.include?(:pending)

    let(:client) { FolioClient.new }

    let(:folio_record) do
      if ENV.key?('DATABASE_URL')
        require 'traject/readers/folio_postgres_reader'
        Traject::FolioPostgresReader.find_by_catkey(catkey, 'postgres.url' => ENV.fetch('DATABASE_URL'))
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
        'collection',
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

    let(:unordered_fields) do
      [
        'item_display', # the order of items is not guaranteed
        'barcode_search',
        'callnum_search',
        'reverse_shelfkey',
        'shelfkey',
        'mhld_display', # derived from the mhlds
        'building_facet' # derived from the item list
      ]
    end
    it 'matches' do
      aggregate_failures "testing response for catkey #{catkey}" do
        mapped_fields.each do |key|
          next if skipped_fields.include? key

          # we can treat nil and an empty array as equivalent (but not e.g. nil and an empty string)
          next if Array(folio_result[key]).empty? && Array(sirsi_result[key]).empty?

          if unordered_fields.include?(key) && folio_result[key].present?
            expect(folio_result[key]).to match_array(sirsi_result[key]),
                                         "expected #{key} to match \n\nSIRSI:\n#{sirsi_result[key].inspect}\nFOLIO:\n#{folio_result[key].inspect}"
          else
            expect(folio_result[key]).to eq(sirsi_result[key]),
                                         "expected #{key} to match \n\nSIRSI:\n#{sirsi_result[key].inspect}\nFOLIO:\n#{folio_result[key].inspect}"
          end
        end

        if sirsi_result['item_display'] || folio_result['item_display']
          sirsi_item_display_fields = sirsi_result.fetch('item_display', []).map { |item_display| item_display.split('-|-').map(&:strip) }
          folio_item_display_fields = folio_result.fetch('item_display', []).map { |item_display| item_display.split('-|-').map(&:strip) }

          sirsi_item_display_fields.each do |item_display_parts|
            folio_display_parts = folio_item_display_fields.find { |item_displays| item_displays[0] == item_display_parts[0] }

            if folio_display_parts.present?
              # we're not mapping item types
              item_display_parts[4] = folio_display_parts[4] = ''

              # The "ASIS" call number type is mapped to "OTHER" in Symphony, but "ALPHANUM" in FOLIO
              item_display_parts[11] = 'ALPHANUM' if item_display_parts[11] == 'OTHER' && folio_display_parts[11] == 'ALPHANUM'

              expect(folio_display_parts).to eq item_display_parts
            else
              expect(folio_display_parts).to be_present, "could not find item with barcode #{item_display_parts[0]} in FOLIO record"
            end
          end
        end
      end
    end
  end

  context 'catkey provided as envvar', if: ENV['catkey'] do # rubocop:disable Style/FetchEnvVar
    let(:catkey) { ENV.fetch('catkey') }

    before do
      puts 'FOLIO record: '
      pp folio_record
    end
    it_behaves_like 'records match'
  end

  # working
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

  # pending
  [
    'a576562',
    'a12451243',
    'a13288549',
    'a10151431',
    'a7919757', # on-order
    'a3372664', # holdings notes are different
    'a7812385', # missing holdings note "no.409 missing."
    'a14408747', # missing holdings note
    'a2741508', # missing a bunch of MHLD data
    'a4705967', # missing MHLD note
    'a14317027', # HOOVER + HV-ARCHIVE are merged?
    'a3324747', # missing temporary location data
    'a4706463', # missing item-level public note
    'a9089314', # missing item-level public note
  ].each do |catkey|
    context "catkey #{catkey}" do
      let(:catkey) { catkey }

      it_behaves_like 'records match', :pending
    end
  end
end
