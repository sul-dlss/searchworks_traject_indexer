require 'spec_helper'

describe 'comparing against a well-known location full of documents generated by solrmarc' do
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end

  let(:record) { MARC::XMLReader.new(StringIO.new(marcxml)).to_a.first }
  subject(:result) { indexer.map_record(record) }

  Dir.glob(File.expand_path('solrmarc_example_docs/*', file_fixture_path)).each do |fixture|
    context "with #{fixture}" do
      let(:file) { File.read(fixture) }
      let(:data) { JSON.parse(file) }
      let(:solrmarc_doc) { data['doc'] }
      let(:expected_doc) { data['doc'].each_with_object({}) { |(k,v), h| h[k] = Array(v).map(&:to_s) } }
      let(:marcxml) { solrmarc_doc['marcxml'] }

      it 'maps the same general output' do
        pending
        expect(result).to include expected_doc
      end
    end
  end
end
