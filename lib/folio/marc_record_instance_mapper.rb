# frozen_string_literal: true

module Folio
  # Creates a Marc Record for an Folio instance
  class MarcRecordInstanceMapper
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/BlockLength
    def self.build(folio_record)
      MARC::Record.new.tap do |marc|
        marc.append(MARC::ControlField.new('001', folio_record.hrid))

        instance = folio_record.instance
        # mode of issuance
        # identifiers
        instance['identifiers'].each do |identifier|
          value = identifier.fetch('value')
          case value
          # LCCN
          when /^([ a-z]{3}\d{8} |[ a-z]{2}\d{10})/
            marc.append(MARC::DataField.new('010', ' ', ' ', ['a', value]))
          # ISBN
          when /^\d{9}[\dX].*/, /^\d{12}[\dX].*/
            marc.append(MARC::DataField.new('020', ' ', ' ', ['a', value]))
          # ISSN
          when /^\d{4}-\d{3}[X\d]\D*$/
            marc.append(MARC::DataField.new('022', ' ', ' ', ['a', value]))
          # OCLC
          when /^\(OCoLC.*/
            marc.append(MARC::DataField.new('035', ' ', ' ', ['a', value]))
          end
        end

        instance['languages'].each do |l|
          marc.append(MARC::DataField.new('041', ' ', ' ', ['a', l]))
        end

        instance['contributors'].each do |contrib|
          # personal name: 100/700
          field = MARC::DataField.new(contrib['primary'] ? '100' : '700', '1', '')
          # corp. name: 110/710, ind1: 2
          # meeting name: 111/711, ind1: 2
          field.append(MARC::Subfield.new('a', contrib['name']))

          marc.append(field)
        end

        marc.append(MARC::DataField.new('245', '0', '0', ['a', instance['title']]))

        # alt titles
        instance['editions'].each do |edition|
          marc.append(MARC::DataField.new('250', '0', '', ['a', edition]))
        end
        # instanceTypeId
        instance['publication'].each do |pub|
          field = MARC::DataField.new('264', '0', '0')
          field.append(MARC::Subfield.new('a', pub['place'])) if pub['place']
          field.append(MARC::Subfield.new('b', pub['publisher'])) if pub['publisher']
          field.append(MARC::Subfield.new('c', pub['dateOfPublication'])) if pub['dateOfPublication']
          marc.append(field)
        end
        instance['physicalDescriptions'].each do |desc|
          marc.append(MARC::DataField.new('300', '0', '0', ['a', desc]))
        end
        instance['publicationFrequency'].each do |freq|
          marc.append(MARC::DataField.new('310', '0', '0', ['a', freq]))
        end
        instance['publicationRange'].each do |range|
          marc.append(MARC::DataField.new('362', '0', '', ['a', range]))
        end
        instance['notes'].each do |note|
          marc.append(MARC::DataField.new('500', '0', '', ['a', note['note']]))
        end
        instance['series'].each do |series|
          marc.append(MARC::DataField.new('490', '0', '', ['a', folio_value(series)]))
        end
        instance['subjects'].each do |subject|
          marc.append(MARC::DataField.new('653', '', '', ['a', folio_value(subject)]))
        end

        # 856 stuff
        instance['electronicAccess']&.each do |eresource|
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

          marc.append(MARC::DataField.new('856', '4', ind2, *subfields.to_a))
        end

        folio_record.holdings.flat_map { |h| h['electronicAccess'] }.each do |eresource|
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

          marc.append(MARC::DataField.new('856', '4', ind2, *subfields.to_a))
        end

        # nature of content
        marc.append(MARC::DataField.new('999', '', '', ['i', folio_record.instance_id]))
        # date creaetd
        # date updated
      end.to_hash
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/BlockLength

    # The FOLIO data can either be a plain string (pre-Poppy) or a hash (post-Poppy)
    def self.folio_value(folio_data)
      return folio_data['value'] if folio_data.is_a?(Hash)

      folio_data
    end
  end
end
