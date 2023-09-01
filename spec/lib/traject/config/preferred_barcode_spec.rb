# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'All_search config' do
  subject { result[field] }
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end
  let(:folio_record) do
    marc_to_folio(
      MARC::Record.new.tap do |r|
        r.leader = '01952cas  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 0 eng d'))
      end
    )
  end
  let(:result) { indexer.map_record(folio_record) }
  let(:field) { 'preferred_barcode' }

  describe 'preferred_barcode' do
    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(sirsi_holdings)
    end

    context 'with lc only' do
      let(:sirsi_holdings) do
        [
          build(:lc_holding, barcode: 'LCbarcode')
        ]
      end

      it { is_expected.to eq ['LCbarcode'] }
    end

    context 'with lc + dewey' do
      let(:sirsi_holdings) do
        [
          build(:lc_holding, barcode: 'LCbarcode'),
          build(:dewey_holding, barcode: 'DeweyBarcode')
        ]
      end

      it { is_expected.to eq ['LCbarcode'] }
    end

    context 'with lc + dewey + sudoc' do
      let(:sirsi_holdings) do
        [
          build(:lc_holding, barcode: 'LCbarcode'),
          build(:dewey_holding, barcode: 'DeweyBarcode'),
          build(:sudoc_holding, barcode: 'SudocBarcode')
        ]
      end

      it { is_expected.to eq ['LCbarcode'] }
    end

    context 'with lc + dewey + sudoc + alphanum' do
      let(:sirsi_holdings) do
        [
          build(:lc_holding, barcode: 'LCbarcode'),
          build(:dewey_holding, barcode: 'DeweyBarcode'),
          build(:sudoc_holding, barcode: 'SudocBarcode'),
          build(:alphanum_holding, barcode: 'AlphanumBarcode')
        ]
      end

      it { is_expected.to eq ['LCbarcode'] }
    end

    context 'with dewey + sudoc + alphanum' do
      let(:sirsi_holdings) do
        [
          build(:dewey_holding, barcode: 'DeweyBarcode'),
          build(:sudoc_holding, barcode: 'SudocBarcode'),
          build(:alphanum_holding, barcode: 'AlphanumBarcode')
        ]
      end

      it { is_expected.to eq ['DeweyBarcode'] }
    end

    context 'with sudoc + alphanum' do
      let(:sirsi_holdings) do
        [
          build(:sudoc_holding, barcode: 'SudocBarcode'),
          build(:alphanum_holding, barcode: 'AlphanumBarcode')
        ]
      end

      it { is_expected.to eq ['SudocBarcode'] }
    end

    context 'with alphanum' do
      let(:sirsi_holdings) do
        [
          build(:alphanum_holding, barcode: 'AlphanumBarcode')
        ]
      end

      it { is_expected.to eq ['AlphanumBarcode'] }
    end

    context 'with dewey + alphanum' do
      let(:sirsi_holdings) do
        [
          build(:dewey_holding, barcode: 'DeweyBarcode'),
          build(:alphanum_holding, barcode: 'AlphanumBarcode')
        ]
      end

      it { is_expected.to eq ['DeweyBarcode'] }
    end

    context 'with lc + alphanum' do
      let(:sirsi_holdings) do
        [
          build(:lc_holding, barcode: 'LCbarcode'),
          build(:alphanum_holding, barcode: 'AlphanumBarcode')
        ]
      end

      it { is_expected.to eq ['LCbarcode'] }
    end
  end

  context 'with lc untruncated + dewey truncated' do
    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(
        [
          build(:lc_holding, barcode: 'LCbarcode', call_number: 'QE538.8 .N36 1975-1977'),
          build(:dewey_holding, barcode: 'Dewey1', call_number: '888.4 .J788 V.5'),
          build(:dewey_holding, barcode: 'Dewey2', call_number: '888.4 .J788 V.6')
        ]
      )
    end

    it { is_expected.to eq ['LCbarcode'] }
  end

  context 'with lc untruncated + dewey truncated + sudoc truncated' do
    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(
        [
          build(:lc_holding, barcode: 'LCbarcode', call_number: 'QE538.8 .N36 1975-1977'),
          build(:dewey_holding, barcode: 'Dewey1', call_number: '888.4 .J788 V.5'),
          build(:dewey_holding, barcode: 'Dewey2', call_number: '888.4 .J788 V.6'),
          build(:sudoc_holding, barcode: 'Sudoc1', call_number: 'Y 4.G 74/7-11:110"'),
          build(:sudoc_holding, barcode: 'Sudoc2', call_number: 'Y 4.G 74/7-11:1101')
        ]
      )
    end

    it { is_expected.to eq ['LCbarcode'] }
  end

  context 'with lc untruncated + dewey truncated + sudoc truncated + alphanum truncated' do
    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(
        [
          build(:lc_holding, barcode: 'LCbarcode', call_number: 'QE538.8 .N36 1975-1977'),
          build(:dewey_holding, barcode: 'Dewey1', call_number: '888.4 .J788 V.5'),
          build(:dewey_holding, barcode: 'Dewey2', call_number: '888.4 .J788 V.6'),
          build(:sudoc_holding, barcode: 'Sudoc1', call_number: 'Y 4.G 74/7-11:110"'),
          build(:sudoc_holding, barcode: 'Sudoc2', call_number: 'Y 4.G 74/7-11:1101'),
          build(:alphanum_holding, barcode: 'Alpha1', call_number: 'ZDVD 19791 DISC 1'),
          build(:alphanum_holding, barcode: 'Alpha2', call_number: 'ZDVD 19791 DISC 2')
        ]
      )
    end
    it { is_expected.to eq ['LCbarcode'] }
  end

  context 'with dewey untruncated + sudoc truncated + alphanum truncated' do
    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(
        [
          build(:dewey_holding, barcode: 'Dewey1', call_number: '888.4 .J788 V.5'),
          build(:sudoc_holding, barcode: 'Sudoc1', call_number: 'Y 4.G 74/7-11:110"'),
          build(:sudoc_holding, barcode: 'Sudoc2', call_number: 'Y 4.G 74/7-11:1101'),
          build(:alphanum_holding, barcode: 'Alpha1', call_number: 'ZDVD 19791 DISC 1'),
          build(:alphanum_holding, barcode: 'Alpha2', call_number: 'ZDVD 19791 DISC 2')
        ]
      )
    end

    it { is_expected.to eq ['Dewey1'] }
  end

  context 'with sudoc untruncated + alphanum truncated' do
    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(
        [
          build(:sudoc_holding, barcode: 'Sudoc1', call_number: 'Y 4.G 74/7-11:110"'),
          build(:alphanum_holding, barcode: 'Alpha1', call_number: 'ZDVD 19791 DISC 1'),
          build(:alphanum_holding, barcode: 'Alpha2', call_number: 'ZDVD 19791 DISC 2')
        ]
      )
    end

    it { is_expected.to eq ['Sudoc1'] }
  end

  context 'with dewey untruncated + alphanum truncated' do
    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(
        [
          build(:dewey_holding, barcode: 'Dewey1', call_number: '888.4 .J788 V.5'),
          build(:alphanum_holding, barcode: 'Alpha1', call_number: 'ZDVD 19791 DISC 1'),
          build(:alphanum_holding, barcode: 'Alpha2', call_number: 'ZDVD 19791 DISC 2')
        ]
      )
    end
    it { is_expected.to eq ['Dewey1'] }
  end

  describe 'prefers the shorted non-truncated callnumber' do
    context 'with lc only' do
      before do
        allow(folio_record).to receive(:sirsi_holdings).and_return(
          [
            build(:lc_holding, barcode: '666', call_number: 'QE538.8 .N36 1975-1977'),
            build(:lc_holding, barcode: '777', call_number: 'D764.7 .K72 1990')
          ]
        )
      end

      it { is_expected.to eq ['777'] }
    end

    context 'with dewey' do
      before do
        allow(folio_record).to receive(:sirsi_holdings).and_return(
          [
            build(:dewey_holding, barcode: 'Dewey1', call_number: '888.4 .J788 V.5'),
            build(:dewey_holding, barcode: 'Dewey2', call_number: '505 .N285B V.241-245 1973', home_location: 'LOCATION')
          ]
        )
      end
      it { is_expected.to eq ['Dewey1'] }
    end

    context 'with sudoc' do
      before do
        allow(folio_record).to receive(:sirsi_holdings).and_return(
          [
            build(:sudoc_holding, barcode: 'Sudoc1', call_number: 'Y 4.G 74/7-11:110"'),
            build(:sudoc_holding, barcode: 'Sudoc2', call_number: 'A 13.78:NC-315', home_location: 'LOCATION')
          ]
        )
      end
      it { is_expected.to eq ['Sudoc2'] }
    end

    context 'with alphanum' do
      before do
        allow(folio_record).to receive(:sirsi_holdings).and_return(
          [
            build(:alphanum_holding, barcode: 'Alpha1', call_number: 'ZDVD 19791 DISC 1'),
            build(:alphanum_holding, barcode: 'Alpha2', call_number: 'ZDVD 19791 DISC 2', home_location: 'LOCATION')
          ]
        )
      end
      it { is_expected.to eq ['Alpha1'] }
    end
  end

  describe 'picking the shortest truncated callnumber when the number of items is the same' do
    context 'with lc only' do
      before do
        allow(folio_record).to receive(:sirsi_holdings).and_return(
          [
            build(:lc_holding, barcode: 'lc1', call_number: 'QE538.8 .N36 1975-1977'),
            build(:lc_holding, barcode: 'lc2', call_number: 'QE538.8 .N36 1978-1980'),
            build(:lc_holding, barcode: 'lc3', call_number: 'E184.S75 R47A V.1 1980'),
            build(:lc_holding, barcode: 'lc4', call_number: 'E184.S75 R47A V.2 1980')
          ]
        )
      end
      specify do
        pending 'Waiting for some decision about how items should be sorted within a lopped call number set'
        expect(result[field]).to eq ['lc1']
      end
    end

    context 'with dewey only' do
      before do
        allow(folio_record).to receive(:sirsi_holdings).and_return(
          [
            build(:dewey_holding, barcode: 'dewey1', call_number: '888.4 .J788 V.5'),
            build(:dewey_holding, barcode: 'dewey2', call_number: '888.4 .J788 V.6'),
            build(:dewey_holding, barcode: 'dewey3', call_number: '505 .N285B V.241-245 1973'),
            build(:dewey_holding, barcode: 'dewey4', call_number: '505 .N285B V.241-245 1975')
          ]
        )
      end
      it { is_expected.to eq ['dewey4'] }
    end

    context 'with sudoc only' do
      before do
        allow(folio_record).to receive(:sirsi_holdings).and_return(
          [
            build(:sudoc_holding, barcode: 'sudoc1', call_number: 'Y 4.G 74/7-11:110'),
            build(:sudoc_holding, barcode: 'sudoc2', call_number: 'Y 4.G 74/7-11:222'),
            build(:sudoc_holding, barcode: 'sudoc3', call_number: 'A 13.78:NC-315', home_location: 'SOMEWHERE'),
            build(:sudoc_holding, barcode: 'sudoc4', call_number: 'A 13.78:NC-315 1947', home_location: 'SOMEWHERE')
          ]
        )
      end

      it { is_expected.to eq ['sudoc1'] }
    end

    context 'with alphanum only' do
      before do
        allow(folio_record).to receive(:sirsi_holdings).and_return(
          [
            build(:alphanum_holding, barcode: 'alpha1', call_number: 'ZDVD 19791 DISC 1'),
            build(:alphanum_holding, barcode: 'alpha2', call_number: 'ZDVD 19791 DISC 2'),
            build(:alphanum_holding, barcode: 'alpha3', call_number: 'ARTDVD 666666 DISC 1'),
            build(:alphanum_holding, barcode: 'alpha4', call_number: 'ARTDVD 666666 DISC 2')
          ]
        )
      end
      specify do
        expect(result[field]).to eq ['alpha1']
      end
    end
  end

  describe 'prefer more items over a shorter key' do
    context 'with lc only' do
      before do
        allow(folio_record).to receive(:sirsi_holdings).and_return(
          [
            build(:lc_holding, barcode: 'lc1', call_number: 'QE538.8 .N36 1975-1977'),
            build(:lc_holding, barcode: 'lc2', call_number: 'QE538.8 .N36 1978-1980'),
            build(:lc_holding, barcode: 'lc3', call_number: 'E184.S75 R47A V.1 1980'),
            build(:lc_holding, barcode: 'lc4', call_number: 'E184.S75 R47A V.2 1980'),
            build(:lc_holding, barcode: 'lc5', call_number: 'E184.S75 R47A V.3')
          ]
        )
      end
      it { is_expected.to eq ['lc5'] }
    end

    context 'with dewey only' do
      before do
        allow(folio_record).to receive(:sirsi_holdings).and_return(
          [
            build(:dewey_holding, barcode: 'dewey1', call_number: '888.4 .J788 V.5'),
            build(:dewey_holding, barcode: 'dewey2', call_number: '888.4 .J788 V.6'),
            build(:dewey_holding, barcode: 'dewey3', call_number: '505 .N285B V.241-245 1973'),
            build(:dewey_holding, barcode: 'dewey4', call_number: '505 .N285B V.241-245 1975'),
            build(:dewey_holding, barcode: 'dewey5', call_number: '505 .N285B V.283-285')
          ]
        )
      end
      it { is_expected.to eq ['dewey5'] }
    end

    context 'with sudoc only' do
      before do
        allow(folio_record).to receive(:sirsi_holdings).and_return(
          [
            build(:sudoc_holding, barcode: 'sudoc1', call_number: 'Y 4.G 74/7-11:110"'),
            build(:sudoc_holding, barcode: 'sudoc2', call_number: 'Y 4.G 74/7-11:222'),
            build(:sudoc_holding, barcode: 'sudoc3', call_number: 'A 13.78:NC-315', home_location: 'SOMEWHERE'),
            build(:sudoc_holding, barcode: 'sudoc4', call_number: 'A 13.78:NC-315 1947', home_location: 'SOMEWHERE'),
            build(:sudoc_holding, barcode: 'sudoc5', call_number: 'A 13.78:NC-315 1956', home_location: 'SOMEWHERE')
          ]
        )
      end
      it { is_expected.to eq ['sudoc3'] }
    end

    context 'with alphanum only' do
      before do
        allow(folio_record).to receive(:sirsi_holdings).and_return(
          [
            build(:alphanum_holding, barcode: 'alpha1', call_number: 'ZDVD 19791 DISC 1'),
            build(:alphanum_holding, barcode: 'alpha2', call_number: 'ZDVD 19791 DISC 2'),
            build(:alphanum_holding, barcode: 'alpha3', call_number: 'ARTDVD 666666 DISC 1', home_location: 'SOMEWHERE'),
            build(:alphanum_holding, barcode: 'alpha4', call_number: 'ARTDVD 666666 DISC 2', home_location: 'SOMEWHERE'),
            build(:alphanum_holding, barcode: 'alpha5', call_number: 'ARTDVD 666666 DISC 3', home_location: 'SOMEWHERE')

          ]
        )
      end
      it { is_expected.to eq ['alpha3'] }
    end
  end

  describe 'with non-Green locations' do
    context 'with lc only' do
      before do
        allow(folio_record).to receive(:sirsi_holdings).and_return(
          [
            build(:alphanum_holding, barcode: 'alpha1', call_number: 'ZDVD 19791 DISC 1'),
            build(:lc_holding, barcode: 'ArsLC1', call_number: 'QE538.8 .N36 V.7', library: 'ARS')
          ]
        )
      end

      it { is_expected.to eq ['alpha1'] }
    end

    context 'libraries prioritized in alpha order by code' do
      before do
        allow(folio_record).to receive(:sirsi_holdings).and_return(
          [
            build(:lc_holding, barcode: 'ArtBarcode', call_number: 'M57 .N4', library: 'ART'),
            build(:lc_holding, barcode: 'EngBarcode', call_number: 'M57 .N42', library: 'ENG')
          ]
        )
      end
      it { is_expected.to eq ['ArtBarcode'] }
    end
  end

  context 'with an online item' do
    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(
        [
          build(:lc_holding, barcode: 'onlineByCallnum', call_number: 'INTERNET RESOURCE')
        ]
      )
    end
    it { is_expected.to eq nil }
  end

  context 'with an online item with a bib callnumber' do
    let(:folio_record) do
      marc_to_folio(
        MARC::Record.new.tap do |r|
          r.leader = '01952cas  2200457Ia 4500'
          r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 0 eng d'))
          r.append(MARC::DataField.new('050', ' ', ' ',
                                       MARC::Subfield.new('a', 'AB123'),
                                       MARC::Subfield.new('b', 'C45')))
        end
      )
    end

    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(
        [
          build(:lc_holding, barcode: 'onlineByCallnum', call_number: 'INTERNET RESOURCE')
        ]
      )
    end

    it { is_expected.to eq ['onlineByCallnum'] }
  end

  context 'with an item with an INTERNET location' do
    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(
        [
          build(:lc_holding, barcode: 'onlineByLoc', call_number: 'AB123 .C45', home_location: 'INTERNET')
        ]
      )
    end
    it { is_expected.to eq ['onlineByLoc'] }
  end

  context 'with an item with an online item with callnum matches another group' do
    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(
        [
          build(:lc_holding, barcode: 'onlineByLoc', call_number: 'AB123 .C45', home_location: 'INTERNET'),
          build(:lc_holding, barcode: 'notOnline', call_number: 'AB123 .C45')
        ]
      )
    end
    it { is_expected.to eq ['notOnline'] }
  end

  context 'with an ignored call number' do
    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(
        [
          build(:holding, scheme: 'OTHER', barcode: 'noCallNum', call_number: 'NO CALL NUMBER')
        ]
      )
    end
    it { is_expected.to eq nil }
  end

  context 'with a shelby location' do
    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(
        [
          build(:lc_holding, barcode: 'shelby', call_number: 'M1503 .A5 VOL.22', current_location: 'SHELBYTITL')
        ]
      )
    end

    it { is_expected.to eq ['shelby'] }
  end

  context 'with a missing location' do
    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(
        [
          build(:lc_holding, barcode: 'missing', call_number: 'AB123 C45', home_location: 'MISSING')
        ]
      )
    end

    it { is_expected.to eq ['missing'] }
  end

  context 'with a lost location' do
    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(
        [
          build(:lc_holding, barcode: 'lost', call_number: 'AB123 C45', home_location: 'LOST-PAID')
        ]
      )
    end

    it { is_expected.to eq ['lost'] }
  end

  context 'with no items' do
    it { is_expected.to eq nil }
  end

  context 'with ignored callnums with no browsable callnum' do
    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(
        [
          build(:holding, scheme: 'OTHER', barcode: 'nocallnum', call_number: 'NO CALL NUMBER')
        ]
      )
    end

    it { is_expected.to eq nil }
  end

  context 'with a bad lane lc callnum' do
    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(
        [
          build(:lc_holding, barcode: 'lane', call_number: 'XX13413', library: 'LANE-MED', home_location: 'ASK@LANE')
        ]
      )
    end

    it { is_expected.to eq nil }
  end

  context 'with bad LCDewey' do
    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(
        [
          build(:lc_holding, barcode: 'badLc', call_number: 'BAD')
        ]
      )
    end

    it { is_expected.to eq ['badLc'] }
  end

  context 'with bad LCDewey' do
    before do
      allow(folio_record).to receive(:sirsi_holdings).and_return(
        [
          build(:dewey_holding, barcode: 'badDewey', call_number: '1234.5 .D6')
        ]
      )
    end

    it { is_expected.to eq ['badDewey'] }
  end
end
