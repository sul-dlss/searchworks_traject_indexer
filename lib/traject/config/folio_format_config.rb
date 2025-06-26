# frozen_string_literal: true

require_relative '../macros/folio_format'
require_relative '../macros/extras'

module FolioFormatConfig
  include Traject::Macros::FolioFormat
  include Traject::Macros::Extras

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def add_folio_format_fields
    to_field 'format_hsim',
             condition(
               leader?(byte: 6, values: %w[p t d f]),
               literal('Archive/Manuscript')
             )

    to_field 'format_hsim',
             all_conditions(
               leader?(byte: 6, values: %w[a]),
               leader?(byte: 7, values: %w[c]),
               literal('Archive/Manuscript')
             )

    to_field 'format_hsim',
             condition(
               marc_subfield?('245', subfield: 'h', values: [%r{manuscript|manuscript/digital}]),
               literal('Archive/Manuscript')
             )

    to_field 'format_hsim',
             all_conditions(
               leader?(byte: 6, values: %w[a t]),
               leader?(byte: 7, values: %w[a m]),
               literal('Book')
             )

    to_field 'format_hsim',
             all_conditions(
               leader?(byte: 7, values: %w[s]),
               control_field_byte?('008', byte: 21, values: ['m']),
               literal('Book')
             )

    to_field 'format_hsim',
             all_conditions(
               control_field_byte?('006', byte: 0, values: ['s']),
               control_field_byte?('006', byte: 4, values: ['m']),
               literal('Book')
             )

    to_field 'format_hsim',
             all_conditions(
               leader?(byte: 7, values: %w[s]),
               control_field_byte?('008', byte: 21, values: ['d']),
               literal('Database')
             )

    to_field 'format_hsim',
             all_conditions(
               control_field_byte?('006', byte: 0, values: ['s']),
               control_field_byte?('006', byte: 4, values: ['d']),
               literal('Database')
             )

    to_field 'format_hsim',
             all_conditions(
               leader?(byte: 6, values: %w[m]),
               control_field_byte?('008', byte: 26, values: ['j']),
               literal('Database')
             )

    to_field 'format_hsim',
             all_conditions(
               leader?(byte: 6, values: %w[m]),
               control_field_byte?('008', byte: 26, values: ['a']),
               literal('Dataset')
             )

    to_field 'format_hsim' do |record, acc, _ctx|
      acc << 'Equipment' if record.respond_to?(:holdings) && record.holdings.any? { |h| h.dig('holdingsType', 'name') == 'Equipment' }
    end

    to_field 'format_hsim',
             all_conditions(
               leader?(byte: 6, values: %w[k]),
               control_field_byte?('008', byte: 33, values: [/[aciklnopst 0-9|]/]),
               literal('Image')
             )

    to_field 'format_hsim',
             all_conditions(
               leader?(byte: 6, values: %w[g]),
               control_field_byte?('008', byte: 33, values: [/[ aciklnopst]/]),
               literal('Image')
             )

    image_terms = [
      'art original', 'digital graphic', 'slide', 'slides', 'chart', 'art reproduction', 'graphic', 'technical drawing', 'flash card', 'transparency', 'activity card', 'picture', 'graphic/digital graphic', 'diapositives'
    ]

    to_field 'format_hsim',
             condition(
               marc_subfield?('245', subfield: 'h', values: image_terms),
               literal('Image')
             )

    to_field 'format_hsim',
             all_conditions(
               control_field_byte?('007', byte: 0, values: %w[k r]),
               marc_subfield?('245', subfield: 'h', values: %w[kit]),
               literal('Image')
             )

    to_field 'format_hsim',
             all_conditions(
               control_field_byte?('007', byte: 0, values: %w[k]),
               control_field_byte?('007', byte: 1, values: %w[g h r v]),
               literal_multiple('Image', 'Image|Photo')
             )

    to_field 'format_hsim',
             all_conditions(
               control_field_byte?('007', byte: 0, values: %w[k]),
               control_field_byte?('007', byte: 1, values: %w[k]),
               literal_multiple('Image', 'Image|Poster')
             )

    to_field 'format_hsim',
             all_conditions(
               control_field_byte?('007', byte: 0, values: %w[g]),
               control_field_byte?('007', byte: 1, values: %w[s]),
               literal_multiple('Image', 'Image|Slide')
             )
  end
end
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/MethodLength
