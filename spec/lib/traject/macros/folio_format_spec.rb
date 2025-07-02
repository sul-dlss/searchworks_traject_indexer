# frozen_string_literal: true

require 'spec_helper'
require 'marc'
require_relative '../../../../lib/traject/macros/folio_format'

RSpec.describe Traject::Macros::FolioFormat do
  include described_class

  let(:record) { MARC::Record.new }
  let(:context) { Traject::Indexer::Context.new }
  let(:accumulator) { [] }

  describe '#all_conditions' do
    let(:action) { ->(_record, accumulator, _context) { accumulator << 'Image' } }

    it 'calls the action if all conditions pass' do
      # Check 2 conditions
      macro = all_conditions(->(_record, _context) { true }, ->(_record, _context) { true }, action)
      macro.call(record, accumulator, context)
      expect(accumulator).to include('Image')
    end

    it 'does not call the action if any condition fails' do
      # Check 2 conditions, one fails
      macro = all_conditions(->(_record, _context) { true }, ->(_record, _context) { false }, action)
      macro.call(record, accumulator, context)
      expect(accumulator).to be_empty
    end
  end

  describe '#condition' do
    let(:action) { ->(_record, accumulator, _context) { accumulator << 'Image' } }

    it 'calls action when single condition is true' do
      macro = condition(->(_record, _context) { true }, action)
      macro.call(record, accumulator, context)
      expect(accumulator).to include('Image')
    end

    it 'does not call action when single condition is false' do
      macro = condition(->(_record, _context) { false }, action)
      macro.call(record, accumulator, context)
      expect(accumulator).to be_empty
    end
  end

  describe '#leader?' do
    before { record.leader = '00000cam a2200000 i 4500' }

    it 'returns true when byte matches one of the values' do
      expect(leader?(byte: 6, values: %w[a b c]).call(record, context)).to be true
    end

    it 'returns true when byte matches a single value' do
      expect(leader?(byte: 6, value: 'a').call(record, context)).to be true
    end

    it 'returns false when byte does not match' do
      expect(leader?(byte: 6, values: %w[x y z]).call(record, context)).to be false
    end

    it 'returns false when leader is nil' do
      allow(record).to receive(:leader).and_return(nil)
      expect(leader?(byte: 6, values: %w[a b c]).call(record, context)).to be false
    end
  end

  describe '#marc_subfield_contains?' do
    before do
      record.append(
        MARC::DataField.new('245', '1', '0',
                            MARC::Subfield.new('h', 'A set of video recordings'))
      )
    end

    it 'matches phrase' do
      condition = marc_subfield_contains?('245', subfield: 'h', values: [
                                            'video recordings', 'audio recordings'
                                          ])
      expect(condition.call(record, context)).to be true
    end

    it 'matches using regex' do
      condition = marc_subfield_contains?('245', subfield: 'h', value: /video/i)
      expect(condition.call(record, context)).to be true
    end

    it 'returns false if no matching subfield' do
      condition = marc_subfield_contains?('245', subfield: 'z', value: /video/i)
      expect(condition.call(record, context)).to be false
    end

    it 'returns false if no matching string' do
      condition = marc_subfield_contains?('245', subfield: 'h', values: ['vdeo recordings', 'film recordings'])
      expect(condition.call(record, context)).to be false
    end
  end

  describe '#control_field_byte?' do
    before do
      record.append(
        MARC::ControlField.new('008', '0a000000000000000000000000000000000000')
      )
    end

    it 'returns true with a match' do
      condition = control_field_byte?('008', byte: 1, values: %w[a b c])
      expect(condition.call(record, context)).to be true
    end

    it 'returns false when no match' do
      condition = control_field_byte?('008', byte: 32, value: 'x')
      expect(condition.call(record, context)).to be false
    end

    it 'handles regex matching' do
      condition = control_field_byte?('008', byte: 31, values: [/0/])
      expect(condition.call(record, context)).to be true
    end

    it 'returns false if field is too short' do
      short_field = MARC::ControlField.new('006', '000')
      record.append(short_field)

      condition = control_field_byte?('006', byte: 10, value: 'x')
      expect(condition.call(record, context)).to be false
    end
  end
end
