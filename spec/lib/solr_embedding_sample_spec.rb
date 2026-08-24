# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SolrEmbeddingSample do
  subject(:sample) { described_class.new(reader:, processor:, batch_size: 100) }

  let(:reader) { instance_double(SolrDocumentReader) }
  let(:processor) { instance_double(EmbeddingProcessor, process: nil) }
  let(:documents) do
    [
      {
        'id' => '1',
        'context_source_ssi' => 'folio',
        'title_full_display' => 'First title'
      },
      {
        'id' => 'ab123cd4567',
        'context_source_ssi' => 'sdr',
        'title_full_display' => 'Second title'
      }
    ]
  end

  before do
    allow(reader).to receive(:each).with(limit: 2).and_return(documents.each)
  end

  it 'builds and synchronously processes canonical jobs from main Solr documents' do
    expect(sample.run(limit: 2)).to eq 2

    expect(processor).to have_received(:process).with(
      [
        hash_including(
          'id' => '1',
          'operation' => 'upsert',
          'input' => 'title: First title | text:',
          'source' => 'folio',
          'model' => 'gemini-embedding-2',
          'dimensions' => 768
        ),
        hash_including(
          'id' => 'ab123cd4567',
          'operation' => 'upsert',
          'input' => 'title: Second title | text:',
          'source' => 'sdr'
        )
      ]
    )
  end

  it 'requires the source field produced by the main indexers' do
    documents.first.delete('context_source_ssi')

    expect { sample.run(limit: 2) }.to raise_error(ArgumentError, /context_source_ssi/)
    expect(processor).not_to have_received(:process)
  end
end
