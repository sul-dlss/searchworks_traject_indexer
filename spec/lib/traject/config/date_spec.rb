# frozen_string_literal: true

RSpec.describe 'Date config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end
  let(:fixture_name) { 'idTests.mrc' }
  subject(:result) { indexer.map_record(record) }

  describe 'pub_year_ss' do
    let(:field) { 'pub_year_ss' }

    [
      { value_of_008: '      e19439999', expected: '1943' },
      { value_of_008: '      e196u9999', expected: '1960' },
      { value_of_008: '      e19uu9999', expected: nil },
      { value_of_008: '      euuuuuuuu', expected: nil },
      { value_of_008: '      s19432007', expected: '1943' },
      { value_of_008: '      s196u2007', expected: '1960' },
      { value_of_008: '      s19uu2007', expected: nil },
      { value_of_008: '      suuuuuuuu', expected: nil },
      { value_of_008: '      t19432007', expected: '2007' },
      { value_of_008: '      t196u2007', expected: '2007' },
      { value_of_008: '      t196u----', expected: '1960' },
      { value_of_008: '      tuuuuuuuu', expected: nil },
      { value_of_008: '      b19439999', expected: nil },
      { value_of_008: '      c19439999', expected: '1943 -' },
      { value_of_008: '      d19439999', expected: '1943 -' },
      { value_of_008: '      d19431983', expected: '1943 - 1983' },
      { value_of_008: '      duuuu1983', expected: '- 1983' },
      { value_of_008: '      i19439999', expected: '1943 -' },
      { value_of_008: '      k19439999', expected: '1943 -' },
      { value_of_008: '      m19439999', expected: '1943 -' },
      { value_of_008: '      n19439999', expected: nil },
      { value_of_008: '      p19439999', expected: '1943' },
      { value_of_008: '      q19439999', expected: '1943 ...' },
      { value_of_008: '      r19439999', expected: '1943' },
      { value_of_008: '      u19439999', expected: '1943 -' },
      { value_of_008: '      |19439999', expected: nil }
    ].each do |row|
      context "with a record with 008 field #{row[:value_of_008]}" do
        let(:record) do
          MARC::Record.new.tap { |r| r.append(MARC::ControlField.new('008', row[:value_of_008])) }
        end

        it "maps to #{row[:expected]}" do
          if row[:expected].nil?
            expect(result[field]).to be_nil
          else
            expect(result[field]).to eq [row[:expected]]
          end
        end
      end
    end
  end

  describe 'publication_year_isi' do
    let(:field) { 'publication_year_isi' }
    [
      { value_of_008: '      e19439999', expected: '1943' },
      { value_of_008: '      e196u9999', expected: '1960' },
      { value_of_008: '      e19uu9999', expected: nil },
      { value_of_008: '      euuuuuuuu', expected: nil },
      { value_of_008: '      s19432007', expected: '1943' },
      { value_of_008: '      s196u2007', expected: '1960' },
      { value_of_008: '      s19uu2007', expected: nil },
      { value_of_008: '      suuuuuuuu', expected: nil },
      { value_of_008: '      t19432007', expected: '1943' },
      { value_of_008: '      t196u2007', expected: '1960' },
      { value_of_008: '      t19uu2007', expected: nil },
      { value_of_008: '      tuuuuuuuu', expected: nil },
      { value_of_008: '      b19439999', expected: nil },
      { value_of_008: '      c19439999', expected: nil },
      { value_of_008: '      d19439999', expected: nil },
      { value_of_008: '      i19439999', expected: nil },
      { value_of_008: '      k19439999', expected: nil },
      { value_of_008: '      m19439999', expected: nil },
      { value_of_008: '      n19439999', expected: nil },
      { value_of_008: '      p19439999', expected: nil },
      { value_of_008: '      q19439999', expected: nil },
      { value_of_008: '      r19439999', expected: nil },
      { value_of_008: '      u19439999', expected: nil },
      { value_of_008: '      |19439999', expected: nil }
    ].each do |row|
      context "with a record with 008 field #{row[:value_of_008]}" do
        let(:record) do
          MARC::Record.new.tap { |r| r.append(MARC::ControlField.new('008', row[:value_of_008])) }
        end

        it "maps to #{row[:expected]}" do
          if row[:expected].nil?
            expect(result[field]).to be_nil
          else
            expect(result[field]).to eq [row[:expected]]
          end
        end
      end
    end
  end

  describe 'beginning_year_isi' do
    let(:field) { 'beginning_year_isi' }
    [
      { value_of_008: '      c19439999', expected: '1943' },
      { value_of_008: '      c196u9999', expected: '1960' },
      { value_of_008: '      c19uu9999', expected: nil },
      { value_of_008: '      cuuuuuuuu', expected: nil },
      { value_of_008: '      d19432007', expected: '1943' },
      { value_of_008: '      d196u2007', expected: '1960' },
      { value_of_008: '      d19uu2007', expected: nil },
      { value_of_008: '      duuuuuuuu', expected: nil },
      { value_of_008: '      m19432007', expected: '1943' },
      { value_of_008: '      m196u2007', expected: '1960' },
      { value_of_008: '      m19uu2007', expected: nil },
      { value_of_008: '      muuuuuuuu', expected: nil },
      { value_of_008: '      u19432007', expected: '1943' },
      { value_of_008: '      u196u2007', expected: '1960' },
      { value_of_008: '      u19uu2007', expected: nil },
      { value_of_008: '      uuuuuuuuu', expected: nil },
      { value_of_008: '      b19439999', expected: nil },
      { value_of_008: '      e19439999', expected: nil },
      { value_of_008: '      i19439999', expected: nil },
      { value_of_008: '      k19439999', expected: nil },
      { value_of_008: '      n19439999', expected: nil },
      { value_of_008: '      p19439999', expected: nil },
      { value_of_008: '      q19439999', expected: nil },
      { value_of_008: '      r19439999', expected: nil },
      { value_of_008: '      s19439999', expected: nil },
      { value_of_008: '      t19439999', expected: nil },
      { value_of_008: '      |19439999', expected: nil }
    ].each do |row|
      context "with a record with 008 field #{row[:value_of_008]}" do
        let(:record) do
          MARC::Record.new.tap { |r| r.append(MARC::ControlField.new('008', row[:value_of_008])) }
        end

        it "maps to #{row[:expected]}" do
          if row[:expected].nil?
            expect(result[field]).to be_nil
          else
            expect(result[field]).to eq [row[:expected]]
          end
        end
      end
    end
  end

  describe 'earliest_poss_year_isi' do
    let(:field) { 'earliest_poss_year_isi' }
    [
      { value_of_008: '      q19439999', expected: '1943' },
      { value_of_008: '      q196u9999', expected: '1960' },
      { value_of_008: '      q19uu9999', expected: nil },
      { value_of_008: '      quuuuuuuu', expected: nil },
      { value_of_008: '      b19439999', expected: nil },
      { value_of_008: '      c19439999', expected: nil },
      { value_of_008: '      d19439999', expected: nil },
      { value_of_008: '      e19439999', expected: nil },
      { value_of_008: '      i19439999', expected: nil },
      { value_of_008: '      k19439999', expected: nil },
      { value_of_008: '      m19439999', expected: nil },
      { value_of_008: '      n19439999', expected: nil },
      { value_of_008: '      p19439999', expected: nil },
      { value_of_008: '      r19439999', expected: nil },
      { value_of_008: '      s19439999', expected: nil },
      { value_of_008: '      t19439999', expected: nil },
      { value_of_008: '      u19439999', expected: nil },
      { value_of_008: '      |19439999', expected: nil }
    ].each do |row|
      context "with a record with 008 field #{row[:value_of_008]}" do
        let(:record) do
          MARC::Record.new.tap { |r| r.append(MARC::ControlField.new('008', row[:value_of_008])) }
        end

        it "maps to #{row[:expected]}" do
          if row[:expected].nil?
            expect(result[field]).to be_nil
          else
            expect(result[field]).to eq [row[:expected]]
          end
        end
      end
    end
  end

  describe 'release_year_isi' do
    let(:field) { 'release_year_isi' }
    [
      { value_of_008: '      p19439999', expected: '1943' },
      { value_of_008: '      p196u9999', expected: '1960' },
      { value_of_008: '      p19uu9999', expected: nil },
      { value_of_008: '      puuuuuuuu', expected: nil },
      { value_of_008: '      b19439999', expected: nil },
      { value_of_008: '      c19439999', expected: nil },
      { value_of_008: '      d19439999', expected: nil },
      { value_of_008: '      e19439999', expected: nil },
      { value_of_008: '      i19439999', expected: nil },
      { value_of_008: '      k19439999', expected: nil },
      { value_of_008: '      m19439999', expected: nil },
      { value_of_008: '      n19439999', expected: nil },
      { value_of_008: '      q19439999', expected: nil },
      { value_of_008: '      r19439999', expected: nil },
      { value_of_008: '      s19439999', expected: nil },
      { value_of_008: '      t19439999', expected: nil },
      { value_of_008: '      u19439999', expected: nil },
      { value_of_008: '      |19439999', expected: nil }
    ].each do |row|
      context "with a record with 008 field #{row[:value_of_008]}" do
        let(:record) do
          MARC::Record.new.tap { |r| r.append(MARC::ControlField.new('008', row[:value_of_008])) }
        end

        it "maps to #{row[:expected]}" do
          if row[:expected].nil?
            expect(result[field]).to be_nil
          else
            expect(result[field]).to eq [row[:expected]]
          end
        end
      end
    end
  end

  describe 'reprint_year_isi' do
    let(:field) { 'reprint_year_isi' }
    [
      { value_of_008: '      r19439999', expected: '1943' },
      { value_of_008: '      r196u9999', expected: '1960' },
      { value_of_008: '      r19uu9999', expected: nil },
      { value_of_008: '      ruuuuuuuu', expected: nil },
      { value_of_008: '      b19439999', expected: nil },
      { value_of_008: '      c19439999', expected: nil },
      { value_of_008: '      d19439999', expected: nil },
      { value_of_008: '      e19439999', expected: nil },
      { value_of_008: '      i19439999', expected: nil },
      { value_of_008: '      k19439999', expected: nil },
      { value_of_008: '      m19439999', expected: nil },
      { value_of_008: '      n19439999', expected: nil },
      { value_of_008: '      p19439999', expected: nil },
      { value_of_008: '      q19439999', expected: nil },
      { value_of_008: '      s19439999', expected: nil },
      { value_of_008: '      t19439999', expected: nil },
      { value_of_008: '      u19439999', expected: nil },
      { value_of_008: '      |19439999', expected: nil }
    ].each do |row|
      context "with a record with 008 field #{row[:value_of_008]}" do
        let(:record) do
          MARC::Record.new.tap { |r| r.append(MARC::ControlField.new('008', row[:value_of_008])) }
        end

        it "maps to #{row[:expected]}" do
          if row[:expected].nil?
            expect(result[field]).to be_nil
          else
            expect(result[field]).to eq [row[:expected]]
          end
        end
      end
    end
  end

  describe 'ending_year_isi' do
    let(:field) { 'ending_year_isi' }
    [
      { value_of_008: '      d19432007', expected: '2007' },
      { value_of_008: '      d1943200u', expected: '2009' },
      { value_of_008: '      d194320uu', expected: nil },
      { value_of_008: '      d19432uuuu', expected: nil },
      { value_of_008: '      m19432007', expected: '2007' },
      { value_of_008: '      m1943200u', expected: '2009' },
      { value_of_008: '      m194320uu', expected: nil },
      { value_of_008: '      m19432uuuu', expected: nil },
      { value_of_008: '      b19432007', expected: nil },
      { value_of_008: '      c19432007', expected: nil },
      { value_of_008: '      e19432007', expected: nil },
      { value_of_008: '      i19432007', expected: nil },
      { value_of_008: '      k19432007', expected: nil },
      { value_of_008: '      n19432007', expected: nil },
      { value_of_008: '      p19432007', expected: nil },
      { value_of_008: '      q19432007', expected: nil },
      { value_of_008: '      r19432007', expected: nil },
      { value_of_008: '      s19432007', expected: nil },
      { value_of_008: '      t19432007', expected: nil },
      { value_of_008: '      u19432007', expected: nil },
      { value_of_008: '      |19432007', expected: nil }
    ].each do |row|
      context "with a record with 008 field #{row[:value_of_008]}" do
        let(:record) do
          MARC::Record.new.tap { |r| r.append(MARC::ControlField.new('008', row[:value_of_008])) }
        end

        it "maps to #{row[:expected]}" do
          if row[:expected].nil?
            expect(result[field]).to be_nil
          else
            expect(result[field]).to eq [row[:expected]]
          end
        end
      end
    end
  end

  describe 'latest_year_isi' do
    let(:field) { 'latest_year_isi' }
    [
      { value_of_008: '      i19432007', expected: '2007' },
      { value_of_008: '      i1943200u', expected: '2009' },
      { value_of_008: '      i194320uu', expected: nil },
      { value_of_008: '      i19432uuuu', expected: nil },
      { value_of_008: '      k19432007', expected: '2007' },
      { value_of_008: '      k1943200u', expected: '2009' },
      { value_of_008: '      k194320uu', expected: nil },
      { value_of_008: '      k19432uuuu', expected: nil },
      { value_of_008: '      b19432007', expected: nil },
      { value_of_008: '      c19432007', expected: nil },
      { value_of_008: '      d19432007', expected: nil },
      { value_of_008: '      e19432007', expected: nil },
      { value_of_008: '      m19432007', expected: nil },
      { value_of_008: '      n19432007', expected: nil },
      { value_of_008: '      p19432007', expected: nil },
      { value_of_008: '      q19432007', expected: nil },
      { value_of_008: '      r19432007', expected: nil },
      { value_of_008: '      s19432007', expected: nil },
      { value_of_008: '      t19432007', expected: nil },
      { value_of_008: '      u19432007', expected: nil },
      { value_of_008: '      |19432007', expected: nil }
    ].each do |row|
      context "with a record with 008 field #{row[:value_of_008]}" do
        let(:record) do
          MARC::Record.new.tap { |r| r.append(MARC::ControlField.new('008', row[:value_of_008])) }
        end

        it "maps to #{row[:expected]}" do
          if row[:expected].nil?
            expect(result[field]).to be_nil
          else
            expect(result[field]).to eq [row[:expected]]
          end
        end
      end
    end
  end

  describe 'latest_poss_year_isi' do
    let(:field) { 'latest_poss_year_isi' }
    [
      { value_of_008: '      q19432007', expected: '2007' },
      { value_of_008: '      q1943200u', expected: '2009' },
      { value_of_008: '      q194320uu', expected: nil },
      { value_of_008: '      q19432uuuu', expected: nil },
      { value_of_008: '      b19432007', expected: nil },
      { value_of_008: '      c19432007', expected: nil },
      { value_of_008: '      d19432007', expected: nil },
      { value_of_008: '      e19432007', expected: nil },
      { value_of_008: '      i19432007', expected: nil },
      { value_of_008: '      k19432007', expected: nil },
      { value_of_008: '      m19432007', expected: nil },
      { value_of_008: '      n19432007', expected: nil },
      { value_of_008: '      p19432007', expected: nil },
      { value_of_008: '      r19432007', expected: nil },
      { value_of_008: '      s19432007', expected: nil },
      { value_of_008: '      t19432007', expected: nil },
      { value_of_008: '      u19432007', expected: nil },
      { value_of_008: '      |19432007', expected: nil }
    ].each do |row|
      context "with a record with 008 field #{row[:value_of_008]}" do
        let(:record) do
          MARC::Record.new.tap { |r| r.append(MARC::ControlField.new('008', row[:value_of_008])) }
        end

        it "maps to #{row[:expected]}" do
          if row[:expected].nil?
            expect(result[field]).to be_nil
          else
            expect(result[field]).to eq [row[:expected]]
          end
        end
      end
    end
  end

  describe 'production_year_isi' do
    let(:field) { 'production_year_isi' }
    [
      { value_of_008: '      p19432007', expected: '2007' },
      { value_of_008: '      p1943200u', expected: '2009' },
      { value_of_008: '      p194320uu', expected: nil },
      { value_of_008: '      p19432uuuu', expected: nil },
      { value_of_008: '      b19432007', expected: nil },
      { value_of_008: '      c19432007', expected: nil },
      { value_of_008: '      d19432007', expected: nil },
      { value_of_008: '      e19432007', expected: nil },
      { value_of_008: '      i19432007', expected: nil },
      { value_of_008: '      k19432007', expected: nil },
      { value_of_008: '      m19432007', expected: nil },
      { value_of_008: '      n19432007', expected: nil },
      { value_of_008: '      q19432007', expected: nil },
      { value_of_008: '      r19432007', expected: nil },
      { value_of_008: '      s19432007', expected: nil },
      { value_of_008: '      t19432007', expected: nil },
      { value_of_008: '      u19432007', expected: nil },
      { value_of_008: '      |19432007', expected: nil }
    ].each do |row|
      context "with a record with 008 field #{row[:value_of_008]}" do
        let(:record) do
          MARC::Record.new.tap { |r| r.append(MARC::ControlField.new('008', row[:value_of_008])) }
        end

        it "maps to #{row[:expected]}" do
          if row[:expected].nil?
            expect(result[field]).to be_nil
          else
            expect(result[field]).to eq [row[:expected]]
          end
        end
      end
    end
  end

  describe 'original_year_isi' do
    let(:field) { 'original_year_isi' }
    [
      { value_of_008: '      r19432007', expected: '2007' },
      { value_of_008: '      r1943200u', expected: '2009' },
      { value_of_008: '      r194320uu', expected: nil },
      { value_of_008: '      r19432uuuu', expected: nil },
      { value_of_008: '      b19432007', expected: nil },
      { value_of_008: '      c19432007', expected: nil },
      { value_of_008: '      d19432007', expected: nil },
      { value_of_008: '      e19432007', expected: nil },
      { value_of_008: '      i19432007', expected: nil },
      { value_of_008: '      k19432007', expected: nil },
      { value_of_008: '      m19432007', expected: nil },
      { value_of_008: '      n19432007', expected: nil },
      { value_of_008: '      p19432007', expected: nil },
      { value_of_008: '      q19432007', expected: nil },
      { value_of_008: '      s19432007', expected: nil },
      { value_of_008: '      t19432007', expected: nil },
      { value_of_008: '      u19432007', expected: nil },
      { value_of_008: '      |19432007', expected: nil }
    ].each do |row|
      context "with a record with 008 field #{row[:value_of_008]}" do
        let(:record) do
          MARC::Record.new.tap { |r| r.append(MARC::ControlField.new('008', row[:value_of_008])) }
        end

        it "maps to #{row[:expected]}" do
          if row[:expected].nil?
            expect(result[field]).to be_nil
          else
            expect(result[field]).to eq [row[:expected]]
          end
        end
      end
    end
  end

  describe 'copyright_year_isi' do
    let(:field) { 'copyright_year_isi' }
    [
      { value_of_008: '      t19432007', expected: '2007' },
      { value_of_008: '      t1943200u', expected: '2009' },
      { value_of_008: '      t194320uu', expected: nil },
      { value_of_008: '      t19432uuuu', expected: nil },
      { value_of_008: '      b19432007', expected: nil },
      { value_of_008: '      c19432007', expected: nil },
      { value_of_008: '      d19432007', expected: nil },
      { value_of_008: '      e19432007', expected: nil },
      { value_of_008: '      i19432007', expected: nil },
      { value_of_008: '      k19432007', expected: nil },
      { value_of_008: '      m19432007', expected: nil },
      { value_of_008: '      n19432007', expected: nil },
      { value_of_008: '      p19432007', expected: nil },
      { value_of_008: '      q19432007', expected: nil },
      { value_of_008: '      r19432007', expected: nil },
      { value_of_008: '      s19432007', expected: nil },
      { value_of_008: '      u19432007', expected: nil },
      { value_of_008: '      |19432007', expected: nil }
    ].each do |row|
      context "with a record with 008 field #{row[:value_of_008]}" do
        let(:record) do
          MARC::Record.new.tap { |r| r.append(MARC::ControlField.new('008', row[:value_of_008])) }
        end

        it "maps to #{row[:expected]}" do
          if row[:expected].nil?
            expect(result[field]).to be_nil
          else
            expect(result[field]).to eq [row[:expected]]
          end
        end
      end
    end
  end

  describe 'other_year_isi' do
    let(:field) { 'other_year_isi' }
    [
      { value_of_008: '      b1943    ', expected: '1943' },
      { value_of_008: '      b194u    ', expected: '1940' },
      { value_of_008: '      b19uu    ', expected: nil },
      { value_of_008: '      b        ', expected: nil },
      { value_of_008: '      n1943    ', expected: '1943' },
      { value_of_008: '      n194u    ', expected: '1940' },
      { value_of_008: '      n||||    ', expected: nil },
      { value_of_008: '      |1943    ', expected: '1943' },
      { value_of_008: '      |194u    ', expected: '1940' },
      { value_of_008: '      |||||    ', expected: nil },
      { value_of_008: '      $1943    ', expected: '1943' },
      { value_of_008: '      $194u    ', expected: '1940' },
      { value_of_008: '      $19uu    ', expected: nil },
      { value_of_008: '      $||||    ', expected: nil },
      { value_of_008: '      c19432007', expected: nil },
      { value_of_008: '      d19432007', expected: nil },
      { value_of_008: '      e19432007', expected: nil },
      { value_of_008: '      i19432007', expected: nil },
      { value_of_008: '      k19432007', expected: nil },
      { value_of_008: '      m19432007', expected: nil },
      { value_of_008: '      p19432007', expected: nil },
      { value_of_008: '      q19432007', expected: nil },
      { value_of_008: '      r19432007', expected: nil },
      { value_of_008: '      s19432007', expected: nil },
      { value_of_008: '      u19432007', expected: nil }
    ].each do |row|
      context "with a record with 008 field #{row[:value_of_008]}" do
        let(:record) do
          MARC::Record.new.tap { |r| r.append(MARC::ControlField.new('008', row[:value_of_008])) }
        end

        it "maps to #{row[:expected]}" do
          if row[:expected].nil?
            expect(result[field]).to be_nil
          else
            expect(result[field]).to eq [row[:expected]]
          end
        end
      end
    end
  end

  describe 'date_cataloged' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }

    let(:records) { MARC::XMLReader.new(file_fixture(fixture_name).to_s).to_a }
    let(:fixture_name) { 'newItemsDateCataloged.xml' }
    let(:record) { records.first }
    let(:field) { 'date_cataloged' }

    it 'is nil if the 916b is NEVER' do
      result = select_by_id('7000010')[field]
      expect(result).to be_nil
    end

    it 'is nil if there is no 916b' do
      result = select_by_id('7000023')[field]
      expect(result).to be_nil
    end

    it 'is an ISO8601 date' do
      result = select_by_id('7000011')[field]
      expect(result).to eq ['2007-11-08T00:00:00Z']
    end
  end

  context 'a blank record (particularly without an 008 field)' do
    subject(:result) { |_rec| indexer.map_record(record) }
    let(:record) { MARC::Record.new }

    it 'indexes fine' do
      expect(result.keys).not_to include(/year_isi$/)
    end
  end
end
