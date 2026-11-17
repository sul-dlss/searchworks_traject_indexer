# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StreamingIndexer::QuarantineWriter do
  subject(:writer) do
    described_class.new(kafka: nil, topic: 'failures', retry_policy:, producer:)
  end

  let(:producer) { double(produce: nil, deliver_messages: nil, shutdown: nil) }
  let(:retry_policy) do
    StreamingIndexer::RetryPolicy.new(max_attempts: 3, base_interval: 0, sleeper: Kernel, random: Random)
  end
  let(:message) do
    double(
      topic: 'source', partition: 2, offset: 42, key: 'abc', value: '{"id":"abc"}', create_time: Time.utc(2026, 1, 1)
    )
  end
  let(:event) { SourceEvent.new(source: :sdr, message:, id: 'abc') }
  let(:failure) { StreamingIndexer::Failure.new(event:, stage: :mapping, error: ArgumentError.new('bad'), id: 'abc', attempts: 1) }

  it 'publishes enough source information to restart a failed record' do
    writer.write([failure])

    expect(producer).to have_received(:produce) do |json, options|
      payload = JSON.parse(json)
      expect(options).to eq(key: 'source:2:42', topic: 'failures')
      expect(payload).to include(
        'source_topic' => 'source',
        'source_partition' => 2,
        'source_offset' => 42,
        'source_key' => 'abc',
        'source_value_encoding' => 'gzip+base64',
        'stage' => 'mapping',
        'error_class' => 'ArgumentError'
      )
      expect(Zlib.gunzip(Base64.strict_decode64(payload['source_value_gzip_base64']))).to eq('{"id":"abc"}')
    end
    expect(producer).to have_received(:deliver_messages)
  end
end
