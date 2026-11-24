# frozen_string_literal: true

require 'json'
require 'uri'

module StreamingIndexer
  # Synchronous, acknowledgment-returning Solr sink. A source checkpoint may
  # advance only after this object returns a success or a per-record failure.
  class SolrSink
    class RequestFailed < Error
      attr_reader :status, :body

      def initialize(message, status: nil, body: nil)
        @status = status
        @body = body
        super(message)
      end
    end

    Result = Data.define(:succeeded, :failed)

    def initialize(settings, retry_policy:, metrics: nil)
      @settings = Traject::Indexer::Settings.new(settings)
      @retry_policy = retry_policy
      @metrics = metrics || Metrics::Null.new
      @update_url = determine_update_url
      @basic_auth = extract_basic_auth!
      @http_client = @settings['streaming.solr.http_client'] || build_http_client
      @batch_size = [Integer(@settings.fetch('streaming.solr.batch_size', 100)), 1].max
    end

    def write(operations)
      succeeded = []
      failed = []

      operations.each_slice(@batch_size) do |batch|
        send_with_retries(batch)
        succeeded.concat(batch)
      rescue StandardError => e
        if batch.one?
          failed << failure(batch.first, e)
        else
          isolate(batch, succeeded:, failed:)
        end
      end

      Result.new(succeeded:, failed:)
    end

    def close
      return unless @settings['solr_writer.commit_on_close'].to_s == 'true'

      @retry_policy.call(stage: :solr) { request(JSON.generate(commit: {})) }
    end

    private

    def isolate(batch, succeeded:, failed:)
      batch.each do |operation|
        send_with_retries([operation])
        succeeded << operation
      rescue StandardError => e
        failed << failure(operation, e)
      end
    end

    def failure(operation, error)
      Failure.new(
        event: operation.event,
        stage: :solr,
        error:,
        id: operation.id,
        attempts: @retry_policy.max_attempts
      )
    end

    def send_with_retries(operations)
      @retry_policy.call(stage: :solr) { request(generate_json(operations)) }
    end

    def request(body)
      response = @http_client.post(@update_url, body, 'Content-type' => 'application/json')
      return response if (200..299).cover?(response.status.to_i)

      raise RequestFailed.new(
        "Solr returned HTTP #{response.status}",
        status: response.status,
        body: response.respond_to?(:body) ? response.body.to_s : nil
      )
    rescue RequestFailed
      raise
    rescue StandardError => e
      raise RequestFailed, "Solr request failed: #{e.class}: #{e.message}"
    end

    def generate_json(operations)
      commands = operations.map do |operation|
        if operation.add?
          "\"add\":#{JSON.generate(doc: operation.document)}"
        else
          "\"delete\":#{JSON.generate(operation.id)}"
        end
      end
      commands.join(",\n").prepend('{').concat('}')
    end

    def determine_update_url
      return @settings['solr.update_url'] if @settings['solr.update_url'].present?

      solr_url = @settings['solr.url'].to_s
      raise ArgumentError, 'solr.url or solr.update_url is required' if solr_url.empty?

      "#{solr_url.chomp('/')}/update"
    end

    def build_http_client
      HTTPClient.new.tap do |client|
        timeout = Float(@settings.fetch('streaming.solr.timeout', 60))
        client.connect_timeout = timeout
        client.receive_timeout = timeout
        client.send_timeout = timeout
        client.ssl_config.set_default_paths
        configure_basic_auth(client)
      end
    end

    def configure_basic_auth(client)
      user, password = @basic_auth
      return unless user || password

      client.set_auth(@update_url, user, password)
    end

    def extract_basic_auth!
      uri = URI.parse(@update_url)
      credentials = [
        @settings['solr_writer.basic_auth_user'] || uri.user,
        @settings['solr_writer.basic_auth_password'] || uri.password
      ]
      uri.user = nil
      uri.password = nil
      @update_url = uri.to_s
      credentials
    end
  end
end
