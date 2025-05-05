# frozen_string_literal: true

module Folio
  class MarcRecordMapper
    def self.build(stripped_marc_json, folio_record)
      record = MARC::Record.new_from_hash(stripped_marc_json || Folio::MarcRecordInstanceMapper.build(folio_record))

      remove_private_fields!(record)
      remove_private_subfields!(record)
      copy_electronic_access!(record, folio_record)
      copy_bound_with_holdings!(record, folio_record)

      record
    end

    # Suppress private notes
    def self.remove_private_fields!(record)
      record.fields.delete_if do |field|
        (field.tag.in?(%w[243 361 541 542 561 583]) && field.indicator1 == '0') ||
          (field.tag.in?(%w[760 761 762 763 764 765 766 777 778 779 780 781 782 783 784 785 786 787]) && field.indicator1 == '1')
      end
    end

    def self.remove_private_subfields!(record)
      record.fields.each do |field|
        next unless field.respond_to? :subfields

        field.subfields.delete_if { |subfield| subfield.code == '0' && subfield.value.start_with?('(SIRSI)') }

        # Scrub any "NoExport" subfields; currently only used by Lane?
        # See: https://searchworks.stanford.edu/view/L81154
        field.subfields.delete_if { |subfield| subfield.value == 'NoExport' }
      end
    end

    # Copy FOLIO Holdings electronic access data to an 856 (used by Lane)
    # overwriting any existing 856 fields (to avoid having to reconcile/merge data)
    def self.copy_electronic_access!(record, folio_record)
      eholdings = folio_record.holdings.flat_map { |h| h['electronicAccess'] }.compact

      return unless eholdings.any?

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
    def self.copy_bound_with_holdings!(record, folio_record)
      return if record.fields('590').any? { |f| f['a'] && f['c'] }

      # if 590 or one of its Bound-with related subfields is missing, and FOLIO says this record is Bound-with, append the relevant data from FOLIO
      folio_record.bound_with_holdings.each do |item|
        field590 = MARC::DataField.new('590', ' ', ' ')
        field590.subfields << MARC::Subfield.new('a', "#{item.holding['callNumber']} bound with #{item.holding.dig('boundWith', 'instance', 'title')}")
        field590.subfields << MARC::Subfield.new('c', "#{item.holding.dig('boundWith', 'instance', 'hrid')} (parent record)")
        record.append(field590)
      end
    end
  end
end
