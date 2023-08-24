# frozen_string_literal: true

require 'spec_helper'

describe 'comparing against a well-known location full of documents generated by solrmarc' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:record) { MARC::XMLReader.new(StringIO.new(marcxml)).to_a.first }
  let(:copy_fields) do
    %w[collection_search pub_date_search db_az_subject_search instructor course topic_display subject_other_display
       title_variant_display summary_display pub_display]
  end
  let(:ignored_fields) do
    %w[all_search created last_updated format _version_ author_sort callnum_facet_hsim marcbib_xml marcxml mhld_display fund_facet building_facet collection] + copy_fields
  end
  let(:pending_fields) { %w[reverse_shelfkey shelfkey preferred_barcode item_display date_cataloged access_facet] }
  subject(:result) { indexer.map_record(stub_record_from_marc(record)).transform_values { |v| v.sort } }

  Dir.glob(File.expand_path('solrmarc_example_docs/*', file_fixture_path)).each do |fixture|
    context "with #{fixture}" do
      let(:file) { File.read(fixture) }
      let(:data) { JSON.parse(file) }
      let(:solrmarc_doc) { data['doc'] }
      let(:expected_doc) do
        data['doc'].transform_values { |v| Array(v).map(&:to_s).sort }
      end
      let(:marcxml) { solrmarc_doc['marcxml'] }

      it 'maps the same general output' do
        # Stub the year so this test doesn't fail every January
        allow_any_instance_of(Time).to receive(:year).and_return(2019)
        expect(result).to include expected_doc.reject { |k, _v| (ignored_fields + pending_fields).include? k }
      end

      it 'maps the same general output' do
        skip unless pending_fields.any?
        pending
        expect(result.select { |k, _v| pending_fields.include? k }).to include expected_doc.select { |k, _v|
                                                                                 pending_fields.include? k
                                                                               }
        expect(false).to eq true # keep rspec happy if the above happens to pass
      end

      it 'maps collection' do
        # FOLIO add 'folio' to the list
        expect(result['collection']).to include(*expected_doc['collection'])
      end

      it 'maps building_facet' do
        # Some buildings change display names in FOLIO
        expect(result['building_facet']).to eq(expected_doc['building_facet']&.map do |x|
          case x
          when 'SAL1&2 (on-campus shelving)' then 'SAL1&2 (on-campus storage)'
          when 'Medical (Lane)' then 'Lane Medical'
          else
            x
          end
        end)
      end
    end
  end
end
