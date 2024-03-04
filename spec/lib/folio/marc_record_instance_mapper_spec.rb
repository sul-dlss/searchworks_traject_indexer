# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Folio::MarcRecordInstanceMapper do
  describe '.build' do
    let(:instance) do
      {
        'id' => '8d3623d4-60ab-4aa6-8637-1c0bf6cfb297',
        'hrid' => 'in00000003052',
        'notes' => [],
        'title' => "Akira Kurosawa's dreams",
        'series' => [],
        'source' => 'FOLIO',
        'editions' => [],
        'subjects' => [],
        'languages' => [],
        'identifiers' => [],
        'publication' => [],
        'contributors' => [],
        'electronicAccess' => [],
        'publicationRange' => [],
        'physicalDescriptions' => [],
        'publicationFrequency' => []
      }
    end

    let(:holdings) { [{ 'electronicAccess' => [] }] }

    context 'when instance type is not available' do
      it 'leaves leader byte 6 unset' do
        marc = described_class.build(instance, holdings)
        expect(marc['leader'][6]).to eq(' ')
      end
    end

    context 'when instance type is available' do
      let(:instance_with_instance_type) do
        instance.merge(
          'instanceType' => {
            'name' => 'two-dimensional moving image'
          }
        )
      end
      it 'sets leader byte 6' do
        marc = described_class.build(instance_with_instance_type, holdings)
        expect(marc['leader'][6]).to eq('g')
      end
    end

    context 'when mode of issuance is not available' do
      it 'leaves leader byte 7 unset' do
        marc = described_class.build(instance, holdings)
        expect(marc['leader'][7]).to eq(' ')
      end
    end

    context 'when mode of issuance is available' do
      let(:instance_with_mode_of_issuance) do
        instance.merge(
          'modeOfIssuance' => {
            'name' => 'single unit'
          }
        )
      end
      it 'sets leader byte 7' do
        marc = described_class.build(instance_with_mode_of_issuance, holdings)
        expect(marc['leader'][7]).to eq('m')
      end
    end
  end
end
