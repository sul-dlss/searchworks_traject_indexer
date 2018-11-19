require 'kafka'

class Traject::KafkaMarcReader
  attr_reader :settings

  def initialize(input_stream, settings)
    @settings = Traject::Indexer::Settings.new settings
  end

  def each
    return to_enum(:each) unless block_given?

    return unless kafka.instance_variable_get(:@fetcher).data?

    kafka.each_message(max_bytes: 10000000) do |message|
      Utils.logger.debug("Traject::KafkaMarcReader#each(#{message.key})")

      if message.key == 'break'
        kafka.mark_message_as_processed(message)
        break
      elsif message.value.nil?
        yield({ id: message.key, delete: true })
      else
        Traject::MarcCombiningReader.new(StringIO.new(message.value), settings).each do |r|
          yield r
        end
      end
    end
  end

  private

  def kafka
    settings['kafka.consumer']
  end
end
