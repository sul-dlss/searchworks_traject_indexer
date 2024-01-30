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
      ::Settings.sdr_events.enabled == true
    end

    # Item was added/updated in the index
    def report_indexing_success(druid)
      create_event(druid:, type: 'indexing_success')
    end

    # Item was removed from the index (e.g. via unrelease)
    def report_indexing_deleted(druid)
      create_event(druid:, type: 'indexing_deleted')
    end

    # Item has missing or inappropriately formatted metadata
    def report_indexing_skipped(druid, message:)
      create_event(druid:, type: 'indexing_skipped', data: { message: })
    end

    # Exception was raised during indexing; provides optional context
    def report_indexing_errored(druid, message:, context: nil)
      create_event(druid:, type: 'indexing_errored', data: { message:, context: }.compact)
    end

    private

    # Generic event creation; prefer more specific methods
    def create_event(druid:, type:, data: {})
      Dor::Event::Client.create(
        druid: "druid:#{druid}",
        type:,
        data: base_data.merge(data)
      ) if enabled?
    end

    # Logged with every event
    def base_data
      @base_data ||= {
        host: Socket.gethostname,
        invoked_by: 'indexer'
      }
    end
  end
end
