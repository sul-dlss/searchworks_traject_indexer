# frozen_string_literal: true

module StreamingIndexer
  class RetryPolicy
    attr_reader :max_attempts

    def initialize(max_attempts: 3, base_interval: 1.0, sleeper: Kernel, random: Random, metrics: nil)
      @max_attempts = Integer(max_attempts)
      @base_interval = Float(base_interval)
      @sleeper = sleeper
      @random = random
      @metrics = metrics || Metrics::Null.new
      raise ArgumentError, 'max_attempts must be positive' unless @max_attempts.positive?
    end

    def call(stage:, retry_if: nil)
      attempts = 0

      begin
        attempts += 1
        yield(attempts)
      rescue StandardError => e
        raise if attempts >= max_attempts
        raise if retry_if && !retry_if.call(e)

        @metrics.retry(stage:)
        @sleeper.sleep(backoff(attempts))
        retry
      end
    end

    private

    def backoff(attempt)
      maximum = @base_interval * (2**(attempt - 1))
      @random.rand((0.5 * maximum)..maximum)
    end
  end
end
