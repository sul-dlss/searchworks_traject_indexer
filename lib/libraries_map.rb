# frozen_string_literal: true

# Map library codes to labels exported from Folio
class LibrariesMap
  # @param [String] key the Symphony library code
  # @return [String,NilClass] if the library exists in the cache of records from folio, return the name.
  #                           It's possible to have a situation where the record we're processing has a library
  #                           code that hasn't yet been added to the cache.
  def self.for(key)
    return if key == 'SUL' # do not index building_facet on electronic resources

    key = 'LANE' if key == 'LANE-MED' # If symphony codes are passed as input, we need to update to the folio code

    library = Folio::Types.libraries.values.find { |candidate| candidate.fetch('code') == key }
    library&.fetch('name')
  end

  def self.translate_array(inputs)
    inputs.map { |input| self.for(input) }
  end
end
