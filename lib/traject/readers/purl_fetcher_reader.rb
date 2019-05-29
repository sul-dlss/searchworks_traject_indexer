require 'manticore' if defined? JRUBY_VERSION

class Traject::PurlFetcherReader
  attr_reader :settings

  def initialize(_input_stream, settings)
    @settings = Traject::Indexer::Settings.new settings
  end

  def each
    return to_enum(:each) unless block_given?

    changes(first_modified: first_modified).each do |change, meta|
      yield change, meta
    end

    deletes(first_modified: first_modified).each do |change, meta|
      yield change.merge(delete: true), meta
    end
  end

  private

  def first_modified
    settings['purl_fetcher.first_modified']
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
          yielder.yield element, { 'range' => data['range'], 'pages' => data['pages'] }
        end

        page = data['pages']['next_page']

        break if page.nil? || total >= max
      end
    end
  end
end
