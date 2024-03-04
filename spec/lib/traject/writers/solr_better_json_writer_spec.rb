# frozen_string_literal: true

require 'spec_helper'

describe Traject::SolrBetterJsonWriter do
  subject(:writer) do
    described_class.new(
      'solr_json_writer.http_client' => http_client,
      'solr.update_url' => 'http://localhost/solr',
      'solr_better_json_writer.debounce_timeout' => 1,
      'purl_fetcher.target' => 'Searchworks',
      'solr_writer.max_skipped' => 100
    )
  end

  let(:http_client) { double(post: double(status: 200)) }
  let(:doc) { Traject::Indexer::Context.new.tap { |doc| doc.output_hash['id'] = [1] } }
  let(:skipped_doc) do
    Traject::Indexer::Context.new.tap do |doc|
      doc.output_hash['id'] = [2]
      doc.skip!
    end
  end
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
      writer.put(doc)
      sleep 2
      expect(writer).to have_received(:send_batch).at_least(1).times
      writer.close
      expect(count).to eq 1
    end
  end

  describe '#send_batch' do
    it 'adds documents to solr' do
      writer.send_batch([doc])
      expect(http_client).to have_received(:post).with(
        'http://localhost/solr',
        '{"add":{"doc":{"id":[1]}}}',
        'Content-type' => 'application/json'
      )
    end

    it 'deletes documents from solr' do
      writer.send_batch([skipped_doc])
      expect(http_client).to have_received(:post).with(
        'http://localhost/solr',
        '{"delete":2}',
        'Content-type' => 'application/json'
      )
    end

    it 'skips writing documents that have no id' do
      writer.send_batch([bad_doc])
      expect(http_client).to have_received(:post).with(
        'http://localhost/solr',
        '{}',
        'Content-type' => 'application/json'
      )
    end

    it 'sends the request as a batch' do
      writer.send_batch([doc, skipped_doc])
      expect(http_client).to have_received(:post).with(
        'http://localhost/solr',
        "{\"add\":{\"doc\":{\"id\":[1]}},\n\"delete\":2}",
        'Content-type' => 'application/json'
      )
    end
  end

  describe 'event reporting' do
    let(:sdr_docs) do
      [
        Traject::Indexer::Context.new.tap do |doc|
          doc.output_hash['id'] = [1]
          doc.source_record = PublicXmlRecord.new('bb112zx3193')
        end,
        Traject::Indexer::Context.new.tap do |doc|
          doc.output_hash['id'] = [2]
          doc.source_record = PublicXmlRecord.new('py305sy7961')
        end
      ]
    end
    let(:folio_doc) do
      Traject::Indexer::Context.new.tap do |doc|
        doc.output_hash['id'] = [3]
        doc.source_record = FolioRecord.new_from_source_record(
          JSON.parse(File.read(file_fixture('a14185492.json'))),
          nil
        )
      end
    end

    before do
      allow(Settings.sdr_events).to receive(:enabled).and_return(true)
      allow(SdrEvents).to receive_messages(
        report_indexing_deleted: true,
        report_indexing_success: true,
        report_indexing_errored: true
      )
    end

    context 'when SDR events are disabled' do
      before do
        allow(Settings.sdr_events).to receive(:enabled).and_return(false)
        allow(Dor::Event::Client).to receive(:create)
      end

      it 'does not report any events' do
        writer.send_batch(sdr_docs)
        expect(Dor::Event::Client).not_to have_received(:create)
      end
    end

    context 'with a FolioRecord' do
      before do
        allow(Dor::Event::Client).to receive(:create)
      end

      it 'does not report any events' do
        writer.send_batch([folio_doc])
        expect(Dor::Event::Client).not_to have_received(:create)
      end
    end

    context 'when all docs index successfully' do
      it 'reports docs that are successfully added' do
        writer.send_batch(sdr_docs)
        expect(SdrEvents).to have_received(:report_indexing_success).with('bb112zx3193', target: 'Searchworks')
        expect(SdrEvents).to have_received(:report_indexing_success).with('py305sy7961', target: 'Searchworks')
      end

      it 'reports docs that are successfully deleted' do
        skipped_doc.source_record = PublicXmlRecord.new('bj057dg6517')
        writer.send_batch([skipped_doc])
        expect(SdrEvents).to have_received(:report_indexing_deleted).with('bj057dg6517', target: 'Searchworks')
      end
    end

    context 'when some docs fail to index' do
      let(:http_client) { double(post: double(status: 400, body: 'Malformed data')) }

      it 'reports docs that fail to index' do
        writer.send_batch(sdr_docs)
        expect(SdrEvents).to have_received(:report_indexing_errored).with(
          'bb112zx3193',
          target: 'Searchworks',
          message: 'add failed',
          context: 'Solr error response: 400: Malformed data'
        )
        expect(SdrEvents).to have_received(:report_indexing_errored).with(
          'py305sy7961',
          target: 'Searchworks',
          message: 'add failed',
          context: 'Solr error response: 400: Malformed data'
        )
      end
    end
  end
end
