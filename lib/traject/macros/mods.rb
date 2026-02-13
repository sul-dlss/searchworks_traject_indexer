# frozen_string_literal: true

module Traject
  module Macros
    # MODSXML-related macros
    module Mods
      def stanford_mods(method, *args, default: nil)
        lambda do |resource, accumulator, _context|
          data = Array(resource.stanford_mods.public_send(method, *args))

          data.each do |v|
            accumulator << v
          end

          accumulator << default if data.empty?
        end
      end

      def mods_xpath(xpath)
        lambda do |resource, accumulator, _context|
          # Convert the xpath result (a Nokogiri nodeset) to a plain array.
          # This allows traject methods like first_only to work properly.
          accumulator.concat(resource.mods.xpath(xpath, mods: 'http://www.loc.gov/mods/v3'))
        end
      end

      def mods_display(method, *args, default: nil)
        lambda do |resource, accumulator, _context|
          data = Array(resource.mods_display.public_send(method, *args))

          data.each do |v|
            v.each_value do |v2|
              accumulator << v2.to_s
            end
          end

          accumulator << default if data.empty?
        end
      end
    end
  end
end
