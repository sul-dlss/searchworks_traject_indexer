require 'spec_helper'

describe Traject::SolrBetterJsonWriter do
  subject(:writer) { described_class.new('solr_json_writer.http_client' => http_client, 'solr.update_url' => 'http://localhost/solr') }
  let(:http_client) { double(post: double(status: 200)) }
  let(:doc) { Traject::Indexer::Context.new.tap { |doc| doc.output_hash['id'] = [1] }}
  let(:skipped_doc) { Traject::Indexer::Context.new.tap { |doc| doc.output_hash['id'] = [2]; doc.skip! } }

  describe '#send_batch' do
    it 'adds documents to solr' do
      writer.send_batch([doc])
      expect(http_client).to have_received(:post).with('http://localhost/solr', '{add: {"doc":{"id":[1]}}}', 'Content-type' => 'application/json')
    end

    it 'deletes documents from solr' do
      writer.send_batch([skipped_doc])
      expect(http_client).to have_received(:post).with('http://localhost/solr', '{delete: {"id":2}}', 'Content-type' => 'application/json')
    end

    it 'sends the request as a batch' do
      writer.send_batch([doc, skipped_doc])
      expect(http_client).to have_received(:post).with('http://localhost/solr', "{add: {\"doc\":{\"id\":[1]}},\ndelete: {\"id\":2}}", 'Content-type' => 'application/json')
    end
  end
end
