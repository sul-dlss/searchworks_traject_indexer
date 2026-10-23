# frozen_string_literal: true

# Builds the stable, bounded text sent to the embedding model from a mapped
# SearchWorks document. Field ordering and labels are part of the input schema;
# changing them should be accompanied by an embedding schema version bump.
class EmbeddingInputBuilder
  DEFAULT_MAX_INPUT_CHARS = 24_000

  TITLE_FIELDS = %w[
    title_full_display
    vern_title_full_display
  ].freeze

  SECTION_FIELDS = {
    'alternate titles' => %w[
      title_variant_search
      vern_title_variant_search
      title_uniform_search
      vern_title_uniform_search
    ],
    'creators' => %w[
      author_1xx_search
      author_7xx_search
      author_8xx_search
      vern_author_1xx_search
      vern_author_7xx_search
      vern_author_8xx_search
    ],
    'subjects' => %w[
      subject_all_search
      vern_subject_all_search
    ],
    'summary' => %w[
      summary_search
      vern_summary_search
    ],
    'contents' => %w[
      toc_search
      vern_toc_search
    ],
    'series' => %w[
      series_search
      vern_series_search
    ],
    'publication' => %w[
      pub_search
      vern_pub_search
      pub_date
    ],
    'format' => %w[
      format_hsim
      format_main_ssim
      genre_ssim
      language
      physical
      vern_physical
    ]
  }.freeze

  def initialize(max_input_chars: DEFAULT_MAX_INPUT_CHARS)
    @max_input_chars = Integer(max_input_chars)
    raise ArgumentError, 'max_input_chars must be positive' unless @max_input_chars.positive?
  end

  def build(document)
    seen = {}
    titles = values(document, TITLE_FIELDS, seen:)
    lines = SECTION_FIELDS.filter_map do |label, fields|
      section_values = values(document, fields, seen:)
      "#{label}: #{section_values.join(' | ')}" if section_values.any?
    end

    truncate(["title: #{titles.any? ? titles.join(' | ') : 'none'} | text:", *lines].join("\n"))
  end

  private

  def values(document, fields, seen:)
    fields.flat_map { |field| Array(document[field]) }
          .filter_map { |value| normalize(value) }
          .reject { |value| duplicate?(value, seen) }
  end

  def duplicate?(value, seen)
    return true if seen.key?(value)

    seen[value] = true
    false
  end

  def normalize(value)
    normalized = value.to_s.gsub(/\s+/, ' ').strip
    normalized unless normalized.empty?
  end

  def truncate(input)
    return input if input.length <= @max_input_chars

    "#{input[0, @max_input_chars - 1]}…"
  end
end
