class Traject::DeleteReader
  attr_reader :input_stream

  def initialize(input_stream, settings)
    @settings = Traject::Indexer::Settings.new settings
    @input_stream = input_stream
  end

  def each(*args, &block)
    input_stream.each(*args, &block)
  end
end
