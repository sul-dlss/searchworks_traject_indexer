module CallNumbers
  require 'forwardable'
  class CallNumberBase
    MONTHS = 'jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec'.freeze
    VOL_PARTS = 'bd|ed|hov|iss|issue|jahrg|new ser|no|part|pts?|ser|shanah|[^a-z]t|v|vols?|vyp'.freeze
    ADDL_VOL_PARTS = [
      'box', 'carton', 'fig', 'flat box', 'grade', 'half box',
      'half carton', 'index', 'large folder', 'large map folder',
      'map folder', 'mfilm', 'mfiche', 'os box', 'os folder', 'pl', 'reel',
      'sheet', 'small folder', 'small map folder', 'suppl', 'tube', 'series'
    ].freeze
    ADDL_VOL_PATTERN = /[\:\/]?(#{ADDL_VOL_PARTS.join('|')}).*/i
    VOL_PATTERN         = /([\.:\/\(])?(n\.s\.?\,? ?)?[\:\/]?(#{VOL_PARTS}|#{MONTHS})[\. -\/]?\d+([\/-]\d+)?( \d{4}([\/-]\d{4})?)?( ?suppl\.?)?/i
    VOL_PATTERN_LOOSER  = /([\.:\/\(])?(n\.s\.?\,? ?)?[\:\/]?(#{VOL_PARTS}|#{MONTHS})[\. -]?\d+.*/i
    VOL_PATTERN_LETTERS = /([\.:\/\(])?(n\.s\.?\,? ?)?[\:\/]?(#{VOL_PARTS}|#{MONTHS})[\/\. -]?[A-Z]?([\/-][A-Z]+)?.*/i
    FOUR_DIGIT_YEAR_REGEX = /\W *(20|19|18|17|16|15|14)\d{2}\D?$?/
    LOOSE_MONTHS_REGEX = /([\.:\/\(])? *#{MONTHS}/i

    extend Forwardable
    delegate %i[to_shelfkey to_reverse_shelfkey] => :shelfkey

    def scheme
      raise NotImplementedError
    end

    def lopped
      raise NotImplementedError
    end

    def to_lopped_shelfkey
      self.class.new(lopped, serial: serial).to_shelfkey
    end

    def to_lopped_reverse_shelfkey
      self.class.new(lopped, serial: serial).to_reverse_shelfkey
    end

    class << self
      def lop_years(value)
        month_b4_year = value[0...(value.index(LOOSE_MONTHS_REGEX) || value.length)]
        year_b4_month = value[0...(value.index(FOUR_DIGIT_YEAR_REGEX) || value.length)]
        shortest_lopped = [month_b4_year, year_b4_month].min_by(&:length)
        return value if shortest_lopped.length < 4
        shortest_lopped
      end
    end

    private

    def shelfkey
      shelfkey_class.new(self)
    end

    def shelfkey_class
      raise NotImplementedError
    end
  end
end
