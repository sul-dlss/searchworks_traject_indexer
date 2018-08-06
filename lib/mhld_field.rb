##
# Class used for containing mhld display information
class MhldField
  attr_accessor :fields866, :fields867, :fields868, :patterns853,
                :most_recent863link_num, :most_recent863seq_num,
                :most_recent863, :library, :location, :public_note,
                :df852has_equals_sf, :library_has

  def initialize
    @fields866 = []
    @fields867 = []
    @fields868 = []
    @patterns853 = {}
    @most_recent863link_num = 0
    @most_recent863seq_num = 0
    @most_recent863 = nil
  end

  def latest_received
    get863display_value(patterns853[most_recent863link_num]) if most_recent_has_been_updated
  end

  def most_recent_has_been_updated
    most_recent863 && most_recent863link_num != 0
  end

  ##
  # Ported over algorithm from solrmarc-sw
  # MHLD records put the pattern of the enumeration in an 853, and the values
  # for each issue received into the 863. To get a user friendly string, the
  # captions from the 853 must be applied to the values in the 863. NOTE: the
  # match between the 853 and 863 linkage numbers should be done before
  # calling this method.
  def get863display_value(pattern853)
    return unless pattern853
    result = ''
    [*'a'..'f'].map do |char|
      caption = pattern853.subfields.select { |sf| sf.code == char }.collect(&:value).first
      value = most_recent863.subfields.select { |sf| sf.code == char }.collect(&:value).first
      break unless caption && value
      result += ':' unless result.empty?
      result += get_captioned(caption, value)
    end
    alt_scheme = ''
    [*'g'..'h'].map do |char|
      caption = pattern853.subfields.select { |sf| sf.code == char }.collect(&:value).first
      value = most_recent863.subfields.select { |sf| sf.code == char }.collect(&:value).first
      break unless caption && value
      alt_scheme += ', ' if char != 'g'
      alt_scheme += "#{caption}#{value}"
    end
    result += ":(#{alt_scheme})" unless alt_scheme.empty?
    prepender = ''
    shall_i_prepend = false
    chronology = ''
    [*'i'..'m'].map do |char|
      caption = pattern853.subfields.select { |sf| sf.code == char }.collect(&:value).first
      value = most_recent863.subfields.select { |sf| sf.code == char }.collect(&:value).first
      break unless caption && value
      case caption
      when /(\(month\)|\(season\)|\(unit\))/i
        value = translate_month_or_season(value)
        prepender = ':'
      when /\(day\)/i
        prepender = ' '
      end
      chronology += if shall_i_prepend
                      "#{prepender}#{value}"
                    else
                      value
                    end
      shall_i_prepend = true
    end
    unless chronology.empty?
      result += if !result.empty?
                  " (#{chronology})"
                else
                  chronology
                end
    end
    result
  end

  def get_captioned(caption, value)
    value = translate_month_or_season(value) if caption =~ /(\(month\)|\(season\))/i
    caption = '' if caption =~ /^\(.*\)$/
    "#{caption}#{value}"
  end

  def translate_month_or_season(value)
    value.gsub('01', 'January')
         .gsub('02', 'February')
         .gsub('03', 'March')
         .gsub('04', 'April')
         .gsub('05', 'May')
         .gsub('06', 'June')
         .gsub('07', 'July')
         .gsub('08', 'August')
         .gsub('09', 'September')
         .gsub('10', 'October')
         .gsub('11', 'November')
         .gsub('12', 'December')
         .gsub('13', 'Spring')
         .gsub('14', 'Summer')
         .gsub('15', 'Autumn')
         .gsub('16', 'Winter')
         .gsub('21', 'Spring')
         .gsub('22', 'Summer')
         .gsub('23', 'Autumn')
         .gsub('24', 'Winter')
  end

  def display(latest_received)
    [
      library, location,
      public_note, library_has,
      latest_received
    ].join(' -|- ')
  end
end
