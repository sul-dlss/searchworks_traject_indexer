# frozen_string_literal: true

FactoryBot.define do
  factory :holding, class: 'FolioItem' do
    transient do
      scheme { '' }
      barcode { 'barcode' }
      notes { [] }
      sequence(:id) { |n| "hi_#{n}" }
      default_item_attributes { { 'id' => id, 'status' => 'Available', 'location' => { 'permanentLocation' => permanent_location } } }
      additional_item_attributes { {} }
      item do
        {
          'callNumberType' => { 'name' => scheme },
          'barcode' => barcode,
          'notes' => notes
        }.tap do |json|
          json['callNumber'] = { 'callNumber' => call_number } if call_number
          json.merge!('enumeration' => enumeration) if enumeration
        end
      end
      holding { {} }
      permanent_location_code { '' }
      permanent_location { { 'code' => permanent_location_code } }
      call_number { nil }
      enumeration { nil }
    end
    library { 'GREEN' }
    type { '' }
    bound_with { false }

    initialize_with { new(**attributes, holding:, item: default_item_attributes.merge(item).merge(additional_item_attributes.deep_stringify_keys)) }

    factory :caldoc_holding do
      call_number { 'CALIF C728 .F6 1973' }
      scheme { 'Shelving control number' }
    end

    factory :lc_holding do
      call_number { 'QE538.8 .N36 1975-1977' }
      scheme { 'LC' }
    end

    factory :dewey_holding do
      call_number { '159.32 .W211' }
      scheme { 'DEWEY' }
    end

    factory :sudoc_holding do
      call_number { 'I 19.76:98-600-B' }
      scheme { 'Superintendent of Documents classification' }
    end

    factory :undoc_holding do
      call_number { 'ECE/EAD/PAU/2003/1' }
      scheme { 'Shelving control number' }
    end

    factory :alphanum_holding do
      call_number { 'ISHII SPRING 2009' }
      scheme { 'Shelving control number' }
    end

    factory :other_holding do
      call_number { '71 15446' }
      scheme { 'OTHER' }
    end

    trait :bound_with do
      bound_with { true }
      additional_item_attributes do
        {
          'id' => 'f947bd93-a1eb-5613-8745-1063f948c461',
          'volume' => nil,
          'callNumber' => { 'callNumber' => '630.654 .I39M' },
          'chronology' => nil,
          'enumeration' => 'V.5:NO.1'
        }
      end
      holding do
        {
          'boundWith' => {
            'instance' => {
              'hrid' => 'a5488000',
              'title' => 'The gases of swamp rice soils ...'
            },
            'holding' => {},
            'item' => {
              'id' => 'some-boundwith-parent-item-id',
              'volume' => nil,
              'callNumber' => { 'callNumber' => '630.654 .I39M' },
              'chronology' => nil,
              'enumeration' => 'V.5:NO.1'
            }
          }
        }
      end
    end
  end
end
