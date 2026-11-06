# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EmbeddingJob do
  describe '.from_context' do
    let(:context) do
      Traject::Indexer::Context.new.tap do |context|
        context.output_hash['id'] = ['123']
        context.output_hash['title_full_display'] = ['A title']
      end
    end

    it 'builds a versioned upsert job with a content hash' do
      job = described_class.from_context(context, source: 'folio')

      expect(job.as_json).to eq(
        id: '123',
        operation: 'upsert',
        input: 'title: A title | text:',
        input_hash: "sha256:#{Digest::SHA256.hexdigest('title: A title | text:')}",
        schema_version: 'searchworks-bib-v1',
        source: 'folio',
        model: 'gemini-embedding-2',
        dimensions: 768
      )
    end

    it 'builds an explicit delete job for a skipped context' do
      context.skip!('Delete')

      expect(described_class.from_context(context, source: 'sdr').as_json).to eq(
        id: '123',
        operation: 'delete',
        schema_version: 'searchworks-bib-v1',
        source: 'sdr'
      )
    end

    it 'returns nil when the context has no id' do
      context.output_hash.delete('id')

      expect(described_class.from_context(context, source: 'folio')).to be_nil
    end
  end
end
