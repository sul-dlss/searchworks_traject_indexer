require 'csv'
require 'kafka'

class Traject::CrezMarcKafkaExtractor
  attr_reader :reserves_file, :kafka, :topic

  def initialize(reserves_file:, kafka:, topic:)
    @reserves_file = reserves_file
    @kafka = kafka
    @topic = topic
  end

  # Scan through the Kafka topic and re-send any messages for records with CREZ data
  def process!
    t0 = Time.now
    h = {}
    kafka.each_message(max_bytes: 10000000, topic: topic) do |message|
      break if message.create_time > t0
      next unless reserved?(message.key)

      # Store only the latest version of the record
      h[message.key] = message.value
    end

    h.each do |key, value|
      producer.produce(value, key: key, topic: topic)
    end

    producer.deliver_messages
    producer.shutdown
    @producer = nil
  end

  private

  def reserves_ckeys
    @reserves_ckeys ||= begin
      ckeys = {}

      File.open(reserves_file, 'r').each do |line|
        csv_options = {
          col_sep: '|', headers: 'rez_desk|resctl_exp_date|resctl_status|ckey|barcode|home_loc|curr_loc|item_rez_status|loan_period|rez_expire_date|rez_stage|course_id|course_name|term|instructor_name',
          header_converters: :symbol, quote_char: "\x00"
        }
        CSV.parse(line, csv_options) do |row|
          ckeys[row[:ckey]] = true
        end
      end

      ckeys
    end
  end

  def reserved? ckey
    reserves_ckeys[ckey]
  end

  def producer
    @producer ||= kafka.async_producer(
      # Trigger a delivery once 10 messages have been buffered.
      delivery_threshold: 10,

      # Trigger a delivery every 30 seconds.
      delivery_interval: 30,
      max_queue_size: 10000000
    )
  end
end
