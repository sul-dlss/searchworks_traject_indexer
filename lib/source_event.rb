# frozen_string_literal: true

# A source record together with the Kafka position that controls its ordering
# and checkpoint. Readers create SourceEvents; the streaming runner does not
# need to know how an SDR or FOLIO payload is decoded.
class SourceEvent
  attr_reader :source, :message, :record, :operation, :id, :error

  def initialize(source:, message:, record: nil, operation: :upsert, id: nil, error: nil) # rubocop:disable Metrics/ParameterLists
    @source = source.to_sym
    @message = message
    @record = record
    @operation = operation.to_sym
    @id = id&.to_s
    @error = error
  end

  def failed?
    !error.nil?
  end

  def delete?
    operation == :delete
  end

  def skip?
    operation == :skip
  end

  def key
    message_attribute(:key)
  end

  def value
    message_attribute(:value)
  end

  def topic
    message_attribute(:topic)
  end

  def partition
    message_attribute(:partition)
  end

  def offset
    message_attribute(:offset)
  end

  def create_time
    message_attribute(:create_time)
  end

  def position
    { topic:, partition:, offset: }
  end

  private

  def message_attribute(name)
    message.public_send(name) if message.respond_to?(name)
  end
end
