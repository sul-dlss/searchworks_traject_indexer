# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/traject/macros/extras'

RSpec.describe Traject::Macros::Extras do
  include Traject::Macros::Extras

  let(:record) { instance_double(PurlRecord) }
  let(:accumulator) { [] }
  let(:output_hash) { {} }
  let(:context) { Traject::Indexer::Context.new(source_record: record, output_hash:) }

  before do
    macro.call(record, accumulator, context)
  end

  describe 'join' do
    let(:macro) { join(' ') }
    let(:accumulator) { [%w[one two], %w[three four]] }

    it 'joins the values in the accumulator' do
      expect(accumulator).to eq ['one two', 'three four']
    end
  end

  describe 'flatten' do
    let(:macro) { flatten }
    let(:accumulator) { [%w[one two], %w[three four]] }

    it 'flattens the nested arrays' do
      expect(accumulator).to eq %w[one two three four]
    end
  end

  describe 'sort' do
    let(:macro) { sort }
    let(:accumulator) { %w[3 1 2] }

    it 'sorts the accumulator' do
      expect(accumulator).to eq %w[1 2 3]
    end

    context 'with reverse' do
      let(:macro) { sort(reverse: true) }

      it 'sorts the accumulator in reverse' do
        expect(accumulator).to eq %w[3 2 1]
      end
    end
  end

  describe 'format_datetimes' do
    let(:macro) { format_datetimes }
    let(:accumulator) { [Time.parse('2021-01-01 12:00:00 UTC'), nil] }

    it 'formats the Time objects' do
      expect(accumulator).to eq ['2021-01-01T12:00:00Z']
    end
  end

  describe 'use_field' do
    let(:macro) { use_field('field') }
    let(:output_hash) { { 'field' => 'value' } }

    it 'adds the field value to the accumulator' do
      expect(accumulator).to eq ['value']
    end

    context 'with a missing field' do
      let(:output_hash) { {} }

      it 'does not add anything to the accumulator' do
        expect(accumulator).to eq []
      end
    end

    context 'with a multi-valued field' do
      let(:output_hash) { { 'field' => %w[value1 value2] } }

      it 'adds the field values to the accumulator' do
        expect(accumulator).to eq %w[value1 value2]
      end
    end
  end
end
