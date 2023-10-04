# frozen_string_literal: true

module Folio
  class Holdings
    YEAR_REGEX = /(?:18|19|20)\d{2}/
    # We've seen chronologies that looks like full dates, MON YYYY, WIN YYYY, and nil
    # We've also seen chronologies with slashes designating a range
    def self.find_latest(holdings)
      # NOTE: We saw some piece records without 'chronology'. Was this just test data?
      pieces = holdings.filter_map do |piece|
        piece.merge(sortable_date: sortable_date(piece),
                    sortable_tokens: sortable_tokens(piece))
      end
      pieces.max_by { |piece| [piece.fetch(:sortable_date), piece.fetch(:sortable_tokens), piece['enumeration']] }
    end

    # @return [Date] a date derived from chronology, enumeration or a really old date (sorts to back) if none are found
    def self.sortable_date(piece)
      extract_sortable_date(piece['chronology']) ||
        extract_sortable_date(piece['enumeration']) ||
        Date.parse('1000-01-01')
    end

    # @return [Array<Integer>] a list of integer tokens derived from chronology and enumeration.
    def self.sortable_tokens(piece)
      Array(
        extract_sortable_tokens(piece['chronology']) ||
          extract_sortable_tokens(piece['enumeration'])
      )
    end

    # Look for other tokens, which are not dates, that can be used to sort.
    # We need to exclude dates so this field can be used as a tie-breaker
    def self.extract_sortable_tokens(str)
      return unless str.present?

      tokens = str.scan(/\d+/).grep_v(YEAR_REGEX)
      tokens.map(&:to_i) if tokens.present?
    end

    # Find any dates that are present in the fields
    def self.extract_sortable_date(date_str)
      return unless date_str

      if date_str.include?('/')
        extract_multiple_sortable_dates(date_str).max
      else
        extract_single_sortable_date(date_str)
      end
    end

    # Parse the date or extract the year when  we assume only one date is represented
    def self.extract_single_sortable_date(date_str)
      return unless date_str

      begin
        return Date.parse(date_str) # handles MON YYYY
      rescue Date::Error
        nil
      end

      # If Date parsing does not work, e.g. "2012" or "Win 2012",
      # look for numbers that match a year expression,
      # and return the most recent/max year
      return unless (years = date_str.scan(YEAR_REGEX).presence)

      max_year = years.map(&:to_i).max
      Date.parse("#{max_year}-01-01")
    end

    def self.extract_multiple_sortable_dates(date_str)
      # Break apart on spaces, after replacing commas with spaces
      ds = date_str.gsub(',', ' ')
      ds_array = ds.split(/\s+/)
      ds_tokens = []
      # For each portion of the string, check if a slash is present and create an array 
      # e.g. "Dec/Jan 2016" would become [["Dec", "Jan"] ["2016"]]
      ds_array.each do |d|
        ds_tokens.push(d.split('/'))
      end

      # Break apart combined dates into separate date strings
      # e.g. Dec/Jan 2/23 2015/2016 = Dec 2 2015, Jan 23 2016
      generated_dates = generate_dates(ds_tokens)
      # For each of these strings, extract Date.parse compatible format
      # or extract a year 
      generated_dates.map { |gd| extract_single_sortable_date(gd) }
    end

    # ds_tokens is an array of arrays representing each portion of the date string
    # E.g. [["Dec", "Jan"] ["2", "3"] ["2016", "2017"]] should result in
    # the strings "Dec 2 2016" and "Jan 3 2017"
    def self.generate_dates(ds_tokens)
      generated_dates = []
      ds_tokens.each do |ds_token|
        if generated_dates.empty?
          # In the very first iteration, add the elements of the array to separate strings
          # e.g. ["Dec", "Jan"] should map to two strings, one starting with "Dec", 
          # the other starting with "Jan".
          # The array of final strings should thus be ["Dec", "Jan"]
          generated_dates.concat(ds_token)
        else
          ds_length = ds_token.length
          gd_length = generated_dates.length
          # E.g. If the final array already has string portions (e.g. ["Dec", "Jan"]),
          # and the next token has only one string "16", add "16" to both strings
          # i.e. ["Dec 16", "Jan 16"]  
          if ds_length == 1
            generated_dates.map! { |gd| "#{gd} #{ds_token[0]}" }
          # if the number of split tokens is the same as what we already have, we need to add 
          # to each string separately. E.g. if the original string started with "Dec/Jan 6/7",
          # we already have ["Dec", "Jan"], and our next set of tokens is ["6", "7"],
          # so we'll append each string with the corresponding index in the other array:
          # ["Dec 6", "Dec 7"]
          elsif ds_length == gd_length
            generated_dates = generated_dates.map.with_index { |v, i| "#{v} #{ds_token[i]}" }
          # E.g. If our string was "Dec 7/8", then we would already have  ["Dec"]
          # in generated_dates, and want to create ["Dec 7", "Dec 8"]
          elsif gd_length == 1 && ds_length > gd_length
            gd_first = generated_dates[0]
            generated_dates[0] += " #{ds_token[0]}"
            1.upto(ds_length - 1) do |i|
              generated_dates[i] = "#{gd_first} #{ds_token[i]}"
            end
          end
        end
      end
      generated_dates
    end
  end
end
