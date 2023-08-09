# frozen_string_literal: true

module Folio
  class MarcElectronicAccess
    def self.build(eresource)
      ind2 = case eresource['name']
             when 'Resource'
               '0'
             when 'Version of resource'
               '1'
             when 'Related resource'
               '2'
             when 'No display constant generated'
               '8'
             else
               ''
             end

      MARC::DataField.new('856', '4', ind2, ['u', eresource['uri']], ['y', eresource['linkText']], ['z', eresource['publicNote']])
    end
  end
end
