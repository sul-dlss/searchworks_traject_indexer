# frozen_string_literal: true

require 'folio_holding'

RSpec.describe FolioHolding do
  describe '#display_location' do
    context 'with an item' do
      subject(:display_location) { described_class.new(item:, holding:).display_location }
      let(:item) do
        {
          location: {
            temporaryLocation: { code: 'GRE-STACKS' }
          }
        }.with_indifferent_access
      end
      let(:holding) do
        {
          location: {
            effectiveLocation: { code: 'SAL3-STACKS' }
          }
        }.with_indifferent_access
      end

      it 'is the holdings effective location' do
        expect(display_location['code']).to eq 'SAL3-STACKS'
      end
    end

    context 'with an item in a location that we treat as the permanent location for display purposes' do
      subject(:display_location) { described_class.new(item:, holding:).display_location }
      let(:item) do
        {
          location: {
            temporaryLocation: { code: 'GRE-CRES', details: { searchworksTreatTemporaryLocationAsPermanentLocation: 'true' } }
          }
        }.with_indifferent_access
      end
      let(:holding) do
        {
          location: {
            effectiveLocation: { code: 'SAL3-STACKS' }
          }
        }.with_indifferent_access
      end

      it 'is the holdings effective location' do
        expect(display_location['code']).to eq 'GRE-CRES'
      end
    end
  end

  describe '#library' do
    subject(:library) { described_class.new(item:, holding:).library }

    context 'with a location without a symphony equivalent' do
      let(:item) do
        {
          location: {}
        }.with_indifferent_access
      end

      let(:holding) do
        {
          location: {
            effectiveLocation: { code: 'SPEC-SAL-TAUBE', library: { code: 'SPEC-COLL' } }
          }
        }.with_indifferent_access
      end

      it 'is the Symphony code' do
        expect(library).to eq 'SPEC-COLL'
      end
    end

    context 'with a location that maps to a Symphony location' do
      let(:item) do
        {
          location: {}
        }.with_indifferent_access
      end

      let(:holding) do
        {
          location: {
            effectiveLocation: { code: 'ART-LOCKED-OVERSIZE' }
          }
        }.with_indifferent_access
      end

      it 'is the Symphony code' do
        expect(library).to eq 'ART'
      end
    end
  end

  describe '#home_location' do
    subject(:home_location) { described_class.new(item:, holding:).home_location }

    context 'with a location without a symphony equivalent' do
      let(:item) do
        {
          location: {}
        }.with_indifferent_access
      end

      let(:holding) do
        {
          location: {
            effectiveLocation: { code: 'SPEC-SAL-TAUBE' }
          }
        }.with_indifferent_access
      end

      it 'is the FOLIO code' do
        expect(home_location).to eq 'SPEC-SAL-TAUBE'
      end
    end

    context 'with a location that maps to a Symphony location' do
      let(:item) do
        {
          location: {}
        }.with_indifferent_access
      end

      let(:holding) do
        {
          location: {
            effectiveLocation: { code: 'ART-LOCKED-OVERSIZE' }
          }
        }.with_indifferent_access
      end

      it 'is the Symphony code' do
        expect(home_location).to eq 'ARTLCKO'
      end
    end
  end

  describe '#to_item_display_hash' do
    context 'with an item' do
      subject(:hash) { described_class.new(item:, holding:).to_item_display_hash }
      let(:item) do
        {
          id: 'uuid',
          barcode: '36105000',
          status: 'Available',
          materialTypeId: 'mt-uuid',
          temporaryLoanTypeId: 'tlt-uuid',
          permanentLoanTypeId: 'plt-uuid',
          location: {
            temporaryLocation: { code: 'GRE-STACKS' }
          }
        }.with_indifferent_access
      end
      let(:holding) do
        {
          location: {
            effectiveLocation: { code: 'SAL3-STACKS' }
          }
        }.with_indifferent_access
      end

      it 'maps the item-level data' do
        expect(hash).to include(
          id: 'uuid',
          barcode: '36105000',
          status: 'Available',
          temporary_location_code: 'GRE-STACKS',
          permanent_location_code: 'SAL3-STACKS',
          material_type_id: 'mt-uuid',
          loan_type_id: 'tlt-uuid'
        )
      end
    end

    context 'with only a holdings record' do
      subject(:hash) { described_class.new(holding:).to_item_display_hash }

      let(:holding) do
        {
          location: {
            effectiveLocation: { code: 'GRE-STACKS' }
          }
        }.with_indifferent_access
      end

      it 'maps the available holdings data' do
        expect(hash).to include(
          temporary_location_code: nil,
          permanent_location_code: 'GRE-STACKS'
        )
      end
    end

    context 'with a bound-with holding' do
      subject(:hash) { described_class.new(item:, holding:, instance:, bound_with_holding:).to_item_display_hash }
      let(:item) do
        {
          id: 'uuid',
          barcode: '36105000',
          status: 'Available',
          materialTypeId: 'mt-uuid',
          temporaryLoanTypeId: 'tlt-uuid',
          permanentLoanTypeId: 'plt-uuid',
          location: {
            temporaryLocation: { code: 'GRE-STACKS' }
          }
        }.with_indifferent_access
      end
      let(:holding) do
        {
          location: {
            effectiveLocation: { code: 'SAL3-STACKS' }
          }
        }.with_indifferent_access
      end
      let(:instance) do
        {
          id: 'instance-uuid',
          hrid: 'instance-hrid'
        }.with_indifferent_access
      end
      let(:bound_with_holding) do
        {
          callNumber: 'bound-with-callnumber'
        }.with_indifferent_access
      end

      it 'maps the available holdings data' do
        expect(hash).to include(
          barcode: '36105000',
          permanent_location_code: 'SAL3-STACKS',
          temporary_location_code: 'GRE-STACKS',
          instance_id: 'instance-uuid',
          instance_hrid: 'instance-hrid'
        )
      end
    end
  end
end
