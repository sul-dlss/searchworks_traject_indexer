# frozen_string_literal: true

RSpec.describe 'Managed purl config' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:records) { MARC::XMLReader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }
  let(:fixture_name) { 'managedPurlTests.xml' }
  subject(:results) { records.map { |rec| indexer.map_record(marc_to_folio(rec)) }.to_a }

  describe 'managed_purl_urls' do
    let(:field) { 'managed_purl_urls' }

    it 'maps the right data' do
      expect(select_by_id('managedPurlItem1Collection')[field]).to eq ['https://purl.stanford.edu/nz353cp1092']
      expect(select_by_id('managedPurlItem3Collections')[field]).to eq ['https://purl.stanford.edu/wd297xz1362']
      expect(select_by_id('managedPurlCollection')[field]).to eq ['https://purl.stanford.edu/ct961sj2730']
      expect(select_by_id('ManagedAnd2UnmanagedPurlCollection')[field]).to eq ['https://purl.stanford.edu/ct961sj2730']
      expect(select_by_id('NoManagedPurlItem')[field]).to be_nil
    end
  end

  describe 'file_id' do
    let(:field) { 'file_id' }

    it 'maps the right data' do
      expect(select_by_id('managedPurlItem1Collection')[field]).to eq ['file1.jpg']
      expect(select_by_id('managedPurlItem3Collections')[field]).to eq ['file1.jpg']
      expect(select_by_id('ManagedAnd2UnmanagedPurlCollection')[field]).to eq nil
      expect(select_by_id('NoManagedPurlItem')[field]).to eq nil
    end
  end

  describe 'collection' do
    let(:field) { 'collection' }

    it 'maps the right data' do
      expect(select_by_id('managedPurlItem1Collection')[field]).to contain_exactly 'sirsi', 'folio', '9615156'
      expect(select_by_id('managedPurlItem3Collections')[field]).to contain_exactly 'sirsi', 'folio', '9615156', '123456789', 'yy000zz1111'
      expect(select_by_id('ManagedAnd2UnmanagedPurlCollection')[field]).to contain_exactly 'sirsi', 'folio'
      expect(select_by_id('NoManagedPurlItem')[field]).to contain_exactly 'sirsi', 'folio'
    end
  end

  describe 'collection_with_title' do
    let(:field) { 'collection_with_title' }

    it 'maps the right data' do
      expect(select_by_id('managedPurlItem1Collection')[field]).to eq ['9615156-|-Francis E. Stafford photographs, 1909-1933']
      expect(select_by_id('managedPurlItem3Collections')[field]).to eq [
        '9615156-|-Francis E. Stafford photographs, 1909-1933', '123456789-|-Test Collection, 1963-2015', 'yy000zz1111-|-Test Collection2, 1968-2015'
      ]
      expect(select_by_id('managedPurlCollection')[field]).to eq nil
      expect(select_by_id('ManagedAnd2UnmanagedPurlCollection')[field]).to eq nil
      expect(select_by_id('NoManagedPurlItem')[field]).to eq nil
    end

    context 'collection_struct' do
      let(:field) { 'collection_struct' }

      it 'maps the right data' do
        expect(select_by_id('managedPurlItem1Collection')[field].map do |x|
                 JSON.parse(x)
               end).to match_array [{ 'druid' => 'yg867hg1375', 'id' => '9615156', 'item_type' => 'item', 'source' => 'SDR-PURL', 'title' => 'Francis E. Stafford photographs, 1909-1933', 'type' => 'collection' }]
      end
    end
  end

  describe 'collection_type' do
    let(:field) { 'collection_type' }

    it 'maps the right data' do
      expect(select_by_id('managedPurlCollection')[field]).to eq ['Digital Collection']
      expect(select_by_id('ManagedAnd2UnmanagedPurlCollection')[field]).to eq ['Digital Collection']
      expect(select_by_id('NoManagedPurlItem')[field]).to eq nil
      expect(select_by_id('managedPurlItem1Collection')[field]).to eq nil
      expect(select_by_id('managedPurlItem3Collections')[field]).to eq nil
    end
  end

  describe 'set' do
    let(:field) { 'set' }

    it 'maps the right data' do
      expect(select_by_id('managedPurlItem1Set1Collection')[field]).to eq ['123456789']
      expect(select_by_id('managedPurlItem1Collection')[field]).to eq nil
      expect(select_by_id('managedPurlCollection')[field]).to eq nil
      expect(select_by_id('ManagedAnd2UnmanagedPurlCollection')[field]).to eq nil
      expect(select_by_id('NoManagedPurlItem')[field]).to eq nil
    end
  end

  describe 'set_with_title' do
    let(:field) { 'set_with_title' }

    it 'maps the right data' do
      expect(select_by_id('managedPurlItem1Set1Collection')[field]).to eq ['123456789-|-Test Set, 1963-2015']
      expect(select_by_id('managedPurlItem3Sets2Collections')[field]).to eq ['aa000bb1111-|-Test set1',
                                                                             'yy000zz1111-|-Test set2', '987654-|-Test set3']
      expect(select_by_id('managedPurlCollection')[field]).to eq nil
      expect(select_by_id('ManagedAnd2UnmanagedPurlCollection')[field]).to eq nil
      expect(select_by_id('NoManagedPurlItem')[field]).to eq nil
    end
  end
end
