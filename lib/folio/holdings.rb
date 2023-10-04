# frozen_string_literal: true

module Folio
  class Holdings
    YEAR_REGEX = /(?:19|20)\d{2}/
    # We've seen chronologies that looks like full dates, MON YYYY, WIN YYYY, and nil
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

    # Find any dates that are present in the fields
    def self.extract_sortable_date(date_str)
      return unless date_str

      if date_str.include?('/')
        max_multiple_dates(extract_multiple_sortable_dates(date_str))
      else
        extract_single_sortable_date(date_str)
      end
    end

    # Look for other tokens, which are not dates, that can be used to sort.
    # We need to exclude dates so this field can be used as a tie-breaker
    def self.extract_sortable_tokens(str)
      return unless str.present?

      tokens = str.scan(/\d+/).grep_v(YEAR_REGEX)
      tokens.map(&:to_i) if tokens.present?
    end

    # Specific date parsing
    def self.extract_single_sortable_date(date_str)
      return unless date_str

      begin
        return Date.parse(date_str) # handles MON YYYY
      rescue Date::Error
        nil
      end

      return unless (years = date_str.scan(YEAR_REGEX).presence)

      max_year = years.map(&:to_i).max
      Date.parse("#{max_year}-01-01")
    end

    def self.max_multiple_dates(multiple_dates)
      multiple_dates.max
    end

    def self.extract_multiple_sortable_dates(date_str)
      # Break apart on spaces, after replacing commas with spaces
      ds = date_str.gsub(',', '')
      ds_array = ds.split(/\s+/)
      ds_tokens = []
      ds_array.each do |d|
        ds_tokens.push(d.split('/'))
      end

      # Generate date strings
      generated_dates = generate_dates(ds_tokens)
      generated_dates.map { |gd| extract_single_sortable_date(gd) }
    end

    # ds_tokens = [ [], [], []  ] - maybe even more
    def self.generate_dates(ds_tokens)
      generated_dates = []
      ds_tokens.each do |ds_token|
        if generated_dates.empty?
          # If we're adding the very first part of the string
          generated_dates.concat(ds_token)
        else
          ds_length = ds_token.length
          gd_length = generated_dates.length
          # If a string already exists, we're simply going to add to them
          if ds_length == 1
            # If only one string, add to each existing generated string
            generated_dates.map! { |gd| "#{gd} #{ds_token[0]}" }
          elsif ds_length == gd_length
            generated_dates = generated_dates.map.with_index { |v, i| "#{v} #{ds_token[i]}" }
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
