# frozen_string_literal: true

module Folio
  # Folio::StatusCurrentLocation takes an item
  # and any requests associated with the item's instance record
  # and creates an equivalent Symphony current location
  class StatusCurrentLocation
    attr_reader :item

    def initialize(item)
      @item = item
    end

    def current_location
      case status
      when 'Checked out', 'Claimed returned', 'Aged to lost'
        'CHECKEDOUT'
      when 'Awaiting pickup'
        symphony_pickup_location_code
      when 'In process', 'In process (non-requestable)'
        'INPROCESS'
      when 'In transit', 'Awaiting delivery'
        'INTRANSIT'
      when 'Missing', 'Long missing'
        'MISSING'
      when 'On order'
        'ON-ORDER'
      end
    end

    private

    def status
      item['status']
    end

    # ARS-LOAN, RUM-LOAN, and SPE-LOAN each receives a
    # special label in SearchWorks. Other codes are generically
    # mapped to GRE-LOAN since they all receive the same label.
    def symphony_pickup_location_code
      case service_point_code
      when 'ARS'
        'ARS-LOAN'
      when 'RUMSEY-MAP'
        'RUM-LOAN'
      when 'SPEC'
        'SPE-LOAN'
      else
        'GRE-LOAN'
      end
    end

    def service_point_code
      item&.dig('request', 'pickupServicePoint', 'code')
    end
  end
end
