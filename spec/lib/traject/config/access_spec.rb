# frozen_string_literal: true

RSpec.describe 'Access config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/marc_config.rb')
    end
  end

  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:fixture_name) { 'onlineFormat.mrc' }
  subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
  let(:field) { 'access_facet' }

  describe 'with fulltext URLs in bib' do
    it 'is considered online' do
      expect(select_by_id('856ind2is0')[field]).to include 'Online'
      expect(select_by_id('856ind2is0Again')[field]).to include 'Online'
      expect(select_by_id('856ind2is1NotToc')[field]).to include 'Online'
      expect(select_by_id('956BlankIndicators')[field]).to include 'Online'
      expect(select_by_id('956ind2is0')[field]).to include 'Online'
      expect(select_by_id('956and856TOC')[field]).to include 'Online'
      expect(select_by_id('mult856and956')[field]).to include 'Online'
      expect(select_by_id('956and856TOCand856suppl')[field]).to include 'Online'
      expect(select_by_id('7117119')[field]).to include 'Online'
      expect(select_by_id('newSfx')[field]).to include 'Online'
      # blank ind2 is most likely not fulltext
      expect(select_by_id('856ind2isBlankFulltext')[field]).not_to include 'Online'
    end
  end

  describe 'with sfx URLs in bib' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '00988nas a2200193z  4500'
        r.append(MARC::ControlField.new('008', '071214uuuuuuuuuxx uu |ss    u|    |||| d'))
        r.append(MARC::DataField.new('956', '4', '0',
                                     MARC::Subfield.new('u', 'http://caslon.stanford.edu:3210/sfxlcl3?url_ver=Z39.88-2004&amp;ctx_ver=Z39.88-2004&amp;ctx_enc=info:ofi/enc:UTF-8&amp;rfr_id=info:sid/sfxit.com:opac_856&amp;url_ctx_fmt=info:ofi/fmt:kev:mtx:ctx&amp;sfx.ignore_date_threshold=1&amp;rft.object_id=110978984448763&amp;svc_val_fmt=info:ofi/fmt:kev:mtx:sch_svc&amp;')))
        r.append(MARC::DataField.new('999', ' ', ' ',
                                     MARC::Subfield.new('a', 'INTERNET RESOURCE'),
                                     MARC::Subfield.new('w', 'ASIS'),
                                     MARC::Subfield.new('i', '2475606-5001'),
                                     MARC::Subfield.new('l', 'INTERNET'),
                                     MARC::Subfield.new('m', 'SUL')))
      end
    end

    specify { expect(result[field]).to eq ['Online'] }
  end

  describe 'with a bound-with without any holdings' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '00988nas a2200193z  4500'
        r.append(MARC::ControlField.new('008', '071214uuuuuuuuuxx uu |ss    u|    |||| d'))
        r.append(MARC::DataField.new('590', '4', '0',
                                     MARC::Subfield.new('a', 'Bound-with'),
                                     MARC::Subfield.new('c', '123456789')))
      end
    end

    specify { expect(result[field]).to eq ['At the Library'] }
  end

  describe 'when the url is that of a GSB request' do
    it 'is considered at the library' do
      expect(select_by_id('123http')[field]).to eq ['At the Library']
      expect(select_by_id('124http')[field]).to eq ['At the Library']
      expect(select_by_id('1234https')[field]).to eq ['At the Library']
      expect(select_by_id('7423084')[field]).to eq ['At the Library']
    end
  end

  describe 'from item library and location fields in the 999' do
    let(:fixture_name) { 'buildingTests.mrc' }

    it 'is considered online' do
      # has SFX url in 956
      expect(select_by_id('7117119')[field]).to eq ['Online']
    end

    it 'is considered At the Library' do
      expect(select_by_id('115472')[field]).to eq ['At the Library']
      expect(select_by_id('2442876')[field]).to eq ['At the Library']
      # formerly "Upon request"
      # SAL1 & 2
      expect(select_by_id('1033119')[field]).to eq ['At the Library']
      expect(select_by_id('1962398')[field]).to eq ['At the Library']
      expect(select_by_id('2328381')[field]).to eq ['At the Library']
      expect(select_by_id('2913114')[field]).to eq ['At the Library']
      # SAL3
      expect(select_by_id('690002')[field]).to eq ['At the Library']
      expect(select_by_id('3941911')[field]).to eq ['At the Library']
      expect(select_by_id('7651581')[field]).to eq ['At the Library']
      expect(select_by_id('2214009')[field]).to eq ['At the Library']
      # SAL-NEWARK
      expect(select_by_id('804724')[field]).to eq ['At the Library']
      # SPEC-INPRO item
      expect(select_by_id('12265160')[field]).to eq ['At the Library']
    end
  end

  describe 'updating looseleef' do
    subject(:result) { indexer.map_record(record) }

    context 'based on 9335774' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01426cas a2200385Ia 4500'
          r.append(MARC::ControlField.new('007', '110912c20119999mnuar l       0    0eng  '))
          r.append(MARC::DataField.new('999', ' ', ' ',
                                       MARC::Subfield.new('a', 'F152 .A28'),
                                       MARC::Subfield.new('w', 'LC'),
                                       MARC::Subfield.new('i', '36105018746623'),
                                       MARC::Subfield.new('l', 'HAS-DIGIT'),
                                       MARC::Subfield.new('m', 'GREEN')))
        end
      end

      it 'is at the library' do
        expect(result[field]).to eq ['At the Library']
      end
    end
    context 'based on 9335774, but online' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01426cas a2200385Ia 4500'
          r.append(MARC::ControlField.new('007', '110912c20119999mnuar l       0    0eng  '))
          r.append(MARC::DataField.new('999', ' ', ' ',
                                       MARC::Subfield.new('a', 'INTERNET RESOURCE'),
                                       MARC::Subfield.new('w', 'ASIS'),
                                       MARC::Subfield.new('i', '2475606-5001'),
                                       MARC::Subfield.new('l', 'INTERNET'),
                                       MARC::Subfield.new('m', 'SUL')))
        end
      end

      it 'is online' do
        expect(result[field]).to eq ['Online']
      end
    end
  end

  describe 'On order' do
    let(:on_order_ignore_locs) { %w[ENDPROCESS LAC INPROCESS SPEC-INPRO] }

    context 'when an XX call number has a current location of ON-ORDER' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(
            MARC::DataField.new(
              '999', ' ', ' ',
              MARC::Subfield.new('a', 'XXwhatever'),
              MARC::Subfield.new('k', 'ON-ORDER')
            )
          )
        end
      end

      it { expect(result[field]).to eq ['On order'] }
    end

    context 'when an XX call number is not ON-ORDER (and is not in a blacklisted location)' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(
            MARC::DataField.new(
              '999', ' ', ' ',
              MARC::Subfield.new('a', 'XXwhatever'),
              MARC::Subfield.new('k', 'SOMEWHERE-ELSE')
            )
          )
        end
      end

      it { expect(result[field]).to eq ['On order'] }
    end

    context 'when an XX call number is not ON-ORDER (but is in HV-ARCHIVE)' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(
            MARC::DataField.new(
              '999', ' ', ' ',
              MARC::Subfield.new('a', 'XXwhatever'),
              MARC::Subfield.new('k', 'SOMEWHERE-ELSE'),
              MARC::Subfield.new('m', 'HV-ARCHIVE')
            )
          )
        end
      end

      it { expect(result[field]).not_to include 'On order' }
    end

    context 'when an XX call number is not ON-ORDER (but it is in a blacklisted home location)' do
      let(:record) do
        MARC::Record.new.tap do |r|
          on_order_ignore_locs.each do |loc|
            r.append(
              MARC::DataField.new(
                '999', ' ', ' ',
                MARC::Subfield.new('a', 'XXwhatever'),
                MARC::Subfield.new('k', 'ANYTHING'),
                MARC::Subfield.new('l', loc)
              )
            )
          end
        end
      end

      it { expect(result[field]).not_to include 'On order' }
    end

    context 'when an XX call number is not ON-ORDER (but it is in a blacklisted current location)' do
      let(:record) do
        MARC::Record.new.tap do |r|
          on_order_ignore_locs.each do |loc|
            r.append(
              MARC::DataField.new(
                '999', ' ', ' ',
                MARC::Subfield.new('a', 'XXwhatever'),
                MARC::Subfield.new('k', loc)
              )
            )
          end
        end
      end

      it { expect(result[field]).not_to include 'On order' }
    end
  end
end
