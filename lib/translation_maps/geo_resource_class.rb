# frozen_string_literal: true

# Map values coming from cocina to OpenGeoMetadata "resource type" values
# See: https://opengeometadata.org/ogm-aardvark/#resource-type-values-ogm

# LOC Cartographic Genres are also valid
# See: https://opengeometadata.org/ogm-aardvark/#resource-type-values-loc

require 'match_map'

MatchMap.new do |mm|
  mm[/map/i] = 'Maps'
  mm[/dataset/i] = 'Datasets'
end
