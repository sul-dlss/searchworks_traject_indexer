# frozen_string_literal: true

FactoryBot.define do
  factory :holding, class: 'SirsiHolding' do
    current_location { '' }
    home_location { '' }
    library { 'GREEN' }
    type { '' }
    barcode { 'barcode' }
    initialize_with { new(**attributes) }

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
      scheme { 'SUDOC' }
    end

    factory :alphanum_holding do
      call_number { 'ISHII SPRING 2009' }
      scheme { 'ALPHANUM' }
    end
  end
end
