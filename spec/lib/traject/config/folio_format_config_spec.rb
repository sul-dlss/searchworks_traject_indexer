# frozen_string_literal: true

RSpec.describe 'format_hsim config' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:instance) { {} }
  subject(:result) { indexer.map_record(folio_record) }
  let(:folio_record) { marc_to_folio(record, instance:) }
  let(:field) { 'format_hsim' }

  before do
    allow(folio_record).to receive(:index_items).and_return(holdings)
    allow(folio_record).to receive(:holdings).and_return(holdings)
  end

  let(:holdings) { [] }

  describe 'format_hsim' do
    context 'when record is a Manuscript' do
      context 'when leader[6] = p' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.leader = 'p1952cpm  2200457Ia 4500'
          end
        end

        it 'maps to Archive/Manuscript' do
          expect(result[field]).to eq ['Archive/Manuscript']
        end
      end

      context 'when leader[6] = a and leader[7] = c' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.leader = 'p1952cac  2200457Ia 4500'
          end
        end

        it 'maps to Archive/Manuscript' do
          expect(result[field]).to eq ['Archive/Manuscript']
        end
      end

      context '245h contains manuscripts' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.leader = '01952c d  2200457Ia 4500'
            # We expect [manuscript] to be in brackets in the string
            r.append(MARC::DataField.new('245', '1', ' ',
                                         MARC::Subfield.new('a', 'manuscript: 245h'),
                                         MARC::Subfield.new('h', '[manuscript]')))
          end
        end

        it 'maps to Archive/Manuscript' do
          expect(result[field]).to eq ['Archive/Manuscript']
        end
      end
    end

    context 'when record is a Book' do
      context 'when leader[6] = a and leader[7] = m' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.leader = 'p1952cam  2200457Ia 4500'
          end
        end

        it 'maps to Book' do
          expect(result[field]).to eq ['Book']
        end
      end

      context 'when leader[7] = s and 008[21] = m' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.leader = 'p1952cas  2200457Ia 4500'
            r.append(MARC::ControlField.new('008', '000000000000000000000m000000000000000000'))
          end
        end

        it 'maps to Book' do
          expect(result[field]).to eq ['Book']
        end
      end

      context 'when 006[0] = s and 006[4] = m' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(MARC::ControlField.new('006', 's000m00000000000000'))
          end
        end

        it 'maps to Book' do
          expect(result[field]).to eq ['Book']
        end
      end
    end
    context 'when record is a Database' do
      context 'when leader[7] = s and 008[21] = d' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.leader = '0000000s0000000000000000'
            r.append(MARC::ControlField.new('008', '000000000000000000000d000000000000000000'))
          end
        end

        it 'maps to Database' do
          expect(result[field]).to eq ['Database']
        end
      end

      context 'when 006[0] = s and 006[4] = d' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(MARC::ControlField.new('006', 's000d00000000000000'))
          end
        end

        it 'maps to Database' do
          expect(result[field]).to eq ['Database']
        end
      end

      context 'when leader[6] = m and 008[26] = j' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.leader = '000000m00000000000000000'
            r.append(MARC::ControlField.new('008', '00000000000000000000000000j00000000000'))
          end
        end

        it 'maps to Database' do
          expect(result[field]).to eq ['Database']
        end
      end
    end

    context 'when record is a Dataset' do
      context 'when leader[6] = m and 008[26] = a' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.leader = '000000m00000000000000000'
            r.append(MARC::ControlField.new('008', '00000000000000000000000000a00000000000'))
          end
        end

        it 'maps to Dataset' do
          expect(result[field]).to eq ['Dataset']
        end
      end
    end

    # TODO: add Equipment test. Need to stub FOLIO record/holdings.
    # context 'when record is Equipment' do
    # end

    context 'when record is an Image' do
      context 'when leader[6] = k and 008[33] matches [aciklnopst 0-9|]' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.leader = '000000k00000000000000000'
            r.append(MARC::ControlField.new('008', '000000000000000000000000000000000a0000'))
          end
        end

        it 'maps to Image' do
          expect(result[field]).to eq ['Image']
        end
      end

      context 'when leader[6] = g and 008[33] matches [ aciklnopst]' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.leader = '000000g00000000000000000'
            r.append(MARC::ControlField.new('008', '000000000000000000000000000000000k0000'))
          end
        end

        it 'maps to Image' do
          expect(result[field]).to eq ['Image']
        end
      end

      context 'when record is an Image based on 245h terms' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.leader = '000000a00000000000000000'
            r.append(MARC::DataField.new('245', '1', ' ',
                                         MARC::Subfield.new('a', 'Example title'),
                                         MARC::Subfield.new('h', 'technical drawing')))
          end
        end

        it 'maps to Image' do
          expect(result[field]).to eq ['Image']
        end
      end

      context 'when record is an Image based on 007 and 245h = kit' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.leader = '000000a00000000000000000'
            r.append(MARC::ControlField.new('007', 'k0000000000'))
            r.append(MARC::DataField.new('245', '1', ' ',
                                         MARC::Subfield.new('a', 'Example kit title'),
                                         MARC::Subfield.new('h', 'kit')))
          end
        end

        it 'maps to Image' do
          expect(result[field]).to eq ['Image']
        end
      end

      context 'when record is an Image|Photo' do
        context 'when 007[0] = k and 007[1] in [g, h, r, v]' do
          let(:record) do
            MARC::Record.new.tap do |r|
              r.leader = '000000a00000000000000000'
              r.append(MARC::ControlField.new('007', 'kg0000000000'))
            end
          end

          it 'maps to Image|Photo' do
            expect(result[field]).to eq ['Image', 'Image|Photo']
          end
        end
      end

      context 'when record is an Image|Poster' do
        context 'when 007[0] = k and 007[1] = k' do
          let(:record) do
            MARC::Record.new.tap do |r|
              r.leader = '000000a00000000000000000'
              r.append(MARC::ControlField.new('007', 'kk0000000000'))
            end
          end

          it 'maps to Image|Poster' do
            expect(result[field]).to eq ['Image', 'Image|Poster']
          end
        end
      end

      context 'when record is an Image|Slide' do
        context 'when 007[0] = g and 007[1] = s' do
          let(:record) do
            MARC::Record.new.tap do |r|
              r.leader = '000000a00000000000000000'
              r.append(MARC::ControlField.new('007', 'gs0000000000'))
            end
          end

          it 'maps to Image|Slide' do
            expect(result[field]).to eq ['Image', 'Image|Slide']
          end
        end
      end
    end
  end
end
