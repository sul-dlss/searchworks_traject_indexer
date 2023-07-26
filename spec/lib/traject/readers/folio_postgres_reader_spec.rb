# frozen_string_literal: true

require 'spec_helper'
require 'traject/readers/folio_postgres_reader'

RSpec.describe Traject::FolioPostgresReader, if: ENV.key?('DATABASE_URL') do
  before do
    WebMock.enable_net_connect!
  end
  context 'with a delta for a whole day' do
    let(:date) { Time.now.advance(days: -1) }
    let(:timeout_in_milliseconds) { 1000 * 60 } # 1 minute max
    subject(:reader) do
      described_class.new(nil, 'folio.updated_after' => date,
                               'postgres.url' => ENV.fetch('DATABASE_URL'),
                               'statement_timeout' => timeout_in_milliseconds)
    end

    # This test enables us to benchmark the query speed.  Against the folio-test db, I see results in 5s on 2023-07-25
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

    # This test enables us to benchmark the query speed.  Against the folio-test db, I see results in ~45s on 2023-07-25
    it 'creates FolioRecords' do
      begin
        result = reader.to_a.last
      rescue PG::QueryCanceled
        raise "Query took too longer than #{timeout_in_milliseconds} milliseconds."
      end
      expect(result).to be_a FolioRecord
    end
  end
end
