# frozen_string_literal: true

module Folio
  # Given an identifier string, return the appropriate MARC::DataField
  class MarcIdentifierMapper
    def self.for(id_value)
      case id_value
      # LCCN
      when /^([ a-z]{3}\d{8} |[ a-z]{2}\d{10})/
        build_data_field('010', id_value)
      # ISBN
      when /^\d{9}[\dX].*/, /^\d{12}[\dX].*/
        build_data_field('020', id_value)
      # ISSN
      when /^\d{4}-\d{3}[X\d]\D*$/
        build_data_field('022', id_value)
      # OCLC
      when /^\(OCoLC.*/
        build_data_field('035', id_value)
      end
    end

    def self.build_data_field(num, id_value)
      MARC::DataField.new(num, ' ', ' ', ['a', id_value])
    end
    private_class_method :build_data_field
  end
end
