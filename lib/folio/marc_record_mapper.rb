# frozen_string_literal: true

module Folio
  class MarcRecordMapper
    def self.build(stripped_marc_json, folio_record)
      record = MARC::Record.new_from_hash(stripped_marc_json || Folio::MarcRecordInstanceMapper.build(folio_record))

      record.fields.each do |field|
        next unless field.respond_to? :subfields

        field.subfields.delete_if { |subfield| subfield.code == '0' && subfield.value.start_with?('(SIRSI)') }

        # Scrub any "NoExport" subfields; currently only used by Lane?
        # See: https://searchworks.stanford.edu/view/L81154
        field.subfields.delete_if { |subfield| subfield.value == 'NoExport' }
      end

      # Copy FOLIO Holdings electronic access data to an 856 (used by Lane)
      # overwriting any existing 856 fields (to avoid having to reconcile/merge data)
      eholdings = folio_record.holdings.flat_map { |h| h['electronicAccess'] }.compact

      if eholdings.any?
        record.fields.delete_if { |field| field.tag == '856' }

        eholdings.each do |eresource|
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

          subfields = {
            '3' => eresource['materialsSpecification'],
            'u' => eresource['uri'],
            'y' => eresource['linkText'],
            'z' => eresource['publicNote']
          }.reject { |_k, v| v.blank? }

          record.append(MARC::DataField.new('856', '4', ind2, *subfields.to_a))
        end
      end

      # Copy bound-with holdings to the 590 field, if one isn't already present:
      # if 590 with Bound-with related subfields are present, return the record as is
      unless record.fields('590').any? { |f| f['a'] && f['c'] }
        # if 590 or one of its Bound-with related subfields is missing, and FOLIO says this record is Bound-with, append the relevant data from FOLIO
        holdings.select { |holding| holding['boundWith'].present? }.each do |holding|
          field590 = MARC::DataField.new('590', ' ', ' ')
          field590.subfields << MARC::Subfield.new('a', "#{holding['callNumber']} bound with #{holding.dig('boundWith', 'instance', 'title')}")
          field590.subfields << MARC::Subfield.new('c', "#{holding.dig('boundWith', 'instance', 'hrid')} (parent record)")
          record.append(field590)
        end
      end
      record
    end
  end
end
