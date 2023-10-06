# frozen_string_literal: true

# Map library codes to labels exported from Folio
class LibrariesMap
  # @param [String] symphony_library_code the Symphony library code
  # @return [String,NilClass] if the library exists in the cache of records from folio, return the name.
  #                           It's possible to have a situation where the record we're processing has a library
  #                           code that hasn't yet been added to the cache.
  def self.for(symphony_library_code)
    return if symphony_library_code == 'SUL' # do not index building_facet on electronic resources

    # If symphony codes are passed as input, we need to update to the folio code
    key = folio_code_for(symphony_library_code)

    library = Folio::Types.libraries.values.find { |candidate| candidate.fetch('code') == key }

    folio_name = library&.fetch('name')

    # We strip 'Library' from the name because it appears in a facet called 'Library'.. except Hoover
    return folio_name if folio_name&.match?(/Hoover/)

    folio_name&.sub(' Library', '')
  end

  def self.folio_code_for(symphony_library_code)
    case symphony_library_code
    when 'LANE-MED'
      'LANE'
    when 'HOOVER'
      'HILA'
    when 'HOPKINS'
      'MARINE-BIO'
    when 'MEDIA-MTXT'
      'MEDIA-CENTER'
    when 'RUMSEYMAP'
      'RUMSEY-MAP'
    else
      symphony_library_code
    end
  end

  def self.symphony_code_for(folio_library_code)
    case folio_library_code
    when 'LANE'
      'LANE-MED'
    when 'HILA'
      'HOOVER'
    when 'MARINE-BIO'
      'HOPKINS'
    when 'MEDIA-CENTER'
      'MEDIA-MTXT'
    when 'RUMSEY-MAP'
      'RUMSEYMAP'
    else
      folio_library_code
    end
  end

  def self.translate_array(inputs)
    inputs.map { |input| self.for(input) }
  end
end
