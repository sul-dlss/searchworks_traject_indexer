# frozen_string_literal: true

# Map library codes to labels exported from Folio
class LibrariesMap
  # @param [String] symphony_library_code the Symphony library code
  # @return [String,NilClass] if the library exists in the cache of records from folio, return the name.
  #                           It's possible to have a situation where the record we're processing has a library
  #                           code that hasn't yet been added to the cache.
  def self.for(library_code)
    return if library_code == 'SUL' # do not index building_facet on electronic resources

    library = Folio::Types.libraries.values.find { |candidate| candidate.fetch('code') == library_code }

    folio_name = library&.fetch('name')

    # We strip 'Library' from the name because it appears in a facet called 'Library'.. except Hoover
    return folio_name if folio_name&.match?(/Hoover/)

    folio_name&.sub(' Library', '')
  end

  def self.translate_array(inputs)
    inputs.map { |input| self.for(input) }
  end
end
