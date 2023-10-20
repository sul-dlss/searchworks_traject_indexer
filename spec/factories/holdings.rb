# frozen_string_literal: true

FactoryBot.define do
  factory :holding, class: 'FolioHolding' do
    transient do
      scheme { '' }
      barcode { 'barcode' }
      notes { [] }
    end
    current_location { '' }
    home_location { '' }
    library { 'GREEN' }
    type { '' }

    additional_item_attributes { {} }
    item do
      {
        'callNumberType' => { 'name' => scheme },
        'barcode' => barcode,
        'notes' => notes
      }
    end

    initialize_with { new(**attributes.except(:item, :additional_item_attributes), item: item.merge(additional_item_attributes)) }

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

    factory :alphanum_holding do
      call_number { 'ISHII SPRING 2009' }
      scheme { 'Shelving control number' }
    end

    factory :other_holding do
      call_number { '71 15446' }
      scheme { 'OTHER' }
    end

    trait :internet_holding do
      call_number { FolioHolding::ECALLNUM }
    end
  end
end
