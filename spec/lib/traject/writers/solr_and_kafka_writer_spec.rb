# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Traject::SolrAndKafkaWriter do
  subject(:writer) do
    described_class.new(
      'composite.solr_writer' => solr_writer,
      'composite.embedding_writer' => embedding_writer
    )
  end

  let(:solr_writer) do
    instance_double(Traject::SolrBetterJsonWriter, put: nil, close: nil, skipped_record_count: 2)
  end
  let(:embedding_writer) { instance_double(Traject::KafkaEmbeddingJobWriter, put: nil, close: nil) }
  let(:context) { Traject::Indexer::Context.new }

  it 'writes each mapped context to Solr and Kafka' do
    writer.put(context)

    expect(solr_writer).to have_received(:put).with(context)
    expect(embedding_writer).to have_received(:put).with(context)
  end

  it 'writes skipped contexts so both writers can emit deletes' do
    expect(writer.write_skipped_records?).to be true
  end

  it 'reports the Solr skipped record count' do
    expect(writer.skipped_record_count).to eq 2
  end

  it 'closes both writers' do
    writer.close

    expect(solr_writer).to have_received(:close)
    expect(embedding_writer).to have_received(:close)
  end

  it 'still closes the embedding writer when closing the Solr writer fails' do
    allow(solr_writer).to receive(:close).and_raise('Solr close failed')

    expect { writer.close }.to raise_error('Solr close failed')
    expect(embedding_writer).to have_received(:close)
  end
end
