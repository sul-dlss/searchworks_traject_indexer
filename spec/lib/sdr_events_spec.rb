# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SdrEvents do
  let(:druid) { 'ab123cd4567' }
  let(:target) { 'Searchworks' }

  before do
    allow(Settings.sdr_events).to receive(:enabled).and_return(true)
    allow(Dor::Event::Client).to receive(:create)
  end

  describe '#report_indexing_success' do
    it 'creates an event' do
      described_class.report_indexing_success(druid, target:)
      expect(Dor::Event::Client).to have_received(:create).with(
        druid: "druid:#{druid}",
        type: 'indexing_success',
        data: { host: Socket.gethostname, invoked_by: 'indexer', target: }
      )
    end
  end

  describe '#report_indexing_deleted' do
    it 'creates an event' do
      described_class.report_indexing_deleted(druid, target:)
      expect(Dor::Event::Client).to have_received(:create).with(
        druid: "druid:#{druid}",
        type: 'indexing_deleted',
        data: { host: Socket.gethostname, invoked_by: 'indexer', target: }
      )
    end
  end

  describe '#report_indexing_skipped' do
    it 'creates an event with message' do
      described_class.report_indexing_skipped(druid, target:, message: 'Problem with metadata')
      expect(Dor::Event::Client).to have_received(:create).with(
        druid: "druid:#{druid}",
        type: 'indexing_skipped',
        data: { host: Socket.gethostname, invoked_by: 'indexer', message: 'Problem with metadata', target: }
      )
    end
  end

  describe '#report_indexing_errored' do
    it 'creates an event with message and context' do
      described_class.report_indexing_errored(druid, target:, message: 'Indexing errored', context: 'stack trace')
      expect(Dor::Event::Client).to have_received(:create).with(
        druid: "druid:#{druid}",
        type: 'indexing_errored',
        data: { host: Socket.gethostname, invoked_by: 'indexer', message: 'Indexing errored', context: 'stack trace', target: }
      )
    end
  end
end
