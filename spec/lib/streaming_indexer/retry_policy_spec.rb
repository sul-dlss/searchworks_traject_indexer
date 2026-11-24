# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StreamingIndexer::RetryPolicy do
  subject(:policy) do
    described_class.new(max_attempts: 3, base_interval: 0, sleeper:, random:, metrics:)
  end

  let(:sleeper) { class_double(Kernel, sleep: nil) }
  let(:random) { class_double(Random, rand: 0) }
  let(:metrics) { instance_double(StreamingIndexer::Metrics::Null, retry: nil) }

  it 'retries failures up to three total attempts' do
    attempts = 0

    expect do
      policy.call(stage: :solr) do
        attempts += 1
        raise 'broken'
      end
    end.to raise_error(RuntimeError, 'broken')

    expect(attempts).to eq 3
    expect(metrics).to have_received(:retry).with(stage: :solr).twice
  end

  it 'returns as soon as an attempt succeeds' do
    attempts = 0
    result = policy.call(stage: :solr) do
      attempts += 1
      raise 'transient' if attempts == 1

      :ok
    end

    expect(result).to eq :ok
    expect(attempts).to eq 2
  end

  it 'does not retry an error rejected by the retry predicate' do
    attempts = 0

    expect do
      policy.call(stage: :embedding_gateway, retry_if: ->(error) { error.is_a?(IOError) }) do
        attempts += 1
        raise ArgumentError, 'invalid request'
      end
    end.to raise_error(ArgumentError, 'invalid request')

    expect(attempts).to eq 1
    expect(metrics).not_to have_received(:retry)
  end
end
