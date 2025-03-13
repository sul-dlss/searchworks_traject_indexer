# frozen_string_literal: true

module Folio
  class SortableDateParser
    # This regex expression is used in scanning strings for years
    YEAR_REGEX = /(?:18|19|20)\d{2}/
    # This regex is used against the year portion of the result of Date.parse
    EXACT_YEAR_REGEX = /^\s*(?:18|19|20)\d{2}$/

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

      parse_date(date_str) || scan_date(date_str)
    end

    def self.parse_date(date_str)
      parsed_date = Date.parse(date_str) # handles MON YYYY
      # If correct, the string after parsing should be YYYY-MM-DD
      # This regex will match a year 2024 but not 202424
      parsed_date if parsed_date.to_s.include?('-') && EXACT_YEAR_REGEX.match(parsed_date.to_s.split('-')[0])
    rescue Date::Error
      nil
    end

    def self.scan_date(date_str)
      # If Date parsing does not work, e.g. "2012" or "Win 2012",
      # look for numbers that match a year expression,
      # and return the most recent/max year
      return unless (years = date_str.scan(YEAR_REGEX).presence)

      max_year = years.map(&:to_i).max
      Date.parse("#{max_year}-01-01")
    end

    def self.extract_multiple_sortable_dates(date_str)
      # Break apart on spaces, after replacing commas with spaces
      ds = date_str.gsub(/[,:]/, ' ')
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
      generated_dates.filter_map { |gd| extract_single_sortable_date(gd) }
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
