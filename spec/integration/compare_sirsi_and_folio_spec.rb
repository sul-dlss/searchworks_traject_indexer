# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'comparing records from sirsi and folio', if: ENV['OKAPI_URL'] || ENV['DATABASE_URL'] do # rubocop:disable Style/FetchEnvVar
  before do
    WebMock.enable_net_connect!
  end

  before(:all) do
    @pgclient = PG.connect(ENV.fetch('DATABASE_URL')) if ENV.key?('DATABASE_URL')
  end

  let(:settings) do
    {
      'postgres.client' => @pgclient
    }
  end

  let(:folio_indexer) do
    Traject::Indexer.new(settings).tap do |i|
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
    MARC::XMLReader.new(StringIO.new(HTTP.get(marc_url).body.to_s)).to_a.first.tap do |marc_record|
      fields = marc_record.fields(false)
      fields.delete_if { |field| folio_migration_junk_tags.include?(field.tag) }
    end
  end

  let(:folio_migration_junk_tags) do
    %w[
      592 594 597 598 599 695 699 790 791 792 793 890 891 897 898 899 909 911 922 925 926 927 928 930
      933 934 935 936 937 942 943 944 946 947 948 949 950 951 952 954 955 957 959 960 961 962
      963 965 966 967 971 975 980 983 984 985 987 988 990 996
    ]
  end

  shared_examples 'records match' do |*flags|
    before { pending(flags[:pending]) } if flags.include?(:pending)

    let(:client) { FolioClient.new }

    let(:folio_record) do
      if ENV.key?('DATABASE_URL')
        Timeout.timeout(10) do
          Traject::FolioPostgresReader.find_by_catkey(catkey, 'postgres.client' => @pgclient)
        end
      else
        client.source_record(instanceHrid: catkey)
      end
    end
    let(:sirsi_result) { sirsi_indexer.map_record(marc_record) }
    let(:folio_result) { folio_indexer.map_record(folio_record) }
    let(:mapped_fields) do
      path = File.expand_path('../../lib/traject/config/folio_config.rb', __dir__)
      File.read(path).scan(/to_field ["']([^"']+)["']/).map(&:first).uniq
    end
    before(:each) do
      skip 'No record in FOLIO' unless folio_record.present?
      pending 'No source record' if folio_record.record['source_record'].none?
    end

    let(:skipped_fields) do
      [
        'collection',
        'marcxml', # FOLIO records have slightly different MARC records
        'all_search', # FOLIO records have slightly different MARC records
        'item_display', # handled separately because item types are mapped different
        'item_display_struct',
        'building_location_facet_ssim', # item types are different; internal use only so this is fine.
        'date_cataloged', # Comes out of a 9xx field
        'context_marc_fields_ssim', # different 9xx fields
        'url_fulltext', # FOLIO has ezproxy prefixes
        'url_restricted', # FOLIO has ezproxy prefixes
        'marc_links_struct', # FOLIO has ezproxy prefixes
        'marc_json_struct',
        'context_source_ssi', # sirsi_config sets this to 'sirsi', and folio sets it to 'folio',
        'uuid_ssi',
        'folio_json_struct',
        'holdings_json_struct',
        'building_facet'
      ]
    end

    let(:unordered_fields) do
      [
        'access_facet',
        'barcode_search',
        'callnum_search',
        'reverse_shelfkey',
        'shelfkey',
        'callnum_facet_hsim',
        'mhld_display' # derived from the mhlds
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

        # Some buildings change display names in FOLIO
        expect(folio_result['building_facet'] || []).to contain_exactly(*((sirsi_result['building_facet'] || []).map do |x|
          case x
          when 'SAL1&2 (on-campus shelving)' then 'SAL1&2 (on-campus storage)'
          when 'Medical (Lane)' then 'Lane Medical'
          when 'Media & Microtext Center' then 'Media Center'
          when /^Hoover/ then 'Hoover Institution Library & Archives'
          when /^Education/ then 'Education (Cubberley)'
          else
            x
          end
        end))

        %w[url_fulltext url_restricted marc_links_struct].each do |key|
          # we can treat nil and an empty array as equivalent (but not e.g. nil and an empty string)
          next if Array(folio_result[key]).empty? && Array(sirsi_result[key]).empty?

          expect(folio_result[key].map { |x| x.gsub('https://stanford.idm.oclc.org/login?url=', '') }).to eq(sirsi_result[key]),
                                                                                                          "expected #{key} to match \n\nSIRSI:\n#{sirsi_result[key].inspect}\nFOLIO:\n#{folio_result[key].inspect}"
        end

        if sirsi_result['item_display_struct'] || folio_result['item_display_struct']
          sirsi_item_display_fields = sirsi_result.fetch('item_display_struct', []).map { |item_display| JSON.parse(item_display) }
          folio_item_display_fields = folio_result.fetch('item_display_struct', []).map { |item_display| JSON.parse(item_display) }

          sirsi_item_display_fields.each do |item_display_parts|
            folio_display_parts = folio_item_display_fields.find { |item_displays| item_displays['barcode'] == item_display_parts['barcode'] }

            item_display_parts['library'] = 'HOOVER' if item_display_parts['library'] == 'HV-ARCHIVE'

            if folio_display_parts.present?
              # INPROCESS and MISSING can be a location or current location
              if %w[INPROCESS MISSING].include?(item_display_parts['home_location'])
                item_display_parts['current_location'] = item_display_parts['home_location'].presence
                item_display_parts['home_location'] = folio_display_parts['home_location'].presence
              end
              # we're not mapping item types
              item_display_parts['type'] = folio_display_parts['type'] = nil

              # The "ASIS" call number type is mapped to "OTHER" in Symphony, but "ALPHANUM" in FOLIO
              item_display_parts['scheme'] = 'ALPHANUM' if item_display_parts['scheme'] == 'OTHER' && folio_display_parts['scheme'] == 'ALPHANUM'

              # Symphony doesn't have item ids
              folio_display_parts['id'] = nil

              expect(folio_display_parts).to eq item_display_parts
            else
              expect(folio_display_parts).to be_present, "could not find item with barcode #{item_display_parts['barcode']} in FOLIO record"
            end
          end
        end
      end
    end
  end

  context 'catkey provided as envvar', if: ENV['catkey'] do # rubocop:disable Style/FetchEnvVar
    let(:catkey) { ENV.fetch('catkey') }

    before(:each) do
      skip('Lane record') if Array(sirsi_result['building_facet']).include? 'Medical (Lane)'
      pending('Bound with') if Array(sirsi_result['marc_json_struct']).to_s.match? 'BW-CHILD'
    end

    before do
      puts 'FOLIO record: '
      pp folio_record
    end
    it_behaves_like 'records match'
  end

  context 'file provided as envvar', if: ENV['file'] do # rubocop:disable Style/FetchEnvVar
    File.read(ENV.fetch('file', nil)).each_line.map(&:strip).sample(500).each do |catkey|
      context "catkey #{catkey}" do
        let(:catkey) { "a#{catkey}" }

        before(:each) do
          skip('Lane record') if Array(sirsi_result['building_facet']).include? 'Medical (Lane)'
          pending('Bound with') if Array(sirsi_result['marc_json_struct']).to_s.match? 'BW-CHILD'
        end

        it_behaves_like 'records match'
      end
    end if ENV['file']
  end

  # working
  [
    'a1004359',
    'a10269181',
    'a10173326',
    'a10779956',
    'a12857777',
    'a1759444',
    'a303651',
    'a304635',
    'a12451243',
    'a13288549',
    'a6535458', # MHLD punctuation
    'a13295747', # electronic
    'a12709561', # electronic
    'a10690790', # ezproxy prefix
    'a81622', # missing status
    'a14644326', # in-process status
    'a3118108', # missing status
    'a282409', # MARC 699 field
    'a10146027' # SUL/SDR instead of SUL/INTERNET
  ].each do |catkey|
    context "catkey #{catkey}" do
      let(:catkey) { catkey }

      it_behaves_like 'records match'
    end
  end

  # good changes
  [
    'a11418750', # used to be access_facet "On order" now "At the Library"... but it's actually LOST-ASSUM
    'a76118', #  bound-with using an actual barcode in FOLIO
    'a14718056', # better callnumber lopping?
    'a14804590' # was a stub ON-ORDER record, now has a little more data
  ].each do |catkey|
    context "catkey #{catkey}" do
      let(:catkey) { catkey }

      it_behaves_like 'records match', pending: 'expected change (for the better)'
    end
  end

  # pending
  [
    'a576562',
    'a10151431',
    'a3184189', # sudoc call number changed formatting
    'a91273', # bound-with with missing item data
    'a1649793', # used to be govdoc
    'a400248', # missing latest received, see also a8589317
    'a2725653', # used to be LOST-ASSUM?
    'a13420376', # used to have an LC call num
    'a10291248', # missing MHLD data
    'a4808878', # extra MHLD data, see also a6513560
    'a10444184', # extra e-resource barcodes
    'a2727161', # MHLD lost library info
    'a8572051', # bound-with turned on-order
    'a14450720', # B&F-HOLD
    'a75306', # different lopping
    'a11852997', # LAW-BIND
    'a36259', # super different BW, see also a153955
    'a105784', # bound-with building facet changed
    'a140576', # current location used to be SEE-LOAN, see also a117415, a227909
    'a233811', # checkedout vs lost-assum, see also a231762, a154314
    'a515836', # funky call-number problems
    'a6634796', # missing call number in item_display
    'a1553634', # migration error holdings
    'a12264341', # extra electronic items
    'a9335111', # missing bound-withs
    'a14461522', # ???
    'a4084116', # call number changed?
    'a13652131', # electronic only, missing physical holding?
    'a2492166', # bound-with call numbers missing
    'a5814693', # MHLD ordering
    'a6517994' # has unexpected MHLD statements
  ].each do |catkey|
    context "catkey #{catkey}" do
      let(:catkey) { catkey }

      it_behaves_like 'records match', pending: 'expected failure'
    end
  end
end
