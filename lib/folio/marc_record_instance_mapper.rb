# frozen_string_literal: true

module Folio
  # Creates a Marc Record for an Folio instance
  class MarcRecordInstanceMapper
    # rubocop:disable Metrics/AbcSize
    def self.build(instance, holdings)
      MARC::Record.new.tap do |marc|
        marc.append(MARC::ControlField.new('001', instance['hrid']))
        # mode of issuance
        # identifiers
        instance['identifiers'].each do |identifier|
          field = MarcIdentifierMapper.for(identifier['value'])
          marc.append(field) if field
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
          marc.append(MARC::DataField.new('490', '0', '', ['a', series]))
        end
        instance['subjects'].each do |subject|
          marc.append(MARC::DataField.new('653', '', '', ['a', subject]))
        end

        # 856 stuff
        instance['electronicAccess']&.each do |eresource|
          marc.append(MarcElectronicAccess.build(eresource))
        end

        holdings.flat_map { |h| h['electronicAccess'] }.each do |eresource|
          marc.append(MarcElectronicAccess.build(eresource))
        end

        # nature of content
        marc.append(MARC::DataField.new('999', '', '', ['i', instance['id']]))
        # date creaetd
        # date updated
      end.to_hash
    end
    # rubocop:enable Metrics/AbcSize
  end
end
