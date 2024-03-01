# frozen_string_literal: true

require 'spec_helper'
require 'benchmark'

# These test enables us to benchmark the query speed.
RSpec.describe Traject::FolioPostgresReader, if: ENV.key?('DATABASE_URL') do
  before do
    WebMock.enable_net_connect!
  end

  if RSpec.configuration.default_formatter == 'doc'
    around do |test|
      Benchmark.bm do |bm|
        bm.report do
          test.run
        end
      end
    end
  end

  # Benchmarking results:
  # (against the folio-test on 2023-07-25)
  # with a delta for a whole day
  #      user     system      total        real
  #  0.016099   0.008823   0.024922 (  4.396743)
  # with a chunk (of about 2.5k items)
  #      user     system      total        real
  #  0.799907   0.173947   0.973854 ( 45.960047)

  context 'with a delta for a whole day' do
    let(:date) { Time.now.advance(days: -1) }
    let(:timeout_in_milliseconds) { 1000 * 60 } # 1 minute max
    subject(:reader) do
      described_class.new(nil, 'folio.updated_after' => date,
                               'postgres.url' => ENV.fetch('DATABASE_URL'),
                               'statement_timeout' => timeout_in_milliseconds)
    end

    it 'creates FolioRecords' do
      begin
        result = reader.first
      rescue PG::QueryCanceled
        raise "Query took too longer than #{timeout_in_milliseconds} milliseconds."
      end
      expect(result).to be_a FolioRecord # This may not pass if no records have been updated since `date`
    end
  end

  context 'with a chunk (of about 2.5k items)' do
    subject(:reader) do
      described_class.new(nil, 'postgres.sql_filters' => [filter],
                               'postgres.url' => ENV.fetch('DATABASE_URL'),
                               'statement_timeout' => timeout_in_milliseconds)
    end
    let(:timeout_in_milliseconds) { 1000 * 60 * 3 } # 3 minutes max; this would be about 8 hours to dump all the records

    let(:filter) do
      # picking a random chunk to try to avoid any caching
      min = rand(0x0000..0xfff0)
      max = min + 0x0010
      "vi.id BETWEEN '#{min.to_s(16).rjust(4, '0')}0000-0000-0000-0000-000000000000' AND '#{max.to_s(16).rjust(4, '0')}ffff-ffff-ffff-ffff-ffffffffffff'"
    end

    it 'creates FolioRecords' do
      begin
        result = reader.to_a.last
      rescue PG::QueryCanceled
        raise "Query took too longer than #{timeout_in_milliseconds} milliseconds."
      end
      expect(result).to be_a FolioRecord
    end
  end

  context 'check encoding parsing' do
    encoding_sample_str_json = JSON.generate({ 'title1' => 'Strategii︠a︡ planirovanii︠a︡ izbiratelʹnoĭ kampanii',
                                               'title2' => 'Unencoded string',
                                               'title3' => 'Strategiii︠a planirovaniia︡ izbiratelʹnoĭ kampanii' })
    let(:encoded_string) do
      JSON.parse(described_class.encoding_cleanup(encoding_sample_str_json))
    end

    it 'encodes cyrilic correctly' do
      expect(encoded_string['title1']).to eq('Strategii͡a planirovanii͡a izbiratelʹnoĭ kampanii')
    end

    it 'returns unencoded string without change' do
      expect(encoded_string['title2']).to eq('Unencoded string')
    end

    it 'returns encoded string without change' do
      expect(encoded_string['title3']).to eq('Strategiii︠a planirovaniia︡ izbiratelʹnoĭ kampanii')
    end
  end
end
