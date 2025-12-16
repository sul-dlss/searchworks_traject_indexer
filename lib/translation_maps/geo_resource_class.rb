# frozen_string_literal: true

# Map values coming from cocina to OpenGeoMetadata "resource class" values
# See: https://opengeometadata.org/ogm-aardvark/#resource-class-values

require 'match_map'

MatchMap.new do |mm|
  mm[/map/i] = 'Maps'
  mm[/dataset/i] = 'Datasets'
end
