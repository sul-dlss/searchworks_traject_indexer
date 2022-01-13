module Indexers
  def self.cached_indexers
    @cached_indexers ||= {}
  end

  def cached_indexer(filename)
    Indexers.cached_indexers[filename] ||= Traject::Indexer.new.tap do |i|
      i.load_config_file(filename)
    end
  end
end
