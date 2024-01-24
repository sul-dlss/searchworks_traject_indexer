# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SdrEvents do
  let(:druid) { 'ab123cd4567' }

  before do
    allow(Settings.sdr_events).to receive(:enabled).and_return(true)
    allow(Dor::Event::Client).to receive(:create)
  end

  describe '#report_indexing_success' do
    it 'creates an event' do
      SdrEvents.report_indexing_success(druid)
      expect(Dor::Event::Client).to have_received(:create).with(
        druid: "druid:#{druid}",
        type: 'indexing_success',
        data: { host: Socket.gethostname, invoked_by: 'indexer' }
      )
    end
  end

  describe '#report_indexing_deleted' do
    it 'creates an event' do
      SdrEvents.report_indexing_deleted(druid)
      expect(Dor::Event::Client).to have_received(:create).with(
        druid: "druid:#{druid}",
        type: 'indexing_deleted',
        data: { host: Socket.gethostname, invoked_by: 'indexer' }
      )
    end
  end

  describe '#report_indexing_skipped' do
    it 'creates an event with message' do
      SdrEvents.report_indexing_skipped(druid, message: 'Problem with metadata')
      expect(Dor::Event::Client).to have_received(:create).with(
        druid: "druid:#{druid}",
        type: 'indexing_skipped',
        data: { host: Socket.gethostname, invoked_by: 'indexer', message: 'Problem with metadata' }
      )
    end
  end

  describe '#report_indexing_errored' do
    it 'creates an event with message and context' do
      SdrEvents.report_indexing_errored(druid, message: 'Indexing errored', context: 'stack trace')
      expect(Dor::Event::Client).to have_received(:create).with(
        druid: "druid:#{druid}",
        type: 'indexing_errored',
        data: { host: Socket.gethostname, invoked_by: 'indexer', message: 'Indexing errored', context: 'stack trace' }
      )
    end
  end
end
