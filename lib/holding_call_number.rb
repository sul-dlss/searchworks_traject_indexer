# frozen_string_literal: true

module HoldingCallNumber
  LOCATION_MAP = Traject::TranslationMap.new('location_map')

  def call_number_for_holding(record, holding, context)
    context.clipboard[:call_number_for_holding] ||= {}
    context.clipboard[:call_number_for_holding][holding] ||= calculate_call_number_for_holding(record, holding, context)
  end

  private

  def calculate_call_number_for_holding(record, holding, context)
    return OpenStruct.new(scheme: holding.call_number_type) if holding.on_order? || holding.in_process?

    serial = (context.output_hash['format_main_ssim'] || []).include?('Journal/Periodical')

    separate_browse_call_num = []
    if holding.call_number.to_s.empty? || holding.ignored_call_number?
      if record['086']
        last086 = record.find_all { |f| f.tag == '086' }.last
        separate_browse_call_num << CallNumbers::Other.new(last086['a'], scheme: last086.indicator1 == '0' ? 'SUDOC' : 'OTHER')
      end

      Traject::MarcExtractor.cached('050ab:090ab', alternate_script: false).extract(record).each do |item050|
        separate_browse_call_num << CallNumbers::LC.new(item050, serial:) if SirsiHolding::CallNumber.new(item050).valid_lc?
      end
    end

    return separate_browse_call_num.first if separate_browse_call_num.any?

    return OpenStruct.new(
      scheme: 'OTHER',
      call_number: holding.call_number.to_s,
      to_volume_sort: CallNumbers::ShelfkeyBase.pad_all_digits("other #{holding.call_number}")
    ) if holding.bad_lc_lane_call_number?
    return OpenStruct.new(scheme: holding.call_number_type) if holding.e_call_number?
    return OpenStruct.new(scheme: holding.call_number_type) if holding.ignored_call_number?

    calculated_call_number_type = case holding.call_number_type
                                  when 'LC'
                                    if holding.valid_lc?
                                      'LC'
                                    elsif holding.dewey?
                                      'DEWEY'
                                    else
                                      'OTHER'
                                    end
                                  when 'DEWEY'
                                    'DEWEY'
                                  else
                                    'OTHER'
                                  end

    case calculated_call_number_type
    when 'LC'
      CallNumbers::LC.new(holding.call_number.to_s, serial:)
    when 'DEWEY'
      CallNumbers::Dewey.new(holding.call_number.to_s, serial:)
    else
      non_skipped_or_ignored_holdings = context.clipboard[:non_skipped_or_ignored_holdings_by_library_location_call_number_type]

      call_numbers_in_location = (non_skipped_or_ignored_holdings[[holding.library, LOCATION_MAP[holding.home_location], holding.call_number_type]] || []).map(&:call_number).map(&:to_s)

      CallNumbers::Other.new(
        holding.call_number.to_s,
        longest_common_prefix: Utils.longest_common_prefix(*call_numbers_in_location),
        scheme: holding.call_number_type == 'LC' ? 'OTHER' : holding.call_number_type
      )
    end
  end
end
