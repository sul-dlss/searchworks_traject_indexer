require 'spec_helper'
RSpec.describe 'All_search config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) { cached_indexer('./lib/traject/config/sirsi_config.rb') }
  let(:fixture_name) { 'allfieldsTests.mrc' }
  let(:base_record) do
    MARC::Record.new.tap do |r|
      r.leader =  '01952cas  2200457Ia 4500'
      r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 0 eng d'))
    end
  end
  subject(:result) { indexer.map_record(record) }
  let(:field) { 'preferred_barcode' }

  describe 'preferred_barcode' do
    context 'with lc only' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'QE538.8 .N36 1975-1977'),
            MARC::Subfield.new('w', 'LC'),
            MARC::Subfield.new('i', 'LCbarcode'),
            MARC::Subfield.new('m', 'GREEN')
          ))
        end
      end

      specify { expect(result[field]).to eq ['LCbarcode'] }
    end

    context 'with lc + dewey' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'QE538.8 .N36 1975-1977'),
            MARC::Subfield.new('w', 'LC'),
            MARC::Subfield.new('i', 'LCbarcode'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', '159.32 .W211'),
            MARC::Subfield.new('w', 'DEWEY'),
            MARC::Subfield.new('i', 'DeweyBarcode'),
            MARC::Subfield.new('m', 'GREEN')
          ))
        end
      end

      specify { expect(result[field]).to eq ['LCbarcode'] }
    end

    context 'with lc + dewey + sudoc' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'QE538.8 .N36 1975-1977'),
            MARC::Subfield.new('w', 'LC'),
            MARC::Subfield.new('i', 'LCbarcode'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', '159.32 .W211'),
            MARC::Subfield.new('w', 'DEWEY'),
            MARC::Subfield.new('i', 'DeweyBarcode'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'I 19.76:98-600-B'),
            MARC::Subfield.new('w', 'SUDOC'),
            MARC::Subfield.new('i', 'SudocBarcode'),
            MARC::Subfield.new('m', 'GREEN')
          ))
        end
      end

      specify { expect(result[field]).to eq ['LCbarcode'] }
    end

    context 'with lc + dewey + sudoc + alphanum' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'QE538.8 .N36 1975-1977'),
            MARC::Subfield.new('w', 'LC'),
            MARC::Subfield.new('i', 'LCbarcode'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', '159.32 .W211'),
            MARC::Subfield.new('w', 'DEWEY'),
            MARC::Subfield.new('i', 'DeweyBarcode'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'I 19.76:98-600-B'),
            MARC::Subfield.new('w', 'SUDOC'),
            MARC::Subfield.new('i', 'SudocBarcode'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'ISHII SPRING 2009'),
            MARC::Subfield.new('w', 'ALPHANUM'),
            MARC::Subfield.new('i', 'AlphanumBarcode'),
            MARC::Subfield.new('m', 'GREEN')
          ))
        end
      end

      specify { expect(result[field]).to eq ['LCbarcode'] }
    end

    context 'with lc + dewey + sudoc + alphanum' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', '159.32 .W211'),
            MARC::Subfield.new('w', 'DEWEY'),
            MARC::Subfield.new('i', 'DeweyBarcode'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'I 19.76:98-600-B'),
            MARC::Subfield.new('w', 'SUDOC'),
            MARC::Subfield.new('i', 'SudocBarcode'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'ISHII SPRING 2009'),
            MARC::Subfield.new('w', 'ALPHANUM'),
            MARC::Subfield.new('i', 'AlphanumBarcode'),
            MARC::Subfield.new('m', 'GREEN')
          ))
        end
      end

      specify { expect(result[field]).to eq ['DeweyBarcode'] }
    end

    context 'with sudoc + alphanum' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'I 19.76:98-600-B'),
            MARC::Subfield.new('w', 'SUDOC'),
            MARC::Subfield.new('i', 'SudocBarcode'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'ISHII SPRING 2009'),
            MARC::Subfield.new('w', 'ALPHANUM'),
            MARC::Subfield.new('i', 'AlphanumBarcode'),
            MARC::Subfield.new('m', 'GREEN')
          ))
        end
      end

      specify { expect(result[field]).to eq ['SudocBarcode'] }
    end

    context 'with alphanum' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'ISHII SPRING 2009'),
            MARC::Subfield.new('w', 'ALPHANUM'),
            MARC::Subfield.new('i', 'AlphanumBarcode'),
            MARC::Subfield.new('m', 'GREEN')
          ))
        end
      end

      specify { expect(result[field]).to eq ['AlphanumBarcode'] }
    end

    context 'with dewey + alphanum' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', '159.32 .W211'),
            MARC::Subfield.new('w', 'DEWEY'),
            MARC::Subfield.new('i', 'DeweyBarcode'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'ISHII SPRING 2009'),
            MARC::Subfield.new('w', 'ALPHANUM'),
            MARC::Subfield.new('i', 'AlphanumBarcode'),
            MARC::Subfield.new('m', 'GREEN')
          ))
        end
      end

      specify { expect(result[field]).to eq ['DeweyBarcode'] }
    end


    context 'with lc + alphanum' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'QE538.8 .N36 1975-1977'),
            MARC::Subfield.new('w', 'LC'),
            MARC::Subfield.new('i', 'LCbarcode'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'ISHII SPRING 2009'),
            MARC::Subfield.new('w', 'ALPHANUM'),
            MARC::Subfield.new('i', 'AlphanumBarcode'),
            MARC::Subfield.new('m', 'GREEN')
          ))
        end
      end

      specify { expect(result[field]).to eq ['LCbarcode'] }
    end
  end

  context 'with lc untruncated' do
    let(:record) do
      base_record.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'QE538.8 .N36 1975-1977'),
          MARC::Subfield.new('w', 'LC'),
          MARC::Subfield.new('i', 'LCbarcode'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    specify { expect(result[field]).to eq ['LCbarcode'] }
  end

  context 'with lc untruncated + dewey truncated' do
    let(:record) do
      base_record.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'QE538.8 .N36 1975-1977'),
          MARC::Subfield.new('w', 'LC'),
          MARC::Subfield.new('i', 'LCbarcode'),
          MARC::Subfield.new('m', 'GREEN')
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', '888.4 .J788 V.5'),
          MARC::Subfield.new('w', 'DEWEY'),
          MARC::Subfield.new('i', 'Dewey1'),
          MARC::Subfield.new('m', 'GREEN')
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', '888.4 .J788 V.6'),
          MARC::Subfield.new('w', 'DEWEY'),
          MARC::Subfield.new('i', 'Dewey2'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    specify { expect(result[field]).to eq ['LCbarcode'] }
  end

  context 'with lc untruncated + dewey truncated + sudoc truncated' do
    let(:record) do
      base_record.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'QE538.8 .N36 1975-1977'),
          MARC::Subfield.new('w', 'LC'),
          MARC::Subfield.new('i', 'LCbarcode'),
          MARC::Subfield.new('m', 'GREEN')
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', '888.4 .J788 V.5'),
          MARC::Subfield.new('w', 'DEWEY'),
          MARC::Subfield.new('i', 'Dewey1'),
          MARC::Subfield.new('m', 'GREEN')
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', '888.4 .J788 V.6'),
          MARC::Subfield.new('w', 'DEWEY'),
          MARC::Subfield.new('i', 'Dewey2'),
          MARC::Subfield.new('m', 'GREEN')
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'Y 4.G 74/7-11:110"'),
          MARC::Subfield.new('w', 'SUDOC'),
          MARC::Subfield.new('i', 'Sudoc1'),
          MARC::Subfield.new('m', 'GREEN')
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'Y 4.G 74/7-11:1101'),
          MARC::Subfield.new('w', 'SUDOC'),
          MARC::Subfield.new('i', 'Sudoc2'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    specify { expect(result[field]).to eq ['LCbarcode'] }
  end

  context 'with lc untruncated + dewey truncated + sudoc truncated + alphanum truncated' do
    let(:record) do
      base_record.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'QE538.8 .N36 1975-1977'),
          MARC::Subfield.new('w', 'LC'),
          MARC::Subfield.new('i', 'LCbarcode'),
          MARC::Subfield.new('m', 'GREEN')
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', '888.4 .J788 V.5'),
          MARC::Subfield.new('w', 'DEWEY'),
          MARC::Subfield.new('i', 'Dewey1'),
          MARC::Subfield.new('m', 'GREEN')
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', '888.4 .J788 V.6'),
          MARC::Subfield.new('w', 'DEWEY'),
          MARC::Subfield.new('i', 'Dewey2'),
          MARC::Subfield.new('m', 'GREEN')
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'Y 4.G 74/7-11:110"'),
          MARC::Subfield.new('w', 'SUDOC'),
          MARC::Subfield.new('i', 'Sudoc1'),
          MARC::Subfield.new('m', 'GREEN')
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'Y 4.G 74/7-11:1101'),
          MARC::Subfield.new('w', 'SUDOC'),
          MARC::Subfield.new('i', 'Sudoc2'),
          MARC::Subfield.new('m', 'GREEN')
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'ZDVD 19791 DISC 1'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('i', 'Alpha1'),
          MARC::Subfield.new('m', 'GREEN')
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'ZDVD 19791 DISC 2'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('i', 'Alpha2'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    specify { expect(result[field]).to eq ['LCbarcode'] }
  end

  context 'with dewey untruncated + sudoc truncated + alphanum truncated' do
    let(:record) do
      base_record.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', '888.4 .J788 V.5'),
          MARC::Subfield.new('w', 'DEWEY'),
          MARC::Subfield.new('i', 'Dewey1'),
          MARC::Subfield.new('m', 'GREEN')
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'Y 4.G 74/7-11:110"'),
          MARC::Subfield.new('w', 'SUDOC'),
          MARC::Subfield.new('i', 'Sudoc1'),
          MARC::Subfield.new('m', 'GREEN')
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'Y 4.G 74/7-11:1101'),
          MARC::Subfield.new('w', 'SUDOC'),
          MARC::Subfield.new('i', 'Sudoc2'),
          MARC::Subfield.new('m', 'GREEN')
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'ZDVD 19791 DISC 1'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('i', 'Alpha1'),
          MARC::Subfield.new('m', 'GREEN')
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'ZDVD 19791 DISC 2'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('i', 'Alpha2'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    specify { expect(result[field]).to eq ['Dewey1'] }
  end

  context 'with sudoc untruncated + alphanum truncated' do
    let(:record) do
      base_record.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'Y 4.G 74/7-11:110"'),
          MARC::Subfield.new('w', 'SUDOC'),
          MARC::Subfield.new('i', 'Sudoc1'),
          MARC::Subfield.new('m', 'GREEN')
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'ZDVD 19791 DISC 1'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('i', 'Alpha1'),
          MARC::Subfield.new('m', 'GREEN')
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'ZDVD 19791 DISC 2'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('i', 'Alpha2'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    specify { expect(result[field]).to eq ['Sudoc1'] }
  end

  context 'with dewey untruncated + alphanum truncated' do
    let(:record) do
      base_record.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', '888.4 .J788 V.5'),
          MARC::Subfield.new('w', 'DEWEY'),
          MARC::Subfield.new('i', 'Dewey1'),
          MARC::Subfield.new('m', 'GREEN')
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'ZDVD 19791 DISC 1'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('i', 'Alpha1'),
          MARC::Subfield.new('m', 'GREEN')
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'ZDVD 19791 DISC 2'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('i', 'Alpha2'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    specify { expect(result[field]).to eq ['Dewey1'] }
  end

  describe 'prefers the shorted non-truncated callnumber' do
    context 'with lc only' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'QE538.8 .N36 1975-1977'),
            MARC::Subfield.new('w', 'LC'),
            MARC::Subfield.new('i', '666'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'D764.7 .K72 1990'),
            MARC::Subfield.new('w', 'LC'),
            MARC::Subfield.new('i', '777'),
            MARC::Subfield.new('m', 'GREEN')
          ))
        end
      end

      specify { expect(result[field]).to eq ['777'] }
    end

    context 'with dewey ' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', '888.4 .J788 V.5'),
            MARC::Subfield.new('w', 'DEWEY'),
            MARC::Subfield.new('i', 'Dewey1'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', '505 .N285B V.241-245 1973'),
            MARC::Subfield.new('w', 'DEWEY'),
            MARC::Subfield.new('i', 'Dewey2'),
            MARC::Subfield.new('m', 'GREEN'),
            MARC::Subfield.new('l', 'LOCATION')

          ))
        end
      end

      specify { expect(result[field]).to eq ['Dewey1'] }
    end

    context 'with sudoc' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'Y 4.G 74/7-11:110'),
            MARC::Subfield.new('w', 'SUDOC'),
            MARC::Subfield.new('i', 'Sudoc1'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'A 13.78:NC-315'),
            MARC::Subfield.new('w', 'SUDOC'),
            MARC::Subfield.new('i', 'Sudoc2'),
            MARC::Subfield.new('m', 'GREEN'),
            MARC::Subfield.new('l', 'LOCATION')
          ))
        end
      end

      specify { expect(result[field]).to eq ['Sudoc2'] }
    end

    context 'with alphanum' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'ZDVD 19791'),
            MARC::Subfield.new('w', 'ALPHANUM'),
            MARC::Subfield.new('i', 'Alpha1'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'ARTDVD 1234'),
            MARC::Subfield.new('w', 'ALPHANUM'),
            MARC::Subfield.new('i', 'Alpha2'),
            MARC::Subfield.new('m', 'GREEN'),
            MARC::Subfield.new('l', 'LOCATION')
          ))
        end
      end

      specify { expect(result[field]).to eq ['Alpha1'] }
    end
  end

  describe 'picking the shortest truncated callnumber when the number of items is the same' do
    context 'with lc only' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'QE538.8 .N36 1975-1977'),
            MARC::Subfield.new('w', 'LC'),
            MARC::Subfield.new('i', 'lc1'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'QE538.8 .N36 1978-1980'),
            MARC::Subfield.new('w', 'LC'),
            MARC::Subfield.new('i', 'lc2'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'E184.S75 R47A V.1 1980'),
            MARC::Subfield.new('w', 'LC'),
            MARC::Subfield.new('i', 'lc3'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'E184.S75 R47A V.2 1980'),
            MARC::Subfield.new('w', 'LC'),
            MARC::Subfield.new('i', 'lc4'),
            MARC::Subfield.new('m', 'GREEN')
          ))
        end
      end

      specify do
        pending 'Waiting for some decision about how items should be sorted within a lopped call number set'
        expect(result[field]).to eq ['lc1']
      end
    end

    context 'with dewey only' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', '888.4 .J788 V.5'),
            MARC::Subfield.new('w', 'DEWEY'),
            MARC::Subfield.new('i', 'dewey1'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', '888.4 .J788 V.6'),
            MARC::Subfield.new('w', 'DEWEY'),
            MARC::Subfield.new('i', 'dewey2'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', '505 .N285B V.241-245 1973'),
            MARC::Subfield.new('w', 'DEWEY'),
            MARC::Subfield.new('i', 'dewey3'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', '505 .N285B V.241-245 1975'),
            MARC::Subfield.new('w', 'DEWEY'),
            MARC::Subfield.new('i', 'dewey4'),
            MARC::Subfield.new('m', 'GREEN')
          ))
        end
      end

      specify { expect(result[field]).to eq ['dewey4'] }
    end

    context 'with sudoc only' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'Y 4.G 74/7-11:110'),
            MARC::Subfield.new('w', 'SUDOC'),
            MARC::Subfield.new('i', 'sudoc1'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'Y 4.G 74/7-11:222'),
            MARC::Subfield.new('w', 'SUDOC'),
            MARC::Subfield.new('i', 'sudoc2'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'A 13.78:NC-315'),
            MARC::Subfield.new('w', 'SUDOC'),
            MARC::Subfield.new('i', 'sudoc3'),
            MARC::Subfield.new('m', 'GREEN'),
            MARC::Subfield.new('l', 'SOMEWHERE')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'A 13.78:NC-315 1947'),
            MARC::Subfield.new('w', 'SUDOC'),
            MARC::Subfield.new('i', 'sudoc4'),
            MARC::Subfield.new('m', 'GREEN'),
            MARC::Subfield.new('l', 'SOMEWHERE')
          ))
        end
      end

      specify { expect(result[field]).to eq ['sudoc1'] }
    end

    context 'with alphanum only' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'ZDVD 19791 DISC 1'),
            MARC::Subfield.new('w', 'ALPHANUM'),
            MARC::Subfield.new('i', 'alpha1'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'ZDVD 19791 DISC 2'),
            MARC::Subfield.new('w', 'ALPHANUM'),
            MARC::Subfield.new('i', 'alpha2'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'ARTDVD 666666 DISC 1'),
            MARC::Subfield.new('w', 'ALPHANUM'),
            MARC::Subfield.new('i', 'alpha3'),
            MARC::Subfield.new('m', 'GREEN'),
            MARC::Subfield.new('l', 'SOMEWHERE')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'ARTDVD 666666 DISC 2'),
            MARC::Subfield.new('w', 'ALPHANUM'),
            MARC::Subfield.new('i', 'alpha4'),
            MARC::Subfield.new('m', 'GREEN'),
            MARC::Subfield.new('l', 'SOMEWHERE')
          ))
        end
      end


      specify do
        expect(result[field]).to eq ['alpha1']
      end
    end
  end

  describe 'prefer more items over a shorter key' do
    context 'with lc only' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'QE538.8 .N36 1975-1977'),
            MARC::Subfield.new('w', 'LC'),
            MARC::Subfield.new('i', 'lc1'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'QE538.8 .N36 1978-1980'),
            MARC::Subfield.new('w', 'LC'),
            MARC::Subfield.new('i', 'lc2'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'E184.S75 R47A V.1 1980'),
            MARC::Subfield.new('w', 'LC'),
            MARC::Subfield.new('i', 'lc3'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'E184.S75 R47A V.2 1980'),
            MARC::Subfield.new('w', 'LC'),
            MARC::Subfield.new('i', 'lc4'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'E184.S75 R47A V.3'),
            MARC::Subfield.new('w', 'LC'),
            MARC::Subfield.new('i', 'lc5'),
            MARC::Subfield.new('m', 'GREEN')
          ))
        end
      end

      specify { expect(result[field]).to eq ['lc5'] }
    end

    context 'with dewey only' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', '888.4 .J788 V.5'),
            MARC::Subfield.new('w', 'DEWEY'),
            MARC::Subfield.new('i', 'dewey1'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', '888.4 .J788 V.6'),
            MARC::Subfield.new('w', 'DEWEY'),
            MARC::Subfield.new('i', 'dewey2'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', '505 .N285B V.241-245 1973'),
            MARC::Subfield.new('w', 'DEWEY'),
            MARC::Subfield.new('i', 'dewey3'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', '505 .N285B V.241-245 1975'),
            MARC::Subfield.new('w', 'DEWEY'),
            MARC::Subfield.new('i', 'dewey4'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', '505 .N285B V.283-285'),
            MARC::Subfield.new('w', 'DEWEY'),
            MARC::Subfield.new('i', 'dewey5'),
            MARC::Subfield.new('m', 'GREEN')
          ))
        end
      end

      specify { expect(result[field]).to eq ['dewey5'] }
    end

    context 'with sudoc only' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'Y 4.G 74/7-11:110'),
            MARC::Subfield.new('w', 'SUDOC'),
            MARC::Subfield.new('i', 'sudoc1'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'Y 4.G 74/7-11:222'),
            MARC::Subfield.new('w', 'SUDOC'),
            MARC::Subfield.new('i', 'sudoc2'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'A 13.78:NC-315'),
            MARC::Subfield.new('w', 'SUDOC'),
            MARC::Subfield.new('i', 'sudoc3'),
            MARC::Subfield.new('m', 'GREEN'),
            MARC::Subfield.new('l', 'SOMEWHERE')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'A 13.78:NC-315 1947'),
            MARC::Subfield.new('w', 'SUDOC'),
            MARC::Subfield.new('i', 'sudoc4'),
            MARC::Subfield.new('m', 'GREEN'),
            MARC::Subfield.new('l', 'SOMEWHERE')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'A 13.78:NC-315 1956'),
            MARC::Subfield.new('w', 'SUDOC'),
            MARC::Subfield.new('i', 'sudoc5'),
            MARC::Subfield.new('m', 'GREEN'),
            MARC::Subfield.new('l', 'SOMEWHERE')
          ))
        end
      end

      specify { expect(result[field]).to eq ['sudoc3'] }
    end

    context 'with alphanum only' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'ZDVD 19791 DISC 1'),
            MARC::Subfield.new('w', 'ALPHANUM'),
            MARC::Subfield.new('i', 'alpha1'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'ZDVD 19791 DISC 2'),
            MARC::Subfield.new('w', 'ALPHANUM'),
            MARC::Subfield.new('i', 'alpha2'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'ARTDVD 666666 DISC 1'),
            MARC::Subfield.new('w', 'ALPHANUM'),
            MARC::Subfield.new('i', 'alpha3'),
            MARC::Subfield.new('m', 'GREEN'),
            MARC::Subfield.new('l', 'SOMEWHERE')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'ARTDVD 666666 DISC 2'),
            MARC::Subfield.new('w', 'ALPHANUM'),
            MARC::Subfield.new('i', 'alpha4'),
            MARC::Subfield.new('m', 'GREEN'),
            MARC::Subfield.new('l', 'SOMEWHERE')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'ARTDVD 666666 DISC 3'),
            MARC::Subfield.new('w', 'ALPHANUM'),
            MARC::Subfield.new('i', 'alpha5'),
            MARC::Subfield.new('m', 'GREEN'),
            MARC::Subfield.new('l', 'SOMEWHERE')
          ))
        end
      end

      specify { expect(result[field]).to eq ['alpha3'] }
    end
  end

  describe 'with non-Green locations' do
    context 'with lc only' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'ZDVD 19791 DISC 1'),
            MARC::Subfield.new('w', 'ALPHANUM'),
            MARC::Subfield.new('i', 'alpha1'),
            MARC::Subfield.new('m', 'GREEN')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'QE538.8 .N36 V.7'),
            MARC::Subfield.new('w', 'LC'),
            MARC::Subfield.new('i', 'ArsLC1'),
            MARC::Subfield.new('m', 'ARS')
          ))
        end
      end

      specify { expect(result[field]).to eq ['alpha1'] }
    end

    context 'libraries prioritized in alpha order by code' do
      let(:record) do
        base_record.tap do |r|
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'M57 .N42'),
            MARC::Subfield.new('w', 'LC'),
            MARC::Subfield.new('i', 'ArtBarcode'),
            MARC::Subfield.new('m', 'ART')
          ))
          r.append(MARC::DataField.new('999', ' ', ' ',
            MARC::Subfield.new('a', 'M57 .N42'),
            MARC::Subfield.new('w', 'LC'),
            MARC::Subfield.new('i', 'EngBarcode'),
            MARC::Subfield.new('m', 'ENG')
          ))
        end
      end

      specify { expect(result[field]).to eq ['ArtBarcode'] }
    end
  end

  context 'with an online item' do
    let(:record) do
      base_record.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'INTERNET RESOURCE'),
          MARC::Subfield.new('w', 'ASIS'),
          MARC::Subfield.new('i', 'onlineByCallnum'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    specify { expect(result[field]).to eq nil }
  end

  context 'with an online item with a bib callnumber' do
    let(:record) do
      base_record.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'INTERNET RESOURCE'),
          MARC::Subfield.new('w', 'ASIS'),
          MARC::Subfield.new('i', 'onlineByCallnum'),
          MARC::Subfield.new('m', 'GREEN')
        ))
        r.append(MARC::DataField.new('050', ' ', ' ',
          MARC::Subfield.new('a', 'AB123'),
          MARC::Subfield.new('b', 'C45')
        ))
      end
    end

    specify { expect(result[field]).to eq ['onlineByCallnum'] }
  end

  context 'with an item with an INTERNET location' do
    let(:record) do
      base_record.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'AB123 .C45'),
          MARC::Subfield.new('w', 'ASIS'),
          MARC::Subfield.new('i', 'onlineByLoc'),
          MARC::Subfield.new('m', 'GREEN'),
          MARC::Subfield.new('l', 'INTERNET')
        ))
      end
    end

    specify { expect(result[field]).to eq ['onlineByLoc'] }
  end

  context 'with an item with an online item with callnum matches another group' do
    let(:record) do
      base_record.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'AB123 .C45'),
          MARC::Subfield.new('w', 'ASIS'),
          MARC::Subfield.new('i', 'onlineByLoc'),
          MARC::Subfield.new('m', 'GREEN'),
          MARC::Subfield.new('l', 'INTERNET')
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'AB123 .C45'),
          MARC::Subfield.new('w', 'LC'),
          MARC::Subfield.new('i', 'notOnline'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    specify { expect(result[field]).to eq ['notOnline'] }
  end

  context 'with an ignored call number' do
    let(:record) do
      base_record.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'NO CALL NUMBER'),
          MARC::Subfield.new('w', 'OTHER'),
          MARC::Subfield.new('i', 'noCallNum'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    specify { expect(result[field]).to eq nil }
  end

  context 'with a shelby location' do
    let(:record) do
      base_record.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'M1503 .A5 VOL.22'),
          MARC::Subfield.new('w', 'LC'),
          MARC::Subfield.new('i', 'shelby'),
          MARC::Subfield.new('m', 'GREEN'),
          MARC::Subfield.new('k', 'SHELBYTITL')
        ))
      end
    end

    specify { expect(result[field]).to eq ['shelby'] }
  end

  context 'with a missing location' do
    let(:record) do
      base_record.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'AB123 C45'),
          MARC::Subfield.new('w', 'LC'),
          MARC::Subfield.new('i', 'missing'),
          MARC::Subfield.new('m', 'GREEN'),
          MARC::Subfield.new('l', 'MISSING')
        ))
      end
    end

    specify { expect(result[field]).to eq ['missing'] }
  end

  context 'with a missing location' do
    let(:record) do
      base_record.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'AB123 C45'),
          MARC::Subfield.new('w', 'LC'),
          MARC::Subfield.new('i', 'lost'),
          MARC::Subfield.new('m', 'GREEN'),
          MARC::Subfield.new('l', 'LOST-PAID')
        ))
      end
    end

    specify { expect(result[field]).to eq ['lost'] }
  end

  context 'with no items' do
    let(:record) do
      base_record
    end

    specify { expect(result[field]).to eq nil }
  end

  context 'with ignored callnums with no browsable callnum' do
    let(:record) do
      base_record.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'NO CALL NUMBER'),
          MARC::Subfield.new('w', 'ASIS'),
          MARC::Subfield.new('i', 'nocallnum'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    specify { expect(result[field]).to eq nil }
  end

  context 'with a bad lane lc callnum' do
    let(:record) do
      base_record.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'XX13413'),
          MARC::Subfield.new('w', 'LC'),
          MARC::Subfield.new('i', 'lane'),
          MARC::Subfield.new('m', 'LANE-MED'),
          MARC::Subfield.new('l', 'ASK@LANE'),
        ))
      end
    end

    specify { expect(result[field]).to eq nil }
  end

  context 'with bad LCDewey' do
    let(:record) do
      base_record.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'BAD'),
          MARC::Subfield.new('w', 'LC'),
          MARC::Subfield.new('i', 'badLc'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    specify { expect(result[field]).to eq ['badLc'] }
  end

  context 'with bad LCDewey' do
    let(:record) do
      base_record.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', '1234.5 .D6'),
          MARC::Subfield.new('w', 'DEWEY'),
          MARC::Subfield.new('i', 'badDewey'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    specify { expect(result[field]).to eq ['badDewey'] }
  end
end
