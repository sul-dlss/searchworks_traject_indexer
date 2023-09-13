# frozen_string_literal: true

module ResultHelpers
  def marc_to_folio_with_stubbed_holdings(marc_record, client: stub_folio_client, instance: {})
    marc_to_folio(marc_record, client:, instance:).tap do |record|
      if marc_record['999']
        stub_sirsi_holdings = []

        marc_record.each_by_tag('999') do |item|
          stub_sirsi_holdings << FolioHolding.new(
            call_number: (item['a'] || '').strip,
            current_location: item['k'],
            home_location: item['l'],
            library: item['m'],
            scheme: item['w'],
            type: item['t'],
            barcode: item['i'],
            public_note: (item['o'] if item['o']&.start_with?(/\.PUBLIC\./i))
          )
        end
        allow(record).to receive(:sirsi_holdings).and_return(stub_sirsi_holdings)
      end
    end
  end

  def marc_to_folio(marc_record, client: stub_folio_client, instance: {})
    FolioRecord.new({
                      'source_record' => [marc_record.to_hash],
                      'instance' => instance.merge({ 'id' => marc_record['001']&.value })
                    }, client)
  end

  def stub_folio_client
    instance_double(FolioClient, instance: {}, items_and_holdings: {}, statistical_codes: [])
  end

  def select_by_id(id)
    results.find { |r| r['id'] == [id] }
  end

  def select_by_field(results, field, value)
    results.select { |r| r[field] == [value] }
  end

  # Ported logic from solrmarc_sw IndexTest.java#assertSingleResult
  def assert_single_result(id, field, value)
    res = select_by_field(results, field, value)
    expect(res.length).to eq 1
    expect(res.first['id']).to eq [id]
  end

  # Ported logic from solrmarc_sw IndexTest.java#assertZeroResult
  def assert_zero_result(field, value)
    res = select_by_field(results, field, value)
    expect(res.length).to eq 0
  end
end
