class Traject::DeleteReader
  attr_reader :input_stream

  def initialize(input_stream, settings)
    @settings = Traject::Indexer::Settings.new settings
    @input_stream = input_stream
  end

  def each(*args, &block)
    return to_enum(:each) unless block_given?

    input_stream.each do |ckey|
      yield({ id: ckey, delete: true })
    end
  end
end
