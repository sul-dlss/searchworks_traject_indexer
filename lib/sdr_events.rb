# frozen_string_literal: true

require 'socket'

# Reports indexing events to SDR via message queue
# See: https://github.com/sul-dlss/dor-event-client
# See also the HTTP API: https://sul-dlss.github.io/dor-services-app/#tag/events
class SdrEvents
  class << self
    def configure(
      hostname: ENV.fetch('SDR_EVENTS_MQ_HOSTNAME', ::Settings.sdr_events.mq.hostname),
      vhost: ENV.fetch('SDR_EVENTS_MQ_VHOST', ::Settings.sdr_events.mq.vhost),
      username: ENV.fetch('SDR_EVENTS_MQ_USERNAME', ::Settings.sdr_events.mq.username),
      password: ENV.fetch('SDR_EVENTS_MQ_PASSWORD', ::Settings.sdr_events.mq.password)
    )
      Dor::Event::Client.configure(hostname:, vhost:, username:, password:)
    end

    def enabled?
      ::Settings.sdr_events.enabled
    end

    # Item was added/updated in the index
    def report_indexing_success(druid, target:)
      create_event(druid:, target:, type: 'indexing_success')
    end

    # Item was removed from the index (e.g. via unrelease)
    def report_indexing_deleted(druid, target:)
      create_event(druid:, target:, type: 'indexing_deleted')
    end

    # Item has missing or inappropriately formatted metadata
    def report_indexing_skipped(druid, target:, message:)
      create_event(druid:, target:, type: 'indexing_skipped', data: { message: })
    end

    # Exception was raised during indexing; provides optional context
    def report_indexing_errored(druid, target:, message:, context: nil)
      create_event(druid:, target:, type: 'indexing_errored', data: { message:, context: }.compact)
    end

    # Take a SolrBetterJsonWriter::Batch and report successful adds/deletes
    def report_indexing_batch_success(batch, target:)
      batch.actions.each do |action, druid, _data|
        next unless druid

        case action
        when :delete
          report_indexing_deleted(druid, target:)
        when :add
          report_indexing_success(druid, target:)
        end
      end
    end

    # Take a SolrBetterJsonWriter::Batch and report failed adds/deletes
    def report_indexing_batch_errored(batch, target:, exception:)
      batch.actions.each do |action, druid, _data|
        next unless druid

        case action
        when :delete
          report_indexing_errored(druid, target:, message: 'delete failed', context: exception)
        when :add
          report_indexing_errored(druid, target:, message: 'add failed', context: exception)
        end
      end
    end

    private

    # Generic event creation; prefer more specific methods
    def create_event(druid:, target:, type:, data: {})
      Dor::Event::Client.create(
        druid: "druid:#{druid}",
        type:,
        data: {
          target:,
          host:,
          invoked_by: 'indexer'
        }.merge(data)
      ) if enabled?
    end

    # Hostname of the machine running the indexer
    def host
      @host ||= Socket.gethostname
    end
  end
end
