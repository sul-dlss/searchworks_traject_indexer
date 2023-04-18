# frozen_string_literal: true

module ResultHelpers
  def select_by_id(id)
    results.select { |r| r['id'] == [id] }.first
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
