class CombiningEnumerable
  def initialize(left, right)
    @left = left
    @right = right
  end

  def each(*args, &block)
    return to_enum(:each, *args) unless block_given?
    @left.each(*args, &block)
    @right.each(*args, &block)
  end
end

class Traject::MarcCombiningReader
  include Enumerable

  attr_reader :settings, :input_stream, :marc_reader

  def initialize(input_stream, settings)
    if defined?(JRUBY_VERSION)
      require 'traject/marc4j_reader'
      @marc_reader = Traject::Marc4JReader.new(input_stream, settings)
    else
      @marc_reader = Traject::MarcReader.new(input_stream, settings)
    end
  end

  def combinable_records
    return enum_for(:combinable_records) unless block_given?

    marc_reader.each.slice_when { |i, j| i['001'].value != j['001'].value }.each do |records_to_combine|
      yield records_to_combine
    end
  end

  def each
    return enum_for(:each) unless block_given?

    combinable_records.each do |records_to_combine|
      if records_to_combine.length == 1
        yield records_to_combine.first
      else
        record = MARC::Record.new

        first_record = records_to_combine.shift
        # if the first record in a set is an MHLD, give up and probably log an error message somewhere
        next if ['u', 'v', 'x', 'y'].include? first_record.leader[6]

        record.leader = first_record.leader
        record.instance_variable_get(:@fields).concat(first_record.instance_variable_get(:@fields))

        records_to_combine.each_with_index do |r, i|

          # An MHLD record is identified by the Leader/06 value. If leader/06 is any of these:
          #	u - Unknown
          #	v - Multipart item holdings
          #	x - Single-part item holdings
          #	y - Serial item holdings
          if ['u', 'v', 'x', 'y'].include? r.leader[6]
            record.instance_variable_get(:@fields).concat(r.fields(%w[852 853 863 866 867 868 999]))
          else
            record.instance_variable_get(:@fields).concat(r.fields('999'))
          end
        end

        record.instance_variable_get(:@fields).reindex

        yield record
      end
    end
  end
end
