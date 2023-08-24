# frozen_string_literal: true

RSpec.describe 'Format physical config' do
  subject(:value) { result[field] }
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end
  let(:result) { indexer.map_record(stub_record_from_marc(marc_record)) }
  let(:field) { 'genre_ssim' }

  describe 'conference proceedings' do
    context 'with a book' do
      let(:marc_record) do
        MARC::Record.new.tap do |r|
          r.leader = '15069nam a2200409 a 4500'
          r.append(MARC::ControlField.new('008', '091123s2014    si a    sb    101 0 eng d'))
          r.append(MARC::DataField.new('650', ' ', '0',
                                       MARC::Subfield.new('a', 'subject'),
                                       MARC::Subfield.new('v', 'Congresses')))
        end
      end

      it { is_expected.to include 'Conference proceedings' }
    end

    context 'with a computer file' do
      let(:marc_record) do
        MARC::Record.new.tap do |r|
          r.leader = '03779cmm a2200505 i 4500'
          r.append(MARC::ControlField.new('008', '131010t20132013cau        m        eng c'))
          r.append(MARC::DataField.new('650', ' ', '0',
                                       MARC::Subfield.new('a', 'subject'),
                                       MARC::Subfield.new('v', 'Congresses')))
        end
      end

      it { is_expected.to include 'Conference proceedings' }
    end

    context 'with a manuscript' do
      let(:marc_record) do
        MARC::Record.new.tap do |r|
          r.leader = '01443cpcaa2200289   4500'
          r.append(MARC::ControlField.new('008', '840706i18701943cau                 ger d'))
          r.append(MARC::DataField.new('650', ' ', '0',
                                       MARC::Subfield.new('a', 'subject'),
                                       MARC::Subfield.new('v', 'Congresses')))
        end
      end

      it { is_expected.to include 'Conference proceedings' }
    end

    context 'with a newspaper' do
      let(:marc_record) do
        MARC::Record.new.tap do |r|
          r.leader = '01102cas a2200277   4500'
          r.append(MARC::ControlField.new('008', '870604d19191919njudr ne      1    0eng d'))
          r.append(MARC::DataField.new('650', ' ', '0',
                                       MARC::Subfield.new('a', 'subject'),
                                       MARC::Subfield.new('v', 'Congresses')))
        end
      end

      it { is_expected.to include 'Conference proceedings' }
    end

    context 'with something else' do
      let(:marc_record) do
        MARC::Record.new.tap do |r|
          r.leader = '01482com a2200337 a 4500'
          r.append(MARC::ControlField.new('008', '840726s1980    dcu---        1   bneng d'))
          r.append(MARC::DataField.new('650', ' ', '0',
                                       MARC::Subfield.new('a', 'subject'),
                                       MARC::Subfield.new('v', 'Congresses')))
        end
      end

      it { is_expected.to include 'Conference proceedings' }
    end

    context 'with a sound recording' do
      let(:marc_record) do
        MARC::Record.new.tap do |r|
          r.leader = '03701cim a2200421 a 4500'
          r.append(MARC::ControlField.new('008', '040802c200u9999cau            l    eng d'))
          r.append(MARC::DataField.new('650', ' ', '0',
                                       MARC::Subfield.new('a', 'subject'),
                                       MARC::Subfield.new('v', 'Congresses')))
        end
      end

      it { is_expected.to include 'Conference proceedings' }
    end

    context 'with a video recording' do
      let(:marc_record) do
        MARC::Record.new.tap do |r|
          r.leader = '02840cgm a2200481 i 4500'
          r.append(MARC::ControlField.new('008', '110805t20112011cau074            vleng c'))
          r.append(MARC::DataField.new('650', ' ', '0',
                                       MARC::Subfield.new('a', 'subject'),
                                       MARC::Subfield.new('v', 'Congresses')))
        end
      end

      it { is_expected.to include 'Conference proceedings' }
    end

    context 'with a different video recording' do
      let(:marc_record) do
        MARC::Record.new.tap do |r|
          r.leader = '02958cgm a2200469Ki 4500'
          r.append(MARC::ControlField.new('008', '110504s2011    cau418            vleng d'))
          r.append(MARC::DataField.new('650', ' ', '0',
                                       MARC::Subfield.new('a', 'subject'),
                                       MARC::Subfield.new('v', 'Congresses')))
        end
      end

      it { is_expected.to include 'Conference proceedings' }
    end

    context 'with a 650|v Congresses' do
      let(:marc_record) do
        MARC::Record.new.tap do |r|
          r.leader = '04473caa a2200313Ia 4500'
          r.append(MARC::ControlField.new('008', '040202s2003    fi g     b    000 0deng d'))
          r.append(MARC::DataField.new('650', ' ', '0',
                                       MARC::Subfield.new('a', 'Music'),
                                       MARC::Subfield.new('v', 'Congresses.')))
        end
      end

      it { is_expected.to include 'Conference proceedings' }
    end

    context 'with a 600|v Congresses' do
      let(:marc_record) do
        MARC::Record.new.tap do |r|
          r.leader = '04473caa a2200313Ia 4500'
          r.append(MARC::ControlField.new('008', '040202s2003    fi g     b    000 0deng d'))
          r.append(MARC::DataField.new('600', ' ', '0',
                                       MARC::Subfield.new('a', 'Music'),
                                       MARC::Subfield.new('v', 'Congresses.')))
        end
      end

      it { is_expected.to include 'Conference proceedings' }
    end

    context 'with LeaderChar07 = m and 008/29 = 1' do
      let(:marc_record) do
        MARC::Record.new.tap do |r|
          r.leader = '04473cam a2200313Ia 4500'
          r.append(MARC::ControlField.new('008', '040202s2003    fi g     b    100 0deng d'))
        end
      end

      it { is_expected.to eq ['Conference proceedings'] }
    end

    context 'with LeaderChar07 = s and 008/29 = 1' do
      let(:marc_record) do
        MARC::Record.new.tap do |r|
          r.leader = '04473cas a2200313Ia 4500'
          r.append(MARC::ControlField.new('008', '040202s2003    fi g     b    100 0deng d'))
        end
      end

      it { is_expected.to eq ['Conference proceedings'] }
    end

    context 'with LeaderChar07 = m and 008/29 not 1' do
      let(:marc_record) do
        MARC::Record.new.tap do |r|
          r.leader = '04473cam a2200313Ia 4500'
          r.append(MARC::ControlField.new('008', '040202s2003    fi g     b    000 0deng d'))
        end
      end

      it { is_expected.to eq nil }
    end

    context 'with LeaderChar07 = s and 008/29 not 1' do
      let(:marc_record) do
        MARC::Record.new.tap do |r|
          r.leader = '04473cas a2200313Ia 4500'
          r.append(MARC::ControlField.new('008', '040202s2003    fi g     b    000 0deng d'))
        end
      end

      it { is_expected.to eq nil }
    end

    context 'with LeaderChar07 not s or m and 008/29 = 1' do
      let(:marc_record) do
        MARC::Record.new.tap do |r|
          r.leader = '04473caa a2200313Ia 4500'
          r.append(MARC::ControlField.new('008', '040202s2003    fi g     b    100 0deng d'))
        end
      end

      it { is_expected.to eq nil }
    end

    context 'with LeaderChar07 not s or m and 008/29 not 1' do
      let(:marc_record) do
        MARC::Record.new.tap do |r|
          r.leader = '04473caa a2200313Ia 4500'
          r.append(MARC::ControlField.new('008', '040202s2003    fi g     b    000 0deng d'))
        end
      end

      it { is_expected.to eq nil }
    end
  end

  context 'with 008 byte 21 is p  (Journal / periodical)' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '02808cas a22005778a 4500'
        r.append(MARC::ControlField.new('008', '050127c20149999enkfr p       |   a0eng c'))
        r.append(MARC::DataField.new('650', ' ', '0',
                                     MARC::Subfield.new('a', 'subject'),
                                     MARC::Subfield.new('v', 'Congresses')))
      end
    end

    it { is_expected.to eq ['Congresses', 'Conference proceedings'] }
  end

  context 'with 008 byte 21 is blank' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '02808cas a22005778a 4500'
        r.append(MARC::ControlField.new('008', '050127c20149999enkfr         |   a0eng c'))
        r.append(MARC::DataField.new('650', ' ', '0',
                                     MARC::Subfield.new('a', 'subject'),
                                     MARC::Subfield.new('v', 'Congresses')))
      end
    end

    it { is_expected.to eq ['Congresses', 'Conference proceedings'] }
  end

  context 'with 008 byte 21 is pipe' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '02808cas a22005778a 4500'
        r.append(MARC::ControlField.new('008', '110417s2011    le |||||||||||||| ||ara d'))
        r.append(MARC::DataField.new('650', ' ', '0',
                                     MARC::Subfield.new('a', 'subject'),
                                     MARC::Subfield.new('v', 'Congresses')))
      end
    end

    it { is_expected.to include 'Conference proceedings' }
  end

  context 'with 006 byte 4 is p' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '03163cas a2200553 a 4500'
        r.append(MARC::ControlField.new('006', 'ser p       0    0'))
        r.append(MARC::ControlField.new('006', '000000d197819uuilunnn         l    eng d'))
        r.append(MARC::DataField.new('650', ' ', '0',
                                     MARC::Subfield.new('a', 'subject'),
                                     MARC::Subfield.new('v', 'Congresses')))
      end
    end

    it { is_expected.to include 'Conference proceedings' }
  end

  context 'with 006 byte 4 is blank' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '03163cas a2200553 a 4500'
        r.append(MARC::ControlField.new('006', 'ser         0    0'))
        r.append(MARC::ControlField.new('006', '000000d197819uuilunnn         l    eng d'))
        r.append(MARC::DataField.new('650', ' ', '0',
                                     MARC::Subfield.new('a', 'subject'),
                                     MARC::Subfield.new('v', 'Congresses')))
      end
    end

    it { is_expected.to include 'Conference proceedings' }
  end

  context 'with 006 byte 4 is pipe' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '02393cas a2200421Ki 4500'
        r.append(MARC::ControlField.new('006', 'suu wss|||||0   |2'))
        r.append(MARC::ControlField.new('006', '130923c20139999un uu         1    0ukr d'))
        r.append(MARC::DataField.new('650', ' ', '0',
                                     MARC::Subfield.new('a', 'subject'),
                                     MARC::Subfield.new('v', 'Congresses')))
      end
    end

    it { is_expected.to include 'Conference proceedings' }
  end

  #   /**
  #    * Thesis value for a variety of main formats
  #    */
  # @Test
  #   public final void testThesis()
  #   {
  #       String fldVal = Genre.THESIS.toString();
  #     Record record = factory.newRecord();
  #     DataField df502 = factory.newDataField("502", ' ', ' ');
  #     df502.addSubfield(factory.newSubfield('a', "I exist"));
  #
  context 'thesis that is also a book' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '15069nam a2200409 a 4500'
        r.append(MARC::ControlField.new('008', '091123s2014    si a    sb    101 0 eng d'))
        r.append(MARC::DataField.new('502', ' ', ' ', MARC::Subfield.new('a', 'I exist')))
      end
    end

    it { is_expected.to include 'Thesis/Dissertation' }
  end

  context 'based on 4673069, thesis that is also a map/globe' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '01168cem a22002777  4500'
        r.append(MARC::ControlField.new('008', '020417s1981    caua, g  b    000 0 eng u'))
        r.append(MARC::DataField.new('502', ' ', ' ', MARC::Subfield.new('a', 'I exist')))
      end
    end

    it { is_expected.to include 'Thesis/Dissertation' }
  end

  context 'based on 4822393, thesis that is also a manuscript' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '01038npcaa2200265   4500'
        r.append(MARC::ControlField.new('008', '020812s2002    cau                 eng d'))
        r.append(MARC::DataField.new('502', ' ', ' ', MARC::Subfield.new('a', 'I exist')))
      end
    end

    it { is_expected.to include 'Thesis/Dissertation' }
  end

  context 'based on 297799, thesis that is also a Music recording' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '00979cjm a2200265   4500'
        r.append(MARC::ControlField.new('008', '790807s1979    xx zzz                  d'))
        r.append(MARC::DataField.new('502', ' ', ' ', MARC::Subfield.new('a', 'I exist')))
      end
    end

    it { is_expected.to include 'Thesis/Dissertation' }
  end

  context 'based on 7620611, thesis that is also a music score' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '00979cjm a2200265   4500'
        r.append(MARC::ControlField.new('008', '790807s1979    xx zzz                  d'))
        r.append(MARC::DataField.new('502', ' ', ' ', MARC::Subfield.new('a', 'I exist')))
      end
    end

    it { is_expected.to include 'Thesis/Dissertation' }
  end

  context 'based on 10208984 (likely a mistake in main format)' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '01165c m a2200313Ia 4500'
        r.append(MARC::ControlField.new('008', '840712r1983    xx a          0   0neng d'))
        r.append(MARC::DataField.new('502', ' ', ' ', MARC::Subfield.new('a', 'I exist')))
      end
    end

    it { is_expected.to include 'Thesis/Dissertation' }
  end

  context 'based on 10169038, thesis that is also a video' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '02245cgm a2200409Ia 4500'
        r.append(MARC::ControlField.new('008', '130215s2012    nyu050            vleng d'))
        r.append(MARC::DataField.new('502', ' ', ' ', MARC::Subfield.new('a', 'I exist')))
      end
    end

    it { is_expected.to include 'Thesis/Dissertation' }
  end

  # something is marked as both a proceedings and a thesis
  context 'based on 3743956' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '01360cam a22003011  4500'
        r.append(MARC::ControlField.new('008', '890928s1929    mdu           000 0 eng c'))
        r.append(MARC::DataField.new('650', ' ', '0',
                                     MARC::Subfield.new('a', 'subject'),
                                     MARC::Subfield.new('v', 'Congresses')))
        r.append(MARC::DataField.new('502', ' ', ' ', MARC::Subfield.new('a', 'Thesis (Ph. D.)--Johns Hopkins, 1928.')))
      end
    end

    it { is_expected.to include 'Conference proceedings', 'Thesis/Dissertation' }
  end

  context 'a government doc that is a book' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '01360cam a22003011  4500'
        r.append(MARC::ControlField.new('008', '890928s1929    mdu          i000 0 eng c'))
      end
    end

    it { is_expected.to eq ['Government document'] }
  end

  context 'based on 4673069, a government doc that is a map' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '01168cem a22002777  4500'
        r.append(MARC::ControlField.new('008', '020417s1981    caua, g  b   i000 0 eng u'))
        r.append(MARC::DataField.new('502', ' ', ' ', MARC::Subfield.new('a', 'I exist!')))
      end
    end

    it { is_expected.to eq ['Thesis/Dissertation', 'Government document'] }
  end

  context 'based on 4822393, a manuscript that is not a govdoc' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '01038npcaa2200265   4500'
        r.append(MARC::ControlField.new('008', '020812s2002    cau          i      eng d'))
      end
    end

    it { is_expected.to eq nil }
  end

  context 'based on 297799, a Music recording that is not a govdoc' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '00979cjm a2200265   4500'
        r.append(MARC::ControlField.new('008', '790807s1979    xx zzz       i          d'))
      end
    end

    it { is_expected.to eq nil }
  end

  context 'based on 7620611, a music score that is not a govdoc' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '01350cdm a2200337La 4500'
        r.append(MARC::ControlField.new('008', '010712r20082000xxumsa  rbehii n    lat d'))
        r.append(MARC::DataField.new('502', ' ', ' ', MARC::Subfield.new('a', 'I exist!')))
      end
    end

    it { is_expected.not_to include 'Government document' }
  end

  context 'based on 10208984, likely a mistake in main format' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '01165c m a2200313Ia 4500'
        r.append(MARC::ControlField.new('008', '840712r1983    xx a         i0   0neng d'))
        r.append(MARC::DataField.new('502', ' ', ' ', MARC::Subfield.new('a', 'I exist!')))
      end
    end

    it { is_expected.to include 'Government document' }
  end

  context 'a goverment document this is also a serial' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cas  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu          i000 0 eng d'))
      end
    end

    it { is_expected.to eq ['Government document'] }
  end

  context 'a goverment document this is also a video' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '02245cgm a2200409Ia 4500'
        r.append(MARC::ControlField.new('008', '130215s2012    nyu050       i    vleng d'))
        r.append(MARC::DataField.new('502', ' ', ' ', MARC::Subfield.new('a', 'I exist!')))
      end
    end

    it { is_expected.to eq ['Thesis/Dissertation', 'Government document'] }
  end

  context 'with the presence of a 008 that says it is not a report' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.append(MARC::ControlField.new('008', '091123s2014    si a    sbt   101 0 eng d'))
        r.append(MARC::DataField.new('027', ' ', ' ', MARC::Subfield.new('a', 'I exist')))
      end
    end

    it { is_expected.not_to eq 'Technical report' }
  end

  context 'with the presence of 027' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.append(MARC::DataField.new('027', ' ', ' ', MARC::Subfield.new('a', 'I exist')))
      end
    end

    it { is_expected.to include 'Technical report' }
  end

  context 'with the presence of 088' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.append(MARC::DataField.new('088', ' ', ' ', MARC::Subfield.new('a', 'I exist')))
      end
    end

    it { is_expected.to include 'Technical report' }
  end

  context 'with leader/06: a or t AND 008/24-27 (any position, i.e. 24, 25, 26, or 27): t' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '15069nam a2200409 a 4500'
        r.append(MARC::ControlField.new('008', '091123s2014    si a    sbt   101 0 eng d'))
      end
    end

    it { is_expected.to include 'Technical report' }
  end

  context 'with 006/00: a or t AND 006/7-10 (any position, i.e. 7, 8, 9, or 10): t' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.append(MARC::ControlField.new('006', 't||||||||t|f||||||'))
      end
    end

    it { is_expected.to include 'Technical report' }
  end

  describe 'with a 655a genre' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '04473cam a2200313Ia 4500'
        r.append(MARC::DataField.new('655', ' ', ' ',
                                     MARC::Subfield.new('a', 'Silent films.')))
        r.append(MARC::DataField.new('655', ' ', ' ',
                                     MARC::Subfield.new('a', 'Clay animation films.')))
      end
    end

    it 'should contain all 655a' do
      expect(result[field]).to eq ['Silent films', 'Clay animation films']
    end
  end

  describe 'with a 655v genre' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '04473cam a2200313Ia 4500'
        r.append(MARC::DataField.new('655', ' ', ' ',
                                     MARC::Subfield.new('v', 'Software.')))
      end
    end

    it 'should contain all 655v' do
      expect(result[field]).to eq ['Software']
    end
  end

  describe 'with a 6xxv genre' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '04473cam a2200313Ia 4500'
        r.append(MARC::DataField.new('600', ' ', '0',
                                     MARC::Subfield.new('a', 'Gautama Buddha'),
                                     MARC::Subfield.new('v', 'Early works to 1800.')))
        r.append(MARC::DataField.new('600', ' ', '1',
                                     MARC::Subfield.new('v', 'Bildband')))
        r.append(MARC::DataField.new('610', ' ', '0',
                                     MARC::Subfield.new('a', 'Something'),
                                     MARC::Subfield.new('v', 'Case studies')))
        r.append(MARC::DataField.new('610', ' ', ' ',
                                     MARC::Subfield.new('v', 'Guidebooks')))
        r.append(MARC::DataField.new('611', ' ', '0',
                                     MARC::Subfield.new('a', 'Something'),
                                     MARC::Subfield.new('v', 'Speeches in Congress')))
        r.append(MARC::DataField.new('611', ' ', '4',
                                     MARC::Subfield.new('v', 'Fiction')))
        r.append(MARC::DataField.new('630', ' ', '0',
                                     MARC::Subfield.new('a', 'Something'),
                                     MARC::Subfield.new('v', 'Criticism, interpretation, etc.')))
        r.append(MARC::DataField.new('630', ' ', '7',
                                     MARC::Subfield.new('v', 'Teatro')))
        r.append(MARC::DataField.new('650', ' ', '0',
                                     MARC::Subfield.new('a', 'World War, 1939-1945'),
                                     MARC::Subfield.new('v', 'Personal narratives.')))
        r.append(MARC::DataField.new('650', ' ', '1',
                                     MARC::Subfield.new('v', 'Humor')))
        r.append(MARC::DataField.new('651', ' ', '0',
                                     MARC::Subfield.new('a', 'Something'),
                                     MARC::Subfield.new('v', 'Census, 1999.')))
        r.append(MARC::DataField.new('651', ' ', '4',
                                     MARC::Subfield.new('v', 'Ausstellung')))
      end
    end

    it 'should contain all 6xxv' do
      expect(result[field]).to eq [
        'Early works to 1800',
        'Bildband',
        'Case studies',
        'Guidebooks',
        'Speeches in Congress',
        'Fiction',
        'Criticism, interpretation, etc.',
        'Teatro',
        'Personal narratives',
        'Humor',
        'Census, 1999',
        'Ausstellung'
      ]
    end
  end

  describe 'with multiple 650v genre' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '04473cam a2200313Ia 4500'
        r.append(MARC::DataField.new('650', ' ', ' ',
                                     MARC::Subfield.new('a', 'Automobiles'),
                                     MARC::Subfield.new('x', 'Collision damage'),
                                     MARC::Subfield.new('z', 'California'),
                                     MARC::Subfield.new('v', 'Statistics'),
                                     MARC::Subfield.new('v', 'Periodicals.')))
      end
    end

    it 'should contain all 650v' do
      expect(result[field]).to eq %w[Statistics Periodicals]
    end
  end

  describe 'genre facet normalization' do
    let(:marc_record) do
      MARC::Record.new.tap do |r|
        r.leader = '04473cam a2200313Ia 4500'
        r.append(MARC::DataField.new('650', ' ', ' ',
                                     MARC::Subfield.new('v', 'Anecdotes..') # trailing periods
        ))
        r.append(MARC::DataField.new('650', ' ', '0',
                                     MARC::Subfield.new('v', 'Art and the war.') # trailing period
        ))
        # Trailing whitespace and multiple intra-field whitespace
        r.append(MARC::DataField.new('655', ' ', '7',
                                     MARC::Subfield.new('v', 'Accordion fold format  (Binding) ') # trailing period
        ))
        r.append(MARC::DataField.new('650', ' ', '0',
                                     MARC::Subfield.new('v', 'Underwater photography .') # trailing space period
        ))
        r.append(MARC::DataField.new('655', ' ', ' ',
                                     MARC::Subfield.new('v', 'Sociology. .') # trailing period space
        ))
        # Period succeeding word with three letters
        r.append(MARC::DataField.new('650', ' ', '0',
                                     MARC::Subfield.new('v', 'Translations into Udi.')))
        r.append(MARC::DataField.new('650', ' ', '0',
                                     MARC::Subfield.new('v', 'Mic.')))
        r.append(MARC::DataField.new('650', ' ', '0',
                                     MARC::Subfield.new('v', 'Art.')))
        r.append(MARC::DataField.new('655', ' ', ' ',
                                     MARC::Subfield.new('a', 'Dr.')))
      end
    end

    it 'normaliozes all the values correctly' do
      expect(result[field]).to match_array [
        'Anecdotes',
        'Art and the war',
        'Accordion fold format (Binding)',
        'Underwater photography',
        'Sociology',
        'Translations into Udi',
        'Mic',
        'Art',
        'Dr.'
      ]
    end
  end

  context 'with some fixture data' do
    let(:records) { MARC::XMLReader.new(file_fixture(fixture_name).to_s).to_a }
    let(:fixture_name) { 'genreFacetTests.xml' }
    subject(:results) { records.map { |rec| indexer.map_record(stub_record_from_marc(rec)) }.to_a }

    it 'maps the right data' do
      expect(select_by_id('655aGenre')[field]).to eq ['Silent films', 'Correspondence']
      expect(select_by_id('610vGenre')[field]).to eq ['Correspondence']
      expect(select_by_id('610vGenre2')[field]).to eq ['Correspondence']
    end

    it 'has no noGenre' do
      expect(select_by_id('NoGenre')).not_to include(field)
    end
  end
end
