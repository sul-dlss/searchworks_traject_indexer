# frozen_string_literal: true

FactoryBot.define do
  factory :holding, class: 'FolioHolding' do
    current_location { '' }
    home_location { '' }
    library { 'GREEN' }
    type { '' }
    barcode { 'barcode' }
    initialize_with { new(**attributes) }

    factory :lc_holding do
      call_number { 'QE538.8 .N36 1975-1977' }
      item { { 'callNumberType' => { 'name' => 'LC' } } }
    end

    factory :dewey_holding do
      call_number { '159.32 .W211' }
      item { { 'callNumberType' => { 'name' => 'DEWEY' } } }
    end

    factory :sudoc_holding do
      call_number { 'I 19.76:98-600-B' }
      item { { 'callNumberType' => { 'name' => 'Superintendent of Documents classification' } } }
    end

    factory :alphanum_holding do
      call_number { 'ISHII SPRING 2009' }
      item { { 'callNumberType' => { 'name' => 'Shelving control number' } } }
    end

    factory :other_holding do
      call_number { '71 15446' }
      item { { 'callNumberType' => { 'name' => 'OTHER' } } }
    end

    trait :internet_holding do
      call_number { FolioHolding::ECALLNUM }
    end
  end
end
