# frozen_string_literal: true

RSpec.describe 'Call Numbers' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:fixture_name) { 'callNumberTests.jsonl' }
  # let(:records) { MARC::JSONLReader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { MARC::Record.new }
  let(:folio_record) { marc_to_folio(record) }

  subject(:result) { indexer.map_record(folio_record) }

  describe 'lc_assigned_callnum_ssim' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '15069nam a2200409 a 4500'
        r.append(MARC::ControlField.new('008', '091123s2014    si a    sb    101 0 eng d'))
        r.append(MARC::DataField.new('050', ' ', '0',
                                     MARC::Subfield.new('a', 'F1356'),
                                     MARC::Subfield.new('b', '.M464 2005')))
        r.append(MARC::DataField.new('090', ' ', '0',
                                     MARC::Subfield.new('a', 'F090'),
                                     MARC::Subfield.new('b', '.Z1')))
      end
    end

    it 'extracts data from the 050ab field' do
      expect(result['lc_assigned_callnum_ssim']).to include 'F1356 .M464 2005'
    end

    it 'extracts data from the 090ab field' do
      expect(result['lc_assigned_callnum_ssim']).to include 'F090 .Z1'
    end
  end

  describe 'callnum_search' do
    let(:field) { 'callnum_search' }
    subject { result[field] }
    before do
      allow(folio_record).to receive(:index_items).and_return(holdings)
    end
    let(:holdings) { [] }

    context 'for 690002' do
      let(:holdings) do
        [build(:dewey_holding, call_number: '159.32 .W211')]
      end

      it { is_expected.to eq ['159.32 .W211'] }
    end

    context 'when the call numbers are not unique (2328381)' do
      let(:holdings) do
        [
          build(:lc_holding, call_number: 'PR3724.T3', barcode: '36105003934432', permanent_location_code: 'STACKS', library: 'SAL'),
          build(:lc_holding, call_number: 'PR3724.T3', barcode: '36105003934424', permanent_location_code: 'STACKS', library: 'SAL'),
          build(:dewey_holding, call_number: '827.5 .S97TG', barcode: '36105048104132', permanent_location_code: 'STACKS', library: 'SAL3')
        ]
      end

      it { is_expected.to eq ['PR3724.T3', '827.5 .S97TG'] }
    end

    context 'when there are two call numbers with the same barcode (1849258)' do
      let(:holdings) do
        [
          build(:dewey_holding, call_number: '352.042 .C594 ED.2', barcode: '36105047516096', permanent_location_code: 'STACKS', library: 'SAL3'),
          build(:dewey_holding, call_number: '352.042 .C594 ED.3', barcode: '36105047516096', permanent_location_code: 'STACKS', library: 'SAL3')
        ]
      end

      it { is_expected.to eq ['352.042 .C594 ED.2', '352.042 .C594 ED.3'] }
    end

    context 'when there is a withdrawn record (2214009)' do
      let(:holdings) do
        [
          build(:dewey_holding, call_number: '370.1 .S655', barcode: '36105033336798', permanent_location_code: 'WITHDRAWN', library: 'EDUCATION'),
          build(:dewey_holding, call_number: '370.1 .S655', barcode: '36105033336780', permanent_location_code: 'STACKS', library: 'SAL3')
        ]
      end

      it { is_expected.to eq ['370.1 .S655'] }
    end

    context 'when call number is a dewey with one digit' do
      let(:holdings) do
        [build(:dewey_holding, call_number: '1 .N44')]
      end

      it { is_expected.to eq ['1 .N44'] }
    end

    context 'when call number is a dewey with two digits' do
      let(:holdings) do
        [build(:dewey_holding, call_number: '22 .N47')]
      end

      it { is_expected.to eq ['22 .N47'] }
    end

    context 'when call number is a dewey with three digits' do
      let(:holdings) do
        [build(:dewey_holding, call_number: '999 .F67')]
      end

      it { is_expected.to eq ['999 .F67'] }
    end

    context 'when call number is a dewey with one digit and decimal' do
      let(:holdings) do
        [build(:dewey_holding, call_number: '1.123 .N44')]
      end

      it { is_expected.to eq ['1.123 .N44'] }
    end

    context 'when call number is a dewey with two digits and decimal' do
      let(:holdings) do
        [build(:dewey_holding, call_number: '22.456 .S655')]
      end

      it { is_expected.to eq ['22.456 .S655'] }
    end

    context 'when call number is a dewey with three digits and decimal' do
      let(:holdings) do
        [build(:dewey_holding, call_number: '999.85 .P84')]
      end

      it { is_expected.to eq ['999.85 .P84'] }
    end

    context 'when call number is NO CALL NUMBER' do
      let(:holdings) do
        [build(:lc_holding, call_number: 'NO CALL NUMBER')]
      end

      it { is_expected.to be_nil }
    end
  end

  describe 'alphanum_callnum_search' do
    let(:field) { 'alphanum_callnum_search' }
    subject { result[field] }
    before do
      allow(folio_record).to receive(:index_items).and_return(holdings)
    end
    let(:holdings) { [] }

    context 'with an ALPHANUM' do
      let(:holdings) do
        [build(:alphanum_holding, call_number: 'ISHII SPRING  2009')]
      end

      it { is_expected.to eq ['ISHII SPRING 2009'] }
    end

    context 'with an ALPHANUM that is from SPEC' do
      let(:holdings) do
        [build(:alphanum_holding, call_number: 'SC1003A BOX 1', library: 'SPEC-COLL')]
      end

      it { is_expected.to be_nil }
    end

    context 'with an ALPHANUM that is an UNDOC' do
      let(:holdings) do
        [build(:undoc_holding)]
      end

      it { is_expected.to be_nil }
    end
  end

  describe 'spec_callnum_search' do
    let(:field) { 'spec_callnum_search' }
    subject { result[field] }
    before do
      allow(folio_record).to receive(:index_items).and_return(holdings)
    end
    let(:holdings) { [] }

    context 'with an ALPHANUM that is not from SPEC' do
      let(:holdings) do
        [build(:alphanum_holding, call_number: 'ISHII SPRING  2009')]
      end

      it { is_expected.to be_nil }
    end

    context 'with an ALPHANUM that is from SPEC' do
      let(:holdings) do
        [build(:alphanum_holding, call_number: 'SC1003A  BOX 1', library: 'SPEC-COLL')]
      end

      it { is_expected.to eq ['SC1003A BOX 1'] }
    end
  end

  describe 'sudoc_callnum_search' do
    let(:field) { 'sudoc_callnum_search' }
    subject { result[field] }
    before do
      allow(folio_record).to receive(:index_items).and_return(holdings)
    end
    let(:holdings) { [] }

    context 'with a SUDOC' do
      let(:holdings) do
        [build(:sudoc_holding, call_number: 'Y 4.SCI  2:107-46')]
      end

      it { is_expected.to eq ['Y 4.SCI 2:107-46'] }
    end

    context 'with a non-SUDOC' do
      let(:holdings) do
        [build(:alphanum_holding)]
      end

      it { is_expected.to be_nil }
    end
  end

  describe 'undoc_callnum_search' do
    let(:field) { 'undoc_callnum_search' }
    subject { result[field] }
    before do
      allow(folio_record).to receive(:index_items).and_return(holdings)
    end
    let(:holdings) { [] }

    context 'with a valid UNDOC' do
      let(:holdings) do
        [build(:undoc_holding, call_number: 'E/  ESCWA/ED/SER. Z/2/2005/2006-2007/2008')]
      end

      it { is_expected.to eq ['E/ ESCWA/ED/SER. Z/2/2005/2006-2007/2008'] }
    end

    context 'with an ALPHANUM callnumber that is not a valid UNDOC' do
      let(:holdings) do
        [build(:alphanum_holding)]
      end

      it { is_expected.to be_nil }
    end
  end
end
