# frozen_string_literal: true

require 'holding_call_number'

###################################
# ItemDisplay takes a Record, a SirsiHolding object, and Traject context,
# and adds behavior needed to produce call number and shelfkey values for
# use in SearchWorks.
###################################
class ItemDisplay
  include HoldingCallNumber

  LOCATION_MAP = Traject::TranslationMap.new('location_map')

  def initialize(record = nil, holding = nil, context = nil)
    @record = record
    @holding = holding
    @context = context
  end

  def call_number
    return if (@holding.ignored_call_number? && !@holding.shelved_by_location?) &&
              (!@holding.e_call_number? || call_number_with_enumeration.to_s == SirsiHolding::ECALLNUM ||
              call_number_object.call_number)

    call_number_with_enumeration
  end

  def lopped_call_number
    return if @holding.ignored_call_number? && !@holding.shelved_by_location?
    return 'Shelved by Series title' if shelved_by_series_title?
    return 'Shelved by title' if shelved_by_location?
    return call_number_object.call_number if single_item_in_location?
    return add_ellipses(call_number_object.lopped) if multiple_items_in_location?

    holding.call_number.to_s
  end

  def shelfkey
    return if @holding.lost_or_missing?
    return lopped_call_number.downcase if shelved_by_location?
    return call_number_object.to_shelfkey if single_item_in_location?

    add_ellipses(call_number_object.to_lopped_shelfkey) if multiple_items_in_location?
  end

  # NOTE: reverse shelfkey implemention moved here from CallNumber::ShelfkeyBase
  #       to eliminate multiple implementations.
  def reverse_shelfkey
    return if @holding.lost_or_missing?

    CallNumbers::ShelfkeyBase.reverse(shelfkey)&.ljust(50, '~') if shelfkey && !shelfkey.empty?
  end

  def volume_sort
    return if @holding.ignored_call_number? && !@holding.shelved_by_location?
    return volume_sort_for_shelved_by_location if shelved_by_location?

    call_number_object.to_volume_sort if single_item_in_location? || multiple_items_in_location?
  end

  def scheme
    call_number_object&.scheme&.upcase
  end

  private

  def non_skipped_or_ignored_holdings
    @non_skipped_or_ignored_holdings ||=
      @context.clipboard[:non_skipped_or_ignored_holdings_by_library_location_call_number_type]
  end

  def stuff_in_the_same_library
    @stuff_in_the_same_library ||= Array(non_skipped_or_ignored_holdings[[@holding.library,
                                                                          LOCATION_MAP[@holding.home_location],
                                                                          @holding.call_number_type]])
  end

  def call_number_object
    @call_number_object ||= call_number_for_holding(@record, @holding, @context)
  end

  def enumeration
    return if @holding.ignored_call_number?

    @holding.call_number.to_s[call_number_object.lopped.length..].strip
  end

  def call_number_with_enumeration
    return [lopped_call_number, enumeration].compact.join(' ') if shelved_by_location? && !@holding.e_call_number?

    @holding.call_number
  end

  def shelved_by_location?
    call_number_object &&
      @holding.shelved_by_location?
  end

  def shelved_by_series_title?
    call_number_object &&
      @holding.shelved_by_location? &&
      [@holding.home_location, @holding.current_location].include?('SHELBYSER')
  end

  def single_item_in_location?
    call_number_object &&
      stuff_in_the_same_library.length <= 1
  end

  def multiple_items_in_location?
    call_number_object &&
      stuff_in_the_same_library.length > 1
  end

  def add_ellipses(call_number)
    return "#{call_number} ..." if call_number_is_lopped? || stuff_in_same_library_has_matching_lopped_call_number?

    call_number
  end

  def call_number_is_lopped?
    call_number_object.lopped != @holding.call_number.to_s
  end

  def stuff_in_same_library_has_matching_lopped_call_number?
    stuff_in_the_same_library.reject { |x| x.call_number.to_s == @holding.call_number.to_s }
                             .select { |x| call_number_for_holding(@record, x, @context).lopped == call_number_object.lopped }.any?
  end

  def volume_sort_for_shelved_by_location
    [
      lopped_call_number,
      (CallNumbers::ShelfkeyBase.reverse(CallNumbers::ShelfkeyBase.pad_all_digits(enumeration)).ljust(50, '~') if enumeration)
    ].compact.join(' ').downcase
  end
end
