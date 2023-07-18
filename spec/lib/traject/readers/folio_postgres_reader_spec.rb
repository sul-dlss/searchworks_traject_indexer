# frozen_string_literal: true

require 'spec_helper'
require 'traject/readers/folio_postgres_reader'

RSpec.describe Traject::FolioPostgresReader, if: ENV.key?('DATABASE_URL') do
  before do
    WebMock.enable_net_connect!
  end
  let(:date) { Time.now.advance(days: -1) }
  let(:timeout_in_milliseconds) { 1000 * 60 * 3 } # Three minutes
  subject(:reader) do
    described_class.new(nil, 'folio.updated_after' => date,
                             'postgres.url' => ENV.fetch('DATABASE_URL'),
                             'statement_timeout' => timeout_in_milliseconds)
  end

  # This test enables us to benchmark the query speed.  Against the folio-test db, I see results in 30-90s on 2023-07-18
  it 'creates FolioRecords' do
    begin
      result = reader.first
    rescue PG::QueryCanceled
      raise "Query took too longer than #{timeout_in_milliseconds} milliseconds."
    end
    expect(result).to be_a FolioRecord # This may not pass if no records have been updated since `date`
  end
end
