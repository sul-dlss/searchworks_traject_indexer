# frozen_string_literal: true

module Traject
  module Macros
    # Traject macros for working with geospatial data
    module MetaJson
      def searchworks_url
        lambda do |record, accumulator, _context|
          accumulator << "#{settings['searchworks.url']}/view/#{record.druid}" if record.public_meta_json? && record.released_to_searchworks?
        end
      end
    end
  end
end
