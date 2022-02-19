require 'spec_helper'

describe Traject::SolrBetterJsonWriter do
  subject(:writer) { described_class.new('solr_json_writer.http_client' => http_client, 'solr.update_url' => 'http://localhost/solr', 'solr_better_json_writer.debounce_timeout' => 1) }
  let(:http_client) { double(post: double(status: 200)) }
  let(:doc) { Traject::Indexer::Context.new.tap { |doc| doc.output_hash['id'] = [1] }}
  let(:skipped_doc) { Traject::Indexer::Context.new.tap { |doc| doc.output_hash['id'] = [2]; doc.skip! } }
  let(:bad_doc) { Traject::Indexer::Context.new.tap { |doc| doc.skip! } }

  describe '#put' do
    it 'flushes data after the queue hits a maximum size' do
      count = 0
      allow(writer).to receive(:send_batch) { |batch| count += batch.length }
      100.times { writer.put(doc) }
      sleep 1
      expect(writer).to have_received(:send_batch).at_least(1).times
      writer.close
      expect(count).to eq 100
    end

    it 'flushes data after a timeout' do
      count = 0
      allow(writer).to receive(:send_batch) { |batch| count += batch.length }
      1.times { writer.put(doc) }
      sleep 2
      expect(writer).to have_received(:send_batch).at_least(1).times
      writer.close
      expect(count).to eq 1
    end
  end

  describe '#send_batch' do
    it 'adds documents to solr' do
      writer.send_batch([doc])
      expect(http_client).to have_received(:post).with('http://localhost/solr', '{add: {"doc":{"id":[1]}}}', 'Content-type' => 'application/json')
    end

    it 'deletes documents from solr' do
      writer.send_batch([skipped_doc])
      expect(http_client).to have_received(:post).with('http://localhost/solr', '{delete: 2}', 'Content-type' => 'application/json')
    end

    it 'skips writing documents that have no id' do
      writer.send_batch([bad_doc])
      expect(http_client).to have_received(:post).with('http://localhost/solr', '{}', 'Content-type' => 'application/json')
    end

    it 'sends the request as a batch' do
      writer.send_batch([doc, skipped_doc])
      expect(http_client).to have_received(:post).with('http://localhost/solr', "{add: {\"doc\":{\"id\":[1]}},\ndelete: 2}", 'Content-type' => 'application/json')
    end
  end
end
