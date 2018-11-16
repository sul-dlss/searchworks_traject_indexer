require 'kafka'
require 'manticore' if defined? JRUBY_VERSION

class Traject::PurlFetcherKafkaExtractor
  attr_reader :first_modified, :kafka, :topic

  def initialize(first_modified:, kafka:, topic:)
    @first_modified = first_modified
    @kafka = kafka
    @topic = topic
  end

  def process!
    changes(first_modified: first_modified).each do |change|
      producer.produce(change.to_json, key: change['druid'], topic: topic)
    end

    deletes(first_modified: first_modified).each do |change|
      producer.produce(nil, key: change['druid'], topic: topic)
    end

    producer.deliver_messages
    producer.shutdown
    @producer = nil
  end

  private

  def producer
    @producer ||= kafka.async_producer(
      # Trigger a delivery once 10 messages have been buffered.
      delivery_threshold: 10,

      # Trigger a delivery every 30 seconds.
      delivery_interval: 30,
      max_queue_size: 10000000
    )
  end

  ##
  # @return [Enumerator]
  def changes(params = {})
    paginated_get('/docs/changes', 'changes', params)
  end

  ##
  # @return [Enumerator]
  def deletes(params = {})
    paginated_get('/docs/deletes', 'deletes', params)
  end

  ##
  # @return [Hash] a parsed JSON hash
  def get(path, params = {})
    JSON.parse(fetch('https://purl-fetcher.stanford.edu' + path, params))
  end

  def fetch(url, params)
    if defined?(JRUBY_VERSION)
      Manticore.get(url, query: params).body
    else
      HTTP.get(url, params: params).body
    end
  end

  ##
  # For performance, and enumberable object is returned.
  #
  # @example operating on each of the results as they come in
  #   paginated_get('/docs/changes', 'changes').map { |v| puts v.inspect }
  #
  # @example getting all of the results and converting to an array
  #   paginated_get('/docs/changes', 'changes').to_a
  #
  # @return [Enumerator] an enumberable object
  def paginated_get(path, accessor, options = {})
    Enumerator.new do |yielder|
      params   = options.dup
      per_page = params.delete(:per_page) { 100 }
      page     = params.delete(:page) { 1 }
      max      = params.delete(:max) { 1_000_000 }
      total    = 0

      loop do
        data = get(path, { per_page: per_page, page: page }.merge(params))

        total += data[accessor].length

        data[accessor].each do |element|
          yielder.yield element
        end

        page = data['pages']['next_page']

        break if page.nil? || total >= max
      end
    end
  end
end
