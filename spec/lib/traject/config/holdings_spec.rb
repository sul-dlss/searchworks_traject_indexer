RSpec.describe 'Holdings config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end

  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }
  let(:fixture_name) { '44794.marc' }
  subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }

  describe 'on_order_library_ssim' do
    let(:field) { 'on_order_library_ssim' }

    it do
      expect(select_by_id('44794')[field]).to eq ['SAL3']
    end
  end
  describe 'mhld_display' do
    let(:field) { 'mhld_display' }
    let(:fixture_name) { '2499.marc' }

    it do
      expect(select_by_id('2499')[field]).to eq [
        'MUSIC -|- STACKS -|-  -|- v.1 -|- ',
        'MUSIC -|- STACKS -|-  -|- v.2 -|- '
      ]
    end
    context do
      let(:fixture_name) { '9012.marc' }
      it do
        expect(select_by_id('9012')[field]).to eq [
          'SAL3 -|- STACKS -|-  -|- 1948,1965-1967,1974-1975 -|- '
        ]
      end
    end
    context do
      let(:fixture_name) { '1572.marc' }
      it do
        expect(select_by_id('1572')[field]).to eq [
          'SAL3 -|- STACKS -|-  -|- Heft 1-2 <v.568-569 in series> -|- '
        ]
      end
    end
    describe '863 has unit after year' do
      # from http://searchworks.stanford.edu/view/474135
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::ControlField.new('001', 'aunitAfterYear'))
          r.append(MARC::DataField.new('852', ' ', ' ',
            MARC::Subfield.new('a', 'CSt'),
            MARC::Subfield.new('b', 'MATH-CS'),
            MARC::Subfield.new('c', 'SHELBYTITL'),
            MARC::Subfield.new('=', '8287')
          ))
          r.append(MARC::DataField.new('853', '2', ' ',
            MARC::Subfield.new('8', '2'),
            MARC::Subfield.new('a', 'v.'),
            MARC::Subfield.new('b', 'no.'),
            MARC::Subfield.new('u', '4'),
            MARC::Subfield.new('v', 'r'),
            MARC::Subfield.new('i', '(year)'),
            MARC::Subfield.new('j', '(unit)')
          ))
          r.append(MARC::DataField.new('863', ' ', '1',
            MARC::Subfield.new('8', '2.57'),
            MARC::Subfield.new('a', '54'),
            MARC::Subfield.new('b', '1'),
            MARC::Subfield.new('i', '2013'),
            MARC::Subfield.new('j', '1_TRIMESTRE')
          ))
          r.append(MARC::DataField.new('866', '3', '1',
            MARC::Subfield.new('8', '1'),
            MARC::Subfield.new('a', 'v.25(1984)-')
          ))
        end
      end
      it do
        expect(result[field]).to eq ['MATH-CS -|- SHELBYTITL -|-  -|- v.25(1984)- -|- v.54:no.1 (2013:1_TRIMESTRE)']
      end
    end
    describe 'latest received' do
      # from http://searchworks.stanford.edu/view/474135
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::ControlField.new('001', 'alatestRecdPatterns'))
          r.append(MARC::DataField.new('852', ' ', ' ',
            MARC::Subfield.new('a', 'CSt'),
            MARC::Subfield.new('b', 'lib'),
            MARC::Subfield.new('c', 'loc'),
            MARC::Subfield.new('=', 'output latest received')
          ))
          r.append(MARC::DataField.new('853', '2', ' ',
            MARC::Subfield.new('8', '3'),
            MARC::Subfield.new('a', 'v.'),
            MARC::Subfield.new('b', 'pt.'),
            MARC::Subfield.new('u', '3'),
            MARC::Subfield.new('v', 'r'),
            MARC::Subfield.new('c', 'no.'),
            MARC::Subfield.new('v', 'c'),
            MARC::Subfield.new('i', '(year)'),
            MARC::Subfield.new('j', '(season)')
          ))
          r.append(MARC::DataField.new('863', ' ', '1',
            MARC::Subfield.new('8', '3.36'),
            MARC::Subfield.new('a', '106'),
            MARC::Subfield.new('b', '3'),
            MARC::Subfield.new('c', '482'),
            MARC::Subfield.new('i', '2010'),
            MARC::Subfield.new('j', 'WIN')
          ))
        end
      end
      it do
        expect(result[field]).to eq ['lib -|- loc -|-  -|-  -|- v.106:pt.3:no.482 (2010:WIN)']
      end
      context do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(MARC::ControlField.new('001', 'alatestRecdPatterns'))
            r.append(MARC::DataField.new('852', ' ', ' ',
              MARC::Subfield.new('a', 'CSt'),
              MARC::Subfield.new('b', 'lib'),
              MARC::Subfield.new('c', 'loc'),
              MARC::Subfield.new('=', 'output latest received')
            ))
            r.append(MARC::DataField.new('853', '2', ' ',
              MARC::Subfield.new('8', '1'),
              MARC::Subfield.new('a', 'v.'),
              MARC::Subfield.new('i', '(year)')
            ))
            r.append(MARC::DataField.new('863', ' ', '1',
              MARC::Subfield.new('8', '1.11'),
              MARC::Subfield.new('a', '105'),
              MARC::Subfield.new('i', '2009'),
            ))
          end
        end
        it do
          expect(result[field]).to eq ['lib -|- loc -|-  -|-  -|- v.105 (2009)']
        end
      end
      context do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(MARC::ControlField.new('001', 'alatestRecdPatterns'))
            r.append(MARC::DataField.new('852', ' ', ' ',
              MARC::Subfield.new('a', 'CSt'),
              MARC::Subfield.new('b', 'lib'),
              MARC::Subfield.new('c', 'loc'),
              MARC::Subfield.new('=', 'output latest received')
            ))
            r.append(MARC::DataField.new('853', '2', ' ',
              MARC::Subfield.new('8', '1'),
              MARC::Subfield.new('a', 'v.'),
              MARC::Subfield.new('b', 'no.'),
              MARC::Subfield.new('u', '52'),
              MARC::Subfield.new('v', 'r'),
              MARC::Subfield.new('i', '(year)'),
              MARC::Subfield.new('j', '(month)'),
              MARC::Subfield.new('k', '(day)')
            ))
            r.append(MARC::DataField.new('863', ' ', '1',
              MARC::Subfield.new('8', '1.569'),
              MARC::Subfield.new('a', '205'),
              MARC::Subfield.new('b', '10'),
              MARC::Subfield.new('i', '2011'),
              MARC::Subfield.new('j', '03'),
              MARC::Subfield.new('k', '9')
            ))
          end
        end
        it do
          expect(result[field]).to eq ['lib -|- loc -|-  -|-  -|- v.205:no.10 (2011:March 9)']
        end
      end
    end
    describe 'library has includes sub z and sub a from 866/867/868' do
      # https://jirasul.stanford.edu/jira/browse/SW-885
      context '866subz' do
        let(:record) do
          # from http://searchworks.stanford.edu/view/48690
          MARC::Record.new.tap do |r|
            r.append(MARC::ControlField.new('001', 'asubz866'))
            r.append(MARC::DataField.new('852', ' ', ' ',
              MARC::Subfield.new('a', 'CSt'),
              MARC::Subfield.new('b', 'lib'),
              MARC::Subfield.new('c', 'loc')
            ))
            r.append(MARC::DataField.new('866', ' ', '0',
              MARC::Subfield.new('8', '1'),
              MARC::Subfield.new('a', 'pt.1-4'),
              MARC::Subfield.new('z', '<v.3,16,27-28 in series>')
            ))
            r.append(MARC::DataField.new('866', '8', '1',
              MARC::Subfield.new('8', '1'),
              MARC::Subfield.new('a', 'pt.2'),
              MARC::Subfield.new('z', '<v.16 in series>')
            ))
            r.append(MARC::DataField.new('866', '8', '1',
              MARC::Subfield.new('8', '1'),
              MARC::Subfield.new('a', 'pt.5'),
            ))
          end
        end
        it do
          expect(result[field][0]).to eq 'lib -|- loc -|-  -|- pt.1-4 <v.3,16,27-28 in series> -|- '
          expect(result[field][1]).to eq 'lib -|- loc -|-  -|- pt.2 <v.16 in series> -|- '
          expect(result[field][2]).to eq 'lib -|- loc -|-  -|- pt.5 -|- '
        end
      end
      context '867subz' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(MARC::ControlField.new('001', 'asubz867'))
            r.append(MARC::DataField.new('852', ' ', ' ',
              MARC::Subfield.new('a', 'CSt'),
              MARC::Subfield.new('b', 'lib'),
              MARC::Subfield.new('c', 'loc')
            ))
            r.append(MARC::DataField.new('867', ' ', '0',
              MARC::Subfield.new('8', '1'),
              MARC::Subfield.new('a', 'first'),
              MARC::Subfield.new('z', 'subz')
            ))
            r.append(MARC::DataField.new('867', ' ', '0',
              MARC::Subfield.new('8', '1'),
              MARC::Subfield.new('a', 'second')
            ))
            r.append(MARC::DataField.new('866', '3', '1', 
              MARC::Subfield.new('8', '0'),
              MARC::Subfield.new('a', 'v.188')
            ))
          end
        end
        it do
          expect(result[field].length).to eq 3
          expect(result[field][0]).to eq 'lib -|- loc -|-  -|- v.188 -|- '
          expect(result[field][1]).to eq 'lib -|- loc -|-  -|- Supplement: first subz -|- '
          expect(result[field][2]).to eq 'lib -|- loc -|-  -|- Supplement: second -|- '
        end
      end
      context '868subz' do
        let(:record) do
          MARC::Record.new.tap do |r|
            r.append(MARC::ControlField.new('001', 'asubz868'))
            r.append(MARC::DataField.new('852', ' ', ' ',
              MARC::Subfield.new('a', 'CSt'),
              MARC::Subfield.new('b', 'lib'),
              MARC::Subfield.new('c', 'loc')
            ))
            r.append(MARC::DataField.new('868', ' ', '0',
              MARC::Subfield.new('8', '1'),
              MARC::Subfield.new('a', 'first'),
              MARC::Subfield.new('z', 'subz')
            ))
            r.append(MARC::DataField.new('868', ' ', '0',
              MARC::Subfield.new('8', '1'),
              MARC::Subfield.new('a', 'second')
            ))
            r.append(MARC::DataField.new('866', '3', '1', 
              MARC::Subfield.new('8', '0'),
              MARC::Subfield.new('a', 'v.188')
            ))
          end
        end
        it do
          expect(result[field].length).to eq 3
          expect(result[field][0]).to eq 'lib -|- loc -|-  -|- v.188 -|- '
          expect(result[field][1]).to eq 'lib -|- loc -|-  -|- Index: first subz -|- '
          expect(result[field][2]).to eq 'lib -|- loc -|-  -|- Index: second -|- '
        end
      end
    end
    describe '"latest" should be populated but only when 853 matches latest recd 863' do
      # https://jirasul.stanford.edu/jira/browse/VUF-2617
      # from http://searchworks.stanford.edu/view/3454845
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::ControlField.new('001', 'alatest'))
          r.append(MARC::DataField.new('852', ' ', ' ',
            MARC::Subfield.new('a', 'CSt'),
            MARC::Subfield.new('b', 'lib'),
            MARC::Subfield.new('c', 'loc'),
            MARC::Subfield.new('=', '41906')
          ))
          r.append(MARC::DataField.new('853', '2', ' ',
            MARC::Subfield.new('8', '2'),
            MARC::Subfield.new('a', '(year)')
          ))
          r.append(MARC::DataField.new('853', '2', ' ',
            MARC::Subfield.new('8', '3'),
            MARC::Subfield.new('a', '(year)'),
            MARC::Subfield.new('b', 'pt.'),
            MARC::Subfield.new('u', '2'),
            MARC::Subfield.new('v', 'r'),
          ))
          r.append(MARC::DataField.new('866', '3', '1',
            MARC::Subfield.new('8', '1'),
            MARC::Subfield.new('a', '2003,2006-')
          ))
          r.append(MARC::DataField.new('863', ' ', '1',
            MARC::Subfield.new('8', '2.1'),
            MARC::Subfield.new('a', '2003')
          ))
          r.append(MARC::DataField.new('863', ' ', '1',
            MARC::Subfield.new('8', '3.1'),
            MARC::Subfield.new('a', '2006'),
            MARC::Subfield.new('b', '1')
          ))
          r.append(MARC::DataField.new('863', ' ', '1',
            MARC::Subfield.new('8', '3.2'),
            MARC::Subfield.new('a', '2006'),
            MARC::Subfield.new('b', '2')
          ))
          r.append(MARC::DataField.new('863', ' ', '1',
            MARC::Subfield.new('8', '3.3'),
            MARC::Subfield.new('a', '2011'),
            MARC::Subfield.new('b', '1')
          ))
          r.append(MARC::DataField.new('863', ' ', '1',
            MARC::Subfield.new('8', '3.4'),
            MARC::Subfield.new('a', '2011'),
            MARC::Subfield.new('b', '2')
          ))
        end
      end
      it do
        expect(result[field].length).to eq 1
        expect(result[field]).to eq ['lib -|- loc -|-  -|- 2003,2006- -|- 2011:pt.2']
      end
    end
  end
end
