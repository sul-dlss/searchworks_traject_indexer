RSpec.describe 'Location facet config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) { cached_indexer('./lib/traject/config/sirsi_config.rb') }
  subject(:result) { indexer.map_record(record) }
  let(:field) { 'location_facet'}

  describe 'Curriculum Collection' do
    context 'with 852 subfield c' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('852', ' ', ' ',
            MARC::Subfield.new('a', 'CSt'),
            MARC::Subfield.new('b', 'EDUCATION'),
            MARC::Subfield.new('c', 'CURRICULUM')
          ))
        end
      end
      it 'is in the curriculum collection' do
        expect(result[field]).to eq ['Curriculum Collection']
      end
    end

    context 'with 999 subfield l (home location) CURRICULUM' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('m', 'EDUCATION'),
            MARC::Subfield.new('l', 'CURRICULUM')
          ))
        end
      end
      it 'is in the curriculum collection' do
        expect(result[field]).to eq ['Curriculum Collection']
      end
    end

    context 'with 999 subfield l (home location) REFERENCE' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('m', 'EDUCATION'),
            MARC::Subfield.new('l', 'REFERENCE')
          ))
        end
      end
      it 'is not in the curriculum collection' do
        expect(result[field]).to be_nil
      end
    end
  end

  describe 'Art Locked Stacks' do
    context 'with 852 subfield c' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('852', ' ', ' ',
            MARC::Subfield.new('a', 'CSt'),
            MARC::Subfield.new('b', 'MATH-CS'),
            MARC::Subfield.new('c', 'ARTLCKL')
          ))
        end
      end
      it 'is in the locked stacks' do
        expect(result[field]).to eq ['Art Locked Stacks']
      end
    end

    context 'with 999 subfield l (home location) CURRICULUM' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('m', 'ART'),
            MARC::Subfield.new('l', 'ARTLCKL-R')
          ))
        end
      end
      it 'is in the locked stacks' do
        expect(result[field]).to eq ['Art Locked Stacks']
      end
    end

    context 'with 999 subfield l (home location) REFERENCE' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('m', 'ART'),
            MARC::Subfield.new('l', 'NOTLOCKED')
          ))
        end
      end
      it 'is not in the locked stacks' do
        expect(result[field]).to be_nil
      end
    end
  end
end
