# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EmbeddingInputBuilder do
  subject(:input) { described_class.new(max_input_chars:).build(document) }

  let(:max_input_chars) { described_class::DEFAULT_MAX_INPUT_CHARS }
  let(:document) do
    {
      'title_full_display' => ['A useful title'],
      'vern_title_full_display' => ["  役に立つ\nタイトル  "],
      'title_variant_search' => ['Another title', 'A useful title'],
      'author_1xx_search' => ['Example, Alice'],
      'subject_all_search' => ['Libraries'],
      'summary_search' => ["A summary with\nextra whitespace."],
      'pub_search' => ['Stanford University Press'],
      'pub_date' => ['2026'],
      'format_main_ssim' => ['Book'],
      'language' => ['English']
    }
  end

  it 'normalizes labeled input and removes duplicate values' do
    expect(input).to eq <<~TEXT.chomp
      title: A useful title | 役に立つ タイトル | text:
      alternate titles: Another title
      creators: Example, Alice
      subjects: Libraries
      summary: A summary with extra whitespace.
      publication: Stanford University Press | 2026
      format: Book | English
    TEXT
  end

  it 'truncates deterministically at the configured character limit' do
    expect(described_class.new(max_input_chars: 40).build(document)).to eq('title: A useful title | 役に立つ タイトル | tex…')
  end
end
