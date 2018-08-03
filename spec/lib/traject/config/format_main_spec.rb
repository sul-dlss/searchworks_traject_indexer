RSpec.describe 'Format main config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end
  subject(:result) { indexer.map_record(record) }
  let(:field) { 'format_main_ssim'}

  describe 'format_main_ssim' do
    context 'with leader/06 i - audio non-music' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01952cid  2200457Ia 4500'
          r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 v eng d'))
          r.append(MARC::DataField.new('245', '1', ' ', MARC::Subfield.new('a', 'audio non-music: leader/06 i')))
        end
      end
      it 'is a sound recording' do
        expect(result[field]).to eq ['Sound Recording']
      end
    end

    context 'with 245h [sound recording]' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01952c d  2200457Ia 4500'
          r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 v eng d'))
          r.append(MARC::DataField.new('245', '1', ' ',
            MARC::Subfield.new('a', 'sound recording: 245h'),
            MARC::Subfield.new('h', '[sound recording]'),
          ))
        end
      end

      xit 'is a sound recording' do
        expect(result[field]).to eq ['Sound Recording']
      end
    end

    context 'with leader/06 a /07 m' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01952cam  2200457Ia 4500'
          r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 v eng d'))
        end
      end

      it 'is a book' do
        expect(result[field]).to eq ['Book']
      end
    end

    context 'with leader/06 t /07 a' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01952cta  2200457Ia 4500'
          r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 v eng d'))
        end
      end

      it 'is a book' do
        expect(result[field]).to eq ['Book']
      end
    end

    context 'with conference proceedings - 600v Congresses' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '04473cam a2200313Ia 4500'
          r.append(MARC::ControlField.new('008', '040202s2003    fi g     b    100 0deng d'))
          r.append(MARC::DataField.new('600', '1', '0',
            MARC::Subfield.new('a', 'Sibelius, Jean,'),
            MARC::Subfield.new('d', '1865-1957'),
            MARC::Subfield.new('v', 'Congresses.'),
          ))
        end
      end

      it 'is a book' do
        expect(result[field]).to eq ['Book']
      end
    end

    context 'Conference Proceedings - 650v Congresses' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '04473cam a2200313Ia 4500'
          r.append(MARC::ControlField.new('008', '040202s2003    fi g     b    100 0deng d'))
          r.append(MARC::DataField.new('650', '1', '0',
            MARC::Subfield.new('a', 'Music'),
            MARC::Subfield.new('v', 'Congresses.')
          ))
        end
      end

      it 'is a book' do
        expect(result[field]).to eq ['Book']
      end
    end

    # formerly believed to be monographic series
    context 'leader/07 b, 006/00 s, 008/21 m  - serial publication' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01952cab  2200457Ia 4500'
          r.append(MARC::ControlField.new('006', 's        h        '))
          r.append(MARC::ControlField.new('008', '780930m19391944nyu   m       000 v eng d'))
        end
      end

      it 'is an other' do
        expect(result[field]).to eq ['Journal/Periodical']
      end
    end

    # Book series
    context 'based on 9343812 - SFX link' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01937cas a2200433 a 4500'
          r.append(MARC::ControlField.new('008', '070207c20109999mauqr m o     0   a0eng c'))
          r.append(MARC::DataField.new('956', '4', '0', MARC::Subfield.new('u', ' http://library.stanford.edu/sfx?stuff')))
        end
      end

      it 'is a book' do
        expect(result[field]).to eq ['Book']
      end
    end

    context 'based on 9138750 - no SFX link' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01750cas a2200409 a 4500'
          r.append(MARC::ControlField.new('008', '101213c20109999dcufr m bs   i0    0eng c'))
        end
      end

      it 'is a book' do
        expect(result[field]).to eq ['Book']
      end
    end

    # monographic series without SFX links
    context 'leader/07 s, no 006, 008/21 m - book (monographic series)' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01952cas  2200457Ia 4500'
          r.append(MARC::ControlField.new('008', '780930m19391944nyu   m       000 v eng d'))
        end
      end

      it 'is a book' do
        expect(result[field]).to eq ['Book']
      end
    end

    context 'leader/07 s  and 008/21 m - Book: monographic series' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '00868cas a22002294a 4500'
          r.append(MARC::ControlField.new('008', '050823c20029999ohuuu m       0    0eng d'))
        end
      end

      it 'is a book' do
        expect(result[field]).to eq ['Book']
      end
    end

    context 'leader/07 b, 006/00 s, 006/04 m, 008/21 d - book (monographic series)' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01952cab  2200457Ia 4500'
          r.append(MARC::ControlField.new('006', 's   m    h        '))
          r.append(MARC::ControlField.new('008', '780930m19391944nyu   d       000 v eng d'))
        end
      end

      it 'is a book' do
        expect(result[field]).to eq ['Book']
      end
    end
  end

  context 'other stuff' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01529cac a2200397Ia 4500'
        r.append(MARC::ControlField.new('008', '081215c200u9999xx         b        eng d'))
      end
    end

    it 'is a manuscript' do
      expect(result[field]).to eq ['Archive/Manuscript']
    end
  end

  context 'other stuff' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01529ctc a2200397Ia 4500'
        r.append(MARC::ControlField.new('008', '081215c200u9999xx         b        eng d'))
      end
    end

    it 'is a manuscript' do
      expect(result[field]).to eq ['Archive/Manuscript']
    end
  end

  context 'leader/06 m 008/26 u - other (not data)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cmd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu        u  000 v eng d'))
      end
    end

    it 'is a Software/Multimedia' do
      expect(result[field]).to eq ['Software/Multimedia']
    end
  end

  context 'leader/06 m 008/26 u - other (not data)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01529cmi a2200397Ia 4500'
        r.append(MARC::ControlField.new('008', '081215c200u9999xx         b        eng d'))
      end
    end

    it 'is a Software/Multimedia' do
      expect(result[field]).to eq ['Software/Multimedia']
    end
  end

  context 'online copy only of a Software/Multimedia and database' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02441cms a2200517 a 4500'
        r.append(MARC::ControlField.new('008', '920901d19912002pauuu1n    m  0   a0eng  '))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', "INTERNET RESOURCE"),
          MARC::Subfield.new('w', "ASIS"),
          MARC::Subfield.new('i', "2475606-5001"),
          MARC::Subfield.new('l', "INTERNET"),
          MARC::Subfield.new('m', "SUL"),
          MARC::Subfield.new('t', "DATABASE")
        ))
      end
    end

    xit 'is only a database' do
      expect(result[field]).to eq ['Database']
    end
  end

  context 'both physical copy and online copy of a Software/Multimedia and database' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02441cms a2200517 a 4500'
        r.append(MARC::ControlField.new('008', '920901d19912002pauuu1n    m  0   a0eng  '))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', "INTERNET RESOURCE"),
          MARC::Subfield.new('w', "ASIS"),
          MARC::Subfield.new('i', "2475606-5001"),
          MARC::Subfield.new('l', "INTERNET"),
          MARC::Subfield.new('m', "SUL"),
          MARC::Subfield.new('t', "DATABASE")
        ))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'F152 .A28'),
          MARC::Subfield.new('w', 'LC'),
          MARC::Subfield.new('i', '36105018746623'),
          MARC::Subfield.new('l', 'HAS-DIGIT'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    it 'is a database' do
      expect(result[field]).to eq ['Software/Multimedia', 'Database']
    end
  end

  context 'with 650|v Congresses' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04473caa a2200313Ia 4500'
        r.append(MARC::ControlField.new('008', '040202s2003    fi g     b    000 0deng d'))
        r.append(MARC::DataField.new('650', ' ', '0',
          MARC::Subfield.new('a', "Music"),
          MARC::Subfield.new('v', "Congresses.")
        ))
      end
    end

    it 'is a book' do
      expect(result[field]).to eq ['Book']
    end
  end

  context 'with 650|v Congresses' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04473caa a2200313Ia 4500'
        r.append(MARC::ControlField.new('008', '040202s2003    fi g     b    000 0deng d'))
        r.append(MARC::DataField.new('600', '1', '0',
          MARC::Subfield.new('a', "Sibelius, Jean,"),
          MARC::Subfield.new('d', "1865-1957"),
          MARC::Subfield.new('v', "Congresses.")
        ))
      end
    end

    it 'is a book' do
      expect(result[field]).to eq ['Book']
    end
  end

  context 'LeaderChar07 = m and 008/29 = 1' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04473cam a2200313Ia 4500'
        r.append(MARC::ControlField.new('008', '040202s2003    fi g     b    000 0deng d'))
      end
    end

    it 'is a book' do
      expect(result[field]).to eq ['Book']
    end
  end

  context 'LeaderChar07 = s and 008/29 = 1' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04473cas a2200313Ia 4500'
        r.append(MARC::ControlField.new('008', '040202s2003    fi g     b    000 0deng d'))
      end
    end

    it 'is an other' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context 'leader/06 m 008/26 a' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cmd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu        a  000 v eng d'))
      end
    end

    it 'is a dataset' do
      expect(result[field]).to eq ['Dataset']
    end
  end

  context 'leader/06 m 008/26 a' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01529cmi a2200397Ia 4500'
        r.append(MARC::ControlField.new('008', '081215c200u9999xx         a        eng d'))
      end
    end

    it 'is a dataset' do
      expect(result[field]).to eq ['Dataset']
    end
  end

  context 'leader/06 m 008/26 a' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02441cms a2200517 a 4500'
        r.append(MARC::ControlField.new('008', '920901d19912002pauuu1n    m  0   a0eng  '))
        r.append(MARC::DataField.new('914', ' ', ' ', MARC::Subfield.new('a', 'EQUIP')))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', "F152 .A28"),
          MARC::Subfield.new('w', "LC"),
          MARC::Subfield.new('i', "36105018746623"),
          MARC::Subfield.new('l', "HAS-DIGIT"),
          MARC::Subfield.new('m', "GREEN")
        ))
      end
    end

    it 'is equipment' do
      expect(result[field]).to eq ['Equipment']
    end
  end

  context 'not equipment' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02808cas a22005778a 4500'
        r.append(MARC::ControlField.new('008', '050127c20149999enkfr p       |   a0eng c'))
        r.append(MARC::DataField.new('914', ' ', ' ', MARC::Subfield.new('a', 'JUNK')))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', "F152 .A28"),
          MARC::Subfield.new('w', "LC"),
          MARC::Subfield.new('i', "36105018746623"),
          MARC::Subfield.new('l', "HAS-DIGIT"),
          MARC::Subfield.new('m', "GREEN")
        ))
      end
    end

    it 'is equipment' do
      expect(result[field]).not_to include 'Equipment'
    end
  end

  context 'no 914$a' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02808cas a22005778a 4500'
        r.append(MARC::ControlField.new('008', '050127c20149999enkfr p       |   a0eng c'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', "F152 .A28"),
          MARC::Subfield.new('w', "LC"),
          MARC::Subfield.new('i', "36105018746623"),
          MARC::Subfield.new('l', "HAS-DIGIT"),
          MARC::Subfield.new('m', "GREEN")
        ))
      end
    end

    it 'is equipment' do
      expect(result[field]).not_to include 'Equipment'
    end
  end

  context 'leader/06 g 008/33 a - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 a eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 g 008/33 c - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 c eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 g 008/33 i - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 i eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 g 008/33 k - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 k eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 g 008/33 l - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 l eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 g 008/33 n - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 n eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 g 008/33 o - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 o eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 g 008/33 p - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 p eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 g 008/33 s - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 s eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 g 008/33 t - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 t eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 k 008/33 blank - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000   eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 k 008/33 | - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 | eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 k 008/33 0 - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 0 eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 k 008/33 1 - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 1 eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 k 008/33 2 - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 2 eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 k 008/33 3 - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 3 eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 k 008/33 4 - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 4 eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 k 008/33 5 - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 5 eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 k 008/33 6 - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 6 eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 k 008/33 7 - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 7 eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 k 008/33 8 - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 8 eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 k 008/33 9 - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 9 eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/07 k 008/33 a - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 a eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/07 k 008/33 c - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 c eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/07 k 008/33 i - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 i eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/07 k 008/33 k - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 k eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/07 k 008/33 l - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 l eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/07 k 008/33 n - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 n eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/07 k 008/33 o - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 o eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/07 k 008/33 p - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 p eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/07 k 008/33 s - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 s eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/07 k 008/33 t - image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 t eng d'))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context '245h [art original/digital graphic] --> Image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', ' ',
          MARC::Subfield.new('a', 'art original/digital graphic: 245h'),
          MARC::Subfield.new('h', '[art original/digital graphic]'),
        ))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context '245h [slide] --> Image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', ' ',
          MARC::Subfield.new('a', 'slide: 245h'),
          MARC::Subfield.new('h', '[slide]'),
        ))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context '245h [slides] --> Image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', ' ',
          MARC::Subfield.new('a', 'slides: 245h'),
          MARC::Subfield.new('h', '[slides]'),
        ))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context '245h [chart] --> Image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', ' ',
          MARC::Subfield.new('a', 'chart: 245h'),
          MARC::Subfield.new('h', '[chart]'),
        ))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context '245h [art reproduction] --> Image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', ' ',
          MARC::Subfield.new('a', 'art reproduction: 245h'),
          MARC::Subfield.new('h', '[art reproduction]'),
        ))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context '245h [graphic] --> Image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', ' ',
          MARC::Subfield.new('a', 'graphic: 245h'),
          MARC::Subfield.new('h', '[graphic]'),
        ))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context '245h [technical drawing] --> Image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', ' ',
          MARC::Subfield.new('a', 'technical drawing: 245h'),
          MARC::Subfield.new('h', '[technical drawing]'),
        ))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context '245h [flash card] --> Image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', ' ',
          MARC::Subfield.new('a', 'flash card: 245h'),
          MARC::Subfield.new('h', '[flash card]'),
        ))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context '245h [transparency] --> Image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', ' ',
          MARC::Subfield.new('a', 'transparency: 245h'),
          MARC::Subfield.new('h', '[transparency]'),
        ))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context '245h [digital graphic] --> Image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', ' ',
          MARC::Subfield.new('a', 'digital graphic: 245h'),
          MARC::Subfield.new('h', '[digital graphic]'),
        ))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context '245h [activity card] --> Image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', ' ',
          MARC::Subfield.new('a', 'activity card: 245h'),
          MARC::Subfield.new('h', '[activity card]'),
        ))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context '245h [picture] --> Image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', ' ',
          MARC::Subfield.new('a', 'picture: 245h'),
          MARC::Subfield.new('h', '[picture]'),
        ))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context '245h [graphic/digital graphic] --> Image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', ' ',
          MARC::Subfield.new('a', 'graphic/digital graphic: 245h'),
          MARC::Subfield.new('h', '[graphic/digital graphic]'),
        ))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context '245h [diapositives] --> Image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', ' ',
          MARC::Subfield.new('a', 'diapositives: 245h'),
          MARC::Subfield.new('h', '[diapositives]'),
        ))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context 'leader/06 a /07 s 008/21 blank - serial publication' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cas  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 0 eng d'))
      end
    end

    it 'is an journal' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context 'leader/07 s 008/21 blank, 65x sub v "Periodicals" - serial publication' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01823cas a22004457a 4500'
        r.append(MARC::ControlField.new('008', '961105d19961996dcuuuu       f0    0eng d'))
        r.append(MARC::DataField.new('650', ' ', '0',
          MARC::Subfield.new('a', 'Industrial statistics'),
          MARC::Subfield.new('v', 'Periodicals.'),
        ))
        r.append(MARC::DataField.new('650', ' ', '0',
          MARC::Subfield.new('a', 'United States'),
          MARC::Subfield.new('v', 'Periodicals.'),
        ))
      end
    end

    it 'is an journal' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context 'leader/07 b, 006/00 s, 006/04 blank, 008/21 blank - serial publication' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01823cab a22004457a 4500'
        r.append(MARC::ControlField.new('006', 's        h        '))
        r.append(MARC::ControlField.new('008', '961105d19961996dcuuuu       f0    0eng d'))
      end
    end

    it 'is an journal' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context 'leader/07 b, 006/00 s, 006/04 blank, 008/21 blank - serial publication' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cab  2200457Ia 4500'
        r.append(MARC::ControlField.new('006', 's        h        '))
        r.append(MARC::ControlField.new('008', '780930m19391944nyu   m       000 v eng d'))
      end
    end

    it 'is an journal' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context 'leader/07 b, 006/00 s, 008/21 p - Serial Publication' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cab  2200457Ia 4500'
        r.append(MARC::ControlField.new('006', 's        h        '))
        r.append(MARC::ControlField.new('008', '780930m19391944nyu   p       000 v eng d'))
      end
    end

    it 'is an journal' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context 'format serial publication:  leader/07 s and 008/21 blank (ignore LCPER in 999w)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01247cas a2200337 a 4500'
        r.append(MARC::ControlField.new('008', '830415c19809999vauuu    a    0    0eng  '))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'E184.S75 R47A V.1 1980'),
          MARC::Subfield.new('w', 'LCPER'),
          MARC::Subfield.new('i', '36105007402873'),
          MARC::Subfield.new('l', 'STACKS'),
          MARC::Subfield.new('m', 'GREEN'),
        ))
      end
    end

    it 'is an journal' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context 'format serial publication:  leader/07 s and 008/21 blank (ignore DEWEYPER in 999w)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01247cas a2200337 a 4500'
        r.append(MARC::ControlField.new('008', '830415c19809999vauuu    a    0    0eng  '))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'E184.S75 R47A V.1 1980'),
          MARC::Subfield.new('w', 'DEWEYPER'),
          MARC::Subfield.new('i', '36105007402873'),
          MARC::Subfield.new('l', 'STACKS'),
          MARC::Subfield.new('m', 'GREEN'),
        ))
      end
    end

    it 'is an journal' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context 'leader/07 s, no 006, 008/21 p - journal' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cas  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu   p       000 v eng d'))
      end
    end

    it 'is an journal' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context 'leader/07 s 008/21 d, 006/00 s 006/04 pl' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01068cas a2200277 a 4500'
        r.append(MARC::ControlField.new('006', 's   p    h        '))
        r.append(MARC::ControlField.new('008', '030807c20029999nyufx         0    0eng c'))
      end
    end

    it 'is an journal' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context 'Other: leader/07 s 008/21 d, 006/00 s 006/04 d' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01068cas a2200277 a 4500'
        r.append(MARC::ControlField.new('006', 's   d    h        '))
        r.append(MARC::ControlField.new('008', '030807c20029999nyufx d       0    0eng c'))
      end
    end

    it 'is an journal' do
      expect(result[field]).to eq ['Database']
    end
  end

  context 'format Other should be access online leader/07 s, 006/00 m, 008/21 we are favoring anything in 008/21  over  006/00' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '00988nas a2200193z  4500'
        r.append(MARC::ControlField.new('006', 'm        d        '))
        r.append(MARC::ControlField.new('008', '071214uuuuuuuuuxx uu |ss    u|    |||| d'))
        r.append(MARC::DataField.new('956', '4', '0', MARC::Subfield.new('u', ' http://library.stanford.edu/sfx?stuff')))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'INTERNET RESOURCE'),
          MARC::Subfield.new('w', 'ASIS'),
          MARC::Subfield.new('i', '7117119-1001'),
          MARC::Subfield.new('l', 'INTERNET'),
          MARC::Subfield.new('t', 'SUL'),
        ))
      end
    end

    it 'is an journal' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context 'No 006 008 byte 21 is p  (Journal / periodical)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02808cas a22005778a 4500'
        r.append(MARC::ControlField.new('008', '050127c20149999enkfr p       |   a0eng c'))
      end
    end

    it 'is an journal' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context '008 byte 21 is blank' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02393cas a2200421Ki 4500'
        r.append(MARC::ControlField.new('008', '130923c20139999un uu         1    0ukr d'))
      end
    end

    it 'is an journal' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context '008 byte 21 is | (pipe)  Journal' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '00756nas a22002175a 4500'
        r.append(MARC::ControlField.new('008', '110417s2011    le |||||||||||||| ||ara d'))
      end
    end

    it 'is an journal' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context '006 byte 4 is p' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '03163cas a2200553 a 4500'
        r.append(MARC::ControlField.new('006', 'ser p       0    0'))
        r.append(MARC::ControlField.new('008', '000000d197819uuilunnn         l    eng d'))
      end
    end

    it 'is an journal' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context '006 byte 4 is blank' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02393cas a2200421Ki 4500'
        r.append(MARC::ControlField.new('006', 'ser         0    0'))
        r.append(MARC::ControlField.new('008', '130923c20139999un uu         1    0ukr d'))
      end
    end

    it 'is an journal' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context '006 byte 4 is blank' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02393cas a2200421Ki 4500'
        r.append(MARC::ControlField.new('006', 'suu wss|||||0   |2'))
        r.append(MARC::ControlField.new('008', '130923c20139999un uu         1    0ukr d'))
      end
    end

    it 'is an journal' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end


  context 'Leader/06 = a and Leader/07 = d and 999m = LANE-MED' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cad  2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('m', 'LANE-MED')
        ))
      end
    end

    it 'is a Book and not Archive/Manuscript' do
      expect(result[field]).to eq ['Book']
    end
  end

  context 'Leader/06 = a and Leader/07 = c and 999m = LANE-MED' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cac  2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('m', 'LANE-MED')
        ))
      end
    end

    it 'is a Book and not Archive/Manuscript' do
      expect(result[field]).to eq ['Book']
    end
  end

  context 'Leader/06 = t and Leader/07 = d and 999m = LANE-MED' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ctd  2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('m', 'LANE-MED')
        ))
      end
    end

    it 'is a Book and not Archive/Manuscript' do
      expect(result[field]).to eq ['Book']
    end
  end

  context 'Leader/06 = t and Leader/07 = c and 999m = LANE-MED' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ctc  2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('m', 'LANE-MED')
        ))
      end
    end

    it 'is a Book and not Archive/Manuscript' do
      expect(result[field]).to eq ['Book']
    end
  end

  context 'Leader/06 = a and Leader/07 = c and 999m not LANE-MED' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cac  2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    it 'is a Archive/Manuscript' do
      expect(result[field]).to eq ['Archive/Manuscript']
    end
  end

  context 'Leader/06 = t and Leader/07 = c and 999m not LANE-MED' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cac  2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    it 'is a Archive/Manuscript' do
      expect(result[field]).to eq ['Archive/Manuscript']
    end
  end

  context 'Leader/06 not a and not t and Leader/07 = c and 999m = LANE-MED' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c c  2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('m', 'LANE-MED')
        ))
      end
    end

    it 'is has no format' do
      expect(result[field]).to eq ['Other']
    end
  end

  context 'Leader/06 not a and not t and Leader/07 = d and 999m = LANE-MED' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('m', 'LANE-MED')
        ))
      end
    end

    it 'is has no format' do
      expect(result[field]).to eq ['Other']
    end
  end

  context 'Leader/06 = a and Leader/07 not c  and 999m = LANE-MED' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ca   2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('m', 'LANE-MED')
        ))
      end
    end

    it 'is has no format' do
      expect(result[field]).to eq ['Other']
    end
  end

  context 'Leader/06 = t and Leader/07 not c  and 999m = LANE-MED' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ct   2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('m', 'LANE-MED')
        ))
      end
    end

    it 'is has no format' do
      expect(result[field]).to eq ['Other']
    end
  end

  context 'leader/06 b (obsolete) - Archive/Manuscript' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cbd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 v eng d'))
      end
    end

    it 'is an archive/manuscript' do
      expect(result[field]).to eq ['Archive/Manuscript']
    end
  end

  context 'leader/06 p mixed materials) - Archive/Manuscript' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cpd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 v eng d'))
      end
    end

    it 'is an archive/manuscript' do
      expect(result[field]).to eq ['Archive/Manuscript']
    end
  end

#     /* If the call number prefixes in the MARC 999a are for Archive/Manuscript items, add Archive/Manuscript format
#      * A (e.g. A0015), F (e.g. F0110), M (e.g. M1810), MISC (e.g. MISC 1773), MSS CODEX (e.g. MSS CODEX 0335),
#     MSS MEDIA (e.g. MSS MEDIA 0025), MSS PHOTO (e.g. MSS PHOTO 0463), MSS PRINTS (e.g. MSS PRINTS 0417),
#     PC (e.g. PC0012), SC (e.g. SC1076), SCD (e.g. SCD0012), SCM (e.g. SCM0348), and V (e.g. V0321).  However,
#     A, F, M, PC, and V are also in the Library of Congress classification which could be in the 999a, so need to make sure that
#     the call number type in the 999w == ALPHANUM and the library in the 999m == SPEC-COLL.
#      */

  context '???' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'A0015'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('m', 'SPEC-COLL')
        ))
      end
    end

    it 'is an archive/manuscript' do
      expect(result[field]).to eq ['Archive/Manuscript']
    end
  end

  context '???' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'F0110'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('m', 'SPEC-COLL')
        ))
      end
    end

    it 'is an archive/manuscript' do
      expect(result[field]).to eq ['Archive/Manuscript']
    end
  end

  context '???' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'M1810'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('m', 'SPEC-COLL')
        ))
      end
    end

    it 'is an archive/manuscript' do
      expect(result[field]).to eq ['Archive/Manuscript']
    end
  end

  context '???' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'MISC 1773'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('m', 'SPEC-COLL')
        ))
      end
    end

    it 'is an archive/manuscript' do
      expect(result[field]).to eq ['Archive/Manuscript']
    end
  end

  context '???' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'MSS CODEX 0335'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('m', 'SPEC-COLL')
        ))
      end
    end

    it 'is an archive/manuscript' do
      expect(result[field]).to eq ['Archive/Manuscript']
    end
  end

  context '???' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'MSS MEDIA 0025'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('m', 'SPEC-COLL')
        ))
      end
    end

    it 'is an archive/manuscript' do
      expect(result[field]).to eq ['Archive/Manuscript']
    end
  end

  context '???' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'MSS PHOTO 0463'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('m', 'SPEC-COLL')
        ))
      end
    end

    it 'is an archive/manuscript' do
      expect(result[field]).to eq ['Archive/Manuscript']
    end
  end

  context '???' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'MSS PRINTS 0417'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('m', 'SPEC-COLL')
        ))
      end
    end

    it 'is an archive/manuscript' do
      expect(result[field]).to eq ['Archive/Manuscript']
    end
  end

  context '???' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'PC0012'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('m', 'SPEC-COLL')
        ))
      end
    end

    it 'is an archive/manuscript' do
      expect(result[field]).to eq ['Archive/Manuscript']
    end
  end

  context '???' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'SC1076'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('m', 'SPEC-COLL')
        ))
      end
    end

    it 'is an archive/manuscript' do
      expect(result[field]).to eq ['Archive/Manuscript']
    end
  end

  context '???' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'SCD0012'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('m', 'SPEC-COLL')
        ))
      end
    end

    it 'is an archive/manuscript' do
      expect(result[field]).to eq ['Archive/Manuscript']
    end
  end

  context '???' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'SCM0348'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('m', 'SPEC-COLL')
        ))
      end
    end

    it 'is an archive/manuscript' do
      expect(result[field]).to eq ['Archive/Manuscript']
    end
  end

  context '???' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'V0321'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('m', 'SPEC-COLL')
        ))
      end
    end

    it 'is an archive/manuscript' do
      expect(result[field]).to eq ['Archive/Manuscript']
    end
  end

  context '999 ALPHANUM starting with MFLIM  but not SPEC-COLL' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01669nam a2200289ua 4500'
        r.append(MARC::ControlField.new('008', '870715r19741700ctu     a     000 0 eng d'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'MFILM N.S. 1350 REEL 230 NO. 3741'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('i', '001AFX2969'),
          MARC::Subfield.new('l', 'MEDIA-MTXT'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    it 'is a book' do
      expect(result[field]).to eq ['Book']
    end
  end

  context '999 ALPHANUM starting with MFICHE  but not SPEC-COLL' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01879cam a2200409 i 4500'
        r.append(MARC::ControlField.new('008', '101015q20092010fr a    bbm   000 0 fre c'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'MFICHE 3239'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('i', '8729402-1001'),
          MARC::Subfield.new('l', 'MEDIA-MTXT'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    it 'is a book' do
      expect(result[field]).to eq ['Book']
    end
  end

  context '999 ALPHANUM starting with MFICHE and SPEC-COLL' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01879cam a2200409 i 4500'
        r.append(MARC::ControlField.new('008', '101015q20092010fr a    bbm   000 0 fre c'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'MFICHE 3239'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('i', '8729402-1001'),
          MARC::Subfield.new('l', 'MEDIA-MTXT'),
          MARC::Subfield.new('m', 'SPEC-COLL')
        ))
      end
    end

    it 'is a book' do
      expect(result[field]).to eq ['Book']
    end
  end

  context 'manuscript or manuscript/digital in 245h' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 v eng d'))
        r.append(MARC::DataField.new('245', '1', ' ',
          MARC::Subfield.new('a', 'manuscript: 245h'),
          MARC::Subfield.new('h', '[manuscript]')
        ))
      end
    end

    it 'is a manuscript' do
      expect(result[field]).to eq ['Archive/Manuscript']
    end
  end

  context 'manuscript or manuscript/digital in 245h' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 v eng d'))
        r.append(MARC::DataField.new('245', '1', ' ',
          MARC::Subfield.new('a', 'manuscript/digital: 245h'),
          MARC::Subfield.new('h', '[manuscript/digital]')
        ))
      end
    end

    it 'is a manuscript' do
      expect(result[field]).to eq ['Archive/Manuscript']
    end
  end

  context 'leader/06 e - globe' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ced  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 0 eng d'))
      end
    end

    it 'is a map' do
      expect(result[field]).to eq ['Map']
    end
  end

  context 'leader/06 f - globe' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cfd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 0 eng d'))
      end
    end

    it 'is a map' do
      expect(result[field]).to eq ['Map', 'Archive/Manuscript']
    end
  end

  context 'marcit brief record' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '00838cas a2200193z  4500'
        r.append(MARC::DataField.new('590', ' ', ' ',
          MARC::Subfield.new('a', 'MARCit brief record.')
        ))
      end
    end

    it 'is a journal/periodical' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context 'marcit brief record without a period' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '00838cas a2200193z  4500'
        r.append(MARC::DataField.new('590', ' ', ' ',
          MARC::Subfield.new('a', 'MARCit brief record')
        ))
      end
    end

    it 'is a journal/periodical' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context 'wrong string in 590' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '00838cas a2200193z  4500'
        r.append(MARC::DataField.new('590', ' ', ' ',
          MARC::Subfield.new('a', 'incorrect string')
        ))
      end
    end

    it 'is an other' do
      expect(result[field]).to eq ['Other']
    end
  end

  context 'wrong string in 590' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '00838cas a2200193z  4500'
        r.append(MARC::DataField.new('590', ' ', ' ',
          MARC::Subfield.new('a', 'something MARCit something')
        ))
      end
    end

    it 'is an other' do
      expect(result[field]).to eq ['Other']
    end
  end

  context 'marcit in wrong field' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '00838cas a2200193z  4500'
        r.append(MARC::DataField.new('580', ' ', ' ',
          MARC::Subfield.new('a', 'MARCit brief record.')
        ))
      end
    end

    it 'is an other' do
      expect(result[field]).to eq ['Other']
    end
  end

  context '245 h has "microform" - microfilm AND music-score' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952adm  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 v eng d'))
        r.append(MARC::DataField.new('245', '1', ' ',
          MARC::Subfield.new('a', 'microform: 245h'),
          MARC::Subfield.new('c', 'stuff.'),
          MARC::Subfield.new('h', '[microform]'),
        ))
      end
    end

    it 'is an other' do
      expect(result[field]).to eq ['Music/Score', 'Archive/Manuscript']
    end
  end

  context '999 ALPHANUM starting with MFLIM' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01669nam a2200289ua 4500'
        r.append(MARC::ControlField.new('008', '870715r19741700ctu     a     000 0 eng d'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'MFILM N.S. 1350 REEL 230 NO. 3741'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('i', '001AFX2969'),
          MARC::Subfield.new('l', 'MEDIA-MTXT'),
          MARC::Subfield.new('m', 'GREEN'),
        ))
      end
    end

    it 'is an other' do
      expect(result[field]).to eq ['Book']
    end
  end

  context '999 ALPHANUM starting with MFICHE' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01879cam a2200409 i 4500'
        r.append(MARC::ControlField.new('008', '101015q20092010fr a    bbm   000 0 fre c'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'MFICHE 3239'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('i', '8729402-1001'),
          MARC::Subfield.new('l', 'MEDIA-MTXT'),
          MARC::Subfield.new('m', 'GREEN'),
        ))
      end
    end

    it 'is an other' do
      expect(result[field]).to eq ['Book']
    end
  end

  context 'music-audio: leader/06 j' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cjd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 v eng d'))
      end
    end

    it 'is a Music recording' do
      expect(result[field]).to eq ['Music recording']
    end
  end

  context 'leader/06 c - music-score' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ccd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 v eng d'))
      end
    end

    it 'is a Music recording' do
      expect(result[field]).to eq ['Music/Score']
    end
  end

  context 'leader/06 d - music-score' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cdd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 v eng d'))
      end
    end

    it 'is a Music recording' do
      expect(result[field]).to eq ['Music/Score', 'Archive/Manuscript']
    end
  end

  context '245 h has "microform" - microfilm AND music-score' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952adm  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 v eng d'))
        r.append(MARC::DataField.new('245', '1', '0',
          MARC::Subfield.new('a', 'microform: 245h'),
          MARC::Subfield.new('c', 'stuff.'),
          MARC::Subfield.new('h', '[microform]'),
        ))
      end
    end

    it 'is a Music recording' do
      expect(result[field]).to eq ['Music/Score', 'Archive/Manuscript']
    end
  end

  context 'leader/07 s 008/21 n - newspaper' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cas  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu   n       000 v eng d'))
      end
    end

    it 'is a newpaper' do
      expect(result[field]).to eq ['Newspaper']
    end
  end

  context 'leader/07 b, 006/00 s, 006/04 w, 008/21' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cab  2200457Ia 4500'
        r.append(MARC::ControlField.new('006', 's   w    h        '))
        r.append(MARC::ControlField.new('008', '780930m19391944nyu   n       000 v eng d'))
      end
    end

    it 'is a other' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context '502 exists - thesis' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cad  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 v eng d'))
        r.append(MARC::DataField.new('502', ' ', ' ',
          MARC::Subfield.new('a', "dissertation note field; we don't care about the contents")
        ))
      end
    end

    it 'is a other' do
      expect(result[field]).to eq ['Other']
    end
  end

  context 'based on 9366507 - integrating, SFX' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02018cai a2200397Ia 4500'
        r.append(MARC::ControlField.new('008', '120203c20089999enkwr d ob    0    2eng d'))
        r.append(MARC::DataField.new('956', '4', '0', MARC::Subfield.new('u', ' http://library.stanford.edu/sfx?stuff')))
      end
    end

    it 'is a database' do
      expect(result[field]).to eq ['Database']
    end
  end

  context 'based on 6735313 - integrating, no SFX' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01622cai a2200397 a 4500'
        r.append(MARC::ControlField.new('008', '061227c20069999vau x dss    f0    2eng c'))
        r.append(MARC::DataField.new('956', '4', '0', MARC::Subfield.new('u', ' http://library.stanford.edu/sfx?stuff')))
      end
    end

    it 'is a database' do
      expect(result[field]).to eq ['Database']
    end
  end

  context 'based on 6735313 - integrating, no SFX' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01622cai a2200397 a 4500'
        r.append(MARC::ControlField.new('008', '061227c20069999vau x dss    f0    2eng c'))
        r.append(MARC::DataField.new('956', '4', '0', MARC::Subfield.new('u', ' http://library.stanford.edu/sfx?stuff')))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', "INTERNET RESOURCE"),
          MARC::Subfield.new('w', "ASIS"),
          MARC::Subfield.new('i', "2475606-5001"),
          MARC::Subfield.new('l', "INTERNET"),
          MARC::Subfield.new('m', "SUL"),
          MARC::Subfield.new('t', "DATABASE")
        ))
      end
    end

    it 'is a database' do
      expect(result[field].uniq).to eq ['Database']
    end
  end

  context 'based on 8774277 - serial, SFX' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02056cas a2200445Ii 4500'
        r.append(MARC::ControlField.new('008', '101110c20099999nz ar d o    f0    0eng d'))
        r.append(MARC::DataField.new('956', '4', '0', MARC::Subfield.new('u', ' http://library.stanford.edu/sfx?stuff')))
      end
    end

    it 'is a database' do
      expect(result[field].uniq).to eq ['Database']
    end
  end

  context 'serial, no SFX' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01548cas a2200361Ia 4500'
        r.append(MARC::ControlField.new('008', '061227c20069999vau x dss    f0    2eng c'))
      end
    end

    it 'is a database' do
      expect(result[field].uniq).to eq ['Database']
    end
  end

  context 'serial, db a-z' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01548cas a2200361Ia 4500'
        r.append(MARC::ControlField.new('008', '061227c20069999vau x dss    f0    2eng c'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', "INTERNET RESOURCE"),
          MARC::Subfield.new('w', "ASIS"),
          MARC::Subfield.new('i', "2475606-5001"),
          MARC::Subfield.new('l', "INTERNET"),
          MARC::Subfield.new('m', "SUL"),
          MARC::Subfield.new('t', "DATABASE")
        ))
      end
    end

    it 'is a database' do
      expect(result[field].uniq).to eq ['Database']
    end
  end

  context 'based on 7911837 - integrating' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02444cai a2200433 a 4500'
        r.append(MARC::ControlField.new('008', '090205c20089999nyuuu l   b   0   a2eng c'))
      end
    end

    it 'is a Book' do
      expect(result[field]).to eq ['Book']
    end
  end

  context 'based on 7911837 - serial' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02444cas a2200433 a 4500'
        r.append(MARC::ControlField.new('008', '090205c20089999nyuuu l   b   0   a2eng c'))
      end
    end

    it 'is a  serial' do
      expect(result[field]).to eq ['Book']
    end
  end

  context 'based on 10094805 - integrating, SFX' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02015cai a2200385 a 4500'
        r.append(MARC::ControlField.new('008', '130110c20139999enk|| woo     0    2eng  '))
        r.append(MARC::DataField.new('956', '4', '0', MARC::Subfield.new('u', ' http://library.stanford.edu/sfx?stuff')))
      end
    end

    it 'is a  serial' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context 'based on 10094805 - integrating, no SFX' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01548cai a2200361Ia 4500'
        r.append(MARC::ControlField.new('008', '040730d19uu2012dcuar w os   f0    2eng d'))
      end
    end

    it 'is a  serial' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context 'integrating, db a-z' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01548cai a2200361Ia 4500'
        r.append(MARC::ControlField.new('008', '040730d19uu2012dcuar w os   f0    2eng d'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', "INTERNET RESOURCE"),
          MARC::Subfield.new('w', "ASIS"),
          MARC::Subfield.new('i', "2475606-5001"),
          MARC::Subfield.new('l', "INTERNET"),
          MARC::Subfield.new('m', "SUL"),
          MARC::Subfield.new('t', "DATABASE")
        ))
      end
    end

    it 'is a  serial' do
      expect(result[field]).to eq ['Journal/Periodical', 'Database']
    end
  end

  context 'serial, SFX' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02015cas a2200385 a 4500'
        r.append(MARC::ControlField.new('008', '130110c20139999enk|| woo     0    2eng  '))
        r.append(MARC::DataField.new('956', '4', '0', MARC::Subfield.new('u', ' http://library.stanford.edu/sfx?stuff')))
      end
    end

    it 'is a  serial' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context 'serial, no SFX' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01548cas a2200361Ia 4500'
        r.append(MARC::ControlField.new('008', '040730d19uu2012dcuar w os   f0    2eng d'))
      end
    end

    it 'is a  serial' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context 'serial, db a-z' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01548cas a2200361Ia 4500'
        r.append(MARC::ControlField.new('008', '040730d19uu2012dcuar w os   f0    2eng d'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', "INTERNET RESOURCE"),
          MARC::Subfield.new('w', "ASIS"),
          MARC::Subfield.new('i', "2475606-5001"),
          MARC::Subfield.new('l', "INTERNET"),
          MARC::Subfield.new('m', "SUL"),
          MARC::Subfield.new('t', "DATABASE")
        ))
      end
    end

    it 'is a  serial' do
      expect(result[field]).to eq ['Journal/Periodical', 'Database']
    end
  end

  context 'leader/07 b, 006/00 s, 006/04 w, 008/21 n - Other' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cab  2200457Ia 4500'
        r.append(MARC::ControlField.new('006', 's   w    h        '))
        r.append(MARC::ControlField.new('008', '780930m19391944nyu   n       000 v eng d'))
      end
    end

    it 'is a journal' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context 'leader/07 s, no 006, 008/21 w - other (web site)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cas  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu   w       000 v eng d'))
      end
    end

    it 'is a journal' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context 'leader/07 b, 006/00 s, 008/21 w - other (web site)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cab  2200457Ia 4500'
        r.append(MARC::ControlField.new('006', 's   w    h        '))
        r.append(MARC::ControlField.new('008', '780930m19391944nyu   w       000 v eng d'))
      end
    end

    it 'is a journal' do
      expect(result[field]).to eq ['Journal/Periodical']
    end
  end

  context 'based on 9539608 - integrating, SFX' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02085cai a2200325 a 4500'
        r.append(MARC::ControlField.new('008', '111014c20119999enk|| p o     |    2eng c'))
        r.append(MARC::DataField.new('956', '4', '0', MARC::Subfield.new('u', ' http://library.stanford.edu/sfx?stuff')))
      end
    end

    it 'is a book' do
      expect(result[field]).to eq ['Book']
    end
  end

  context 'based on 10182766k - integrating, no SFX' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01579cai a2200337Ia 4500'
        r.append(MARC::ControlField.new('008', '081215c200u9999xx         a        eng d'))
      end
    end

    it 'is a book' do
      expect(result[field]).to eq ['Book']
    end
  end

  context 'integrating, db a-z' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01579cai a2200337Ia 4500'
        r.append(MARC::ControlField.new('008', '081215c200u9999xx         a        eng d'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', "INTERNET RESOURCE"),
          MARC::Subfield.new('w', "ASIS"),
          MARC::Subfield.new('i', "2475606-5001"),
          MARC::Subfield.new('l', "INTERNET"),
          MARC::Subfield.new('m', "SUL"),
          MARC::Subfield.new('t', "DATABASE")
        ))
      end
    end

    it 'is a book' do
      expect(result[field]).to eq ['Book', 'Database']
    end
  end

  context 'serial, SFX' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02085cas a2200325 a 4500'
        r.append(MARC::ControlField.new('008', '111014c20119999enk|| q o     |    2eng c'))
        r.append(MARC::DataField.new('956', '4', '0', MARC::Subfield.new('u', ' http://library.stanford.edu/sfx?stuff')))
      end
    end

    it 'is a book' do
      expect(result[field]).to eq ['Book']
    end
  end

  context 'serial, no SFX' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02085cas a2200325 a 4500'
        r.append(MARC::ControlField.new('008', '111014c20119999enk|| q o     |    2eng c'))
      end
    end

    it 'is a book' do
      expect(result[field]).to eq ['Book']
    end
  end

  context 'serial, db a-z' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02085cas a2200325 a 4500'
        r.append(MARC::ControlField.new('008', '111014c20119999enk|| q o     |    2eng c'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', "INTERNET RESOURCE"),
          MARC::Subfield.new('w', "ASIS"),
          MARC::Subfield.new('i', "2475606-5001"),
          MARC::Subfield.new('l', "INTERNET"),
          MARC::Subfield.new('m', "SUL"),
          MARC::Subfield.new('t', "DATABASE")
        ))
      end
    end

    it 'is a book' do
      expect(result[field]).to eq ['Book', 'Database']
    end
  end

  context 'leader/06 g 008/33 f - Video' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000  f eng d'))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'leader/06 g 008/33 m - Video' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000  m eng d'))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'leader/06 g 008/33 v - Video' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000  v eng d'))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'leader/06 g 008/33 | - Video' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000  | eng d'))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'leader/06 g 008/33 blank - Video' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000   eng d'))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'leader/06 g 008/33 0 - Video' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 0 eng d'))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'leader/06 g 008/33 1 - Video' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 1 eng d'))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'leader/06 g 008/33 2 - Video' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 2 eng d'))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'leader/06 g 008/33 3 - Video' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 3 eng d'))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'leader/06 g 008/33 4 - Video' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 4 eng d'))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'leader/06 g 008/33 5 - Video' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 5 eng d'))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'leader/06 g 008/33 6 - Video' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 6 eng d'))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'leader/06 g 008/33 7 - Video' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 7 eng d'))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'leader/06 g 008/33 8 - Video' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 8 eng d'))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'leader/06 g 008/33 9 - Video' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 9 eng d'))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  #     /* Ignore capitalization variations and punctuation variations (this includes cases where the square brackets are not present,
  #      *  where one square bracket is not present, where there is punctuation inside or outside the brackets, where parentheses are
  #      *  used instead of square brackets, etc.)
  #      * 245h contains [videorecording], [video recording], [videorecordings], [video recordings],
  #      * 	[motion picture], [filmstrip], [VCD-DVD], [videodisc], and [videocassette]
  #      */
  context 'videorecording' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', '0',
          MARC::Subfield.new('a', 'videorecording: 245h'),
          MARC::Subfield.new('h', '[videorecording]'),
        ))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'video recording' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', '0',
          MARC::Subfield.new('a', 'video recording: 245h'),
          MARC::Subfield.new('h', '[video recording]'),
        ))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end
  context 'videorecording' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', '0',
          MARC::Subfield.new('a', 'videorecordings: 245h'),
          MARC::Subfield.new('h', '[videorecordings]'),
        ))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'video recording' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', '0',
          MARC::Subfield.new('a', 'video recordings: 245h'),
          MARC::Subfield.new('h', '[video recordings]'),
        ))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'motion picture' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', '0',
          MARC::Subfield.new('a', 'motion picture: 245h'),
          MARC::Subfield.new('h', '[motion picture]'),
        ))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'filmstrip' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', '0',
          MARC::Subfield.new('a', 'filmstrip: 245h'),
          MARC::Subfield.new('h', '[filmstrip]'),
        ))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'VCD-DVD' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', '0',
          MARC::Subfield.new('a', 'VCD-DVD: 245h'),
          MARC::Subfield.new('h', '[VCD-DVD]'),
        ))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'videodisc' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', '0',
          MARC::Subfield.new('a', 'videodisc: 245h'),
          MARC::Subfield.new('h', '[videodisc]'),
        ))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'videocassette' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::DataField.new('245', '1', '0',
          MARC::Subfield.new('a', 'videocassette: 245h'),
          MARC::Subfield.new('h', '[videocassette]'),
        ))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context 'leader/06 t 008/33 w - other' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ctb  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 w eng d'))
      end
    end

    it 'is an other' do
      expect(result[field]).to eq ['Other']
    end
  end
  context 'leader/06 k 008/33 w - other' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952ckd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 w eng d'))
      end
    end

    it 'is an other' do
      expect(result[field]).to eq ['Other']
    end
  end

  context 'leader/06 g 008/33 w - other' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cgd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 w eng d'))
      end
    end

    it 'is an other' do
      expect(result[field]).to eq ['Other']
    end
  end

  context 'instructional kit leader/06 o' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952cod  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 v eng d'))
      end
    end

    it 'is an other' do
      expect(result[field]).to eq ['Other']
    end
  end

  context 'leader/06 r' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952crd  2200457Ia 4500'
        r.append(MARC::ControlField.new('008', '780930m19391944nyu           000 v eng d'))
      end
    end

    it 'is a 3D Object' do
      expect(result[field]).to eq ['Object']
    end
  end

  context '245h [kit], 007/00 a -> Map/Globe' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::ControlField.new('007', 'ao cg|||||||||'))
        r.append(MARC::DataField.new('245', '1', '0',
          MARC::Subfield.new('a', 'kit: 245h'),
          MARC::Subfield.new('h', '[kit]'),
        ))
      end
    end

    it 'is a Map/Globe' do
      expect(result[field]).to eq ['Map']
    end
  end

  context '245h [kit], 007/00 c -> Software/Multimedia' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::ControlField.new('007', 'co cg|||||||||'))
        r.append(MARC::DataField.new('245', '1', '0',
          MARC::Subfield.new('a', 'kit: 245h'),
          MARC::Subfield.new('h', '[kit]'),
        ))
      end
    end

    it 'is a Software/Multimedia' do
      expect(result[field]).to eq ['Software/Multimedia']
    end
  end

  context '245h [kit], 007/00 d -> Map/Globe' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::ControlField.new('007', 'do cg|||||||||'))
        r.append(MARC::DataField.new('245', '1', '0',
          MARC::Subfield.new('a', 'kit: 245h'),
          MARC::Subfield.new('h', '[kit]'),
        ))
      end
    end

    it 'is a Map/Globe' do
      expect(result[field]).to eq ['Map']
    end
  end

  context '245h [kit], 007/00 g -> Video' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::ControlField.new('007', 'go cg|||||||||'))
        r.append(MARC::DataField.new('245', '1', '0',
          MARC::Subfield.new('a', 'kit: 245h'),
          MARC::Subfield.new('h', '[kit]'),
        ))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context '245h [kit], 007/00 k -> Image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::ControlField.new('007', 'ko cg|||||||||'))
        r.append(MARC::DataField.new('245', '1', '0',
          MARC::Subfield.new('a', 'kit: 245h'),
          MARC::Subfield.new('h', '[kit]'),
        ))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context '245h [kit], 007/00 m -> Video' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::ControlField.new('007', 'mo cg|||||||||'))
        r.append(MARC::DataField.new('245', '1', '0',
          MARC::Subfield.new('a', 'kit: 245h'),
          MARC::Subfield.new('h', '[kit]'),
        ))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context '245h [kit], 007/00 q -> Music score' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::ControlField.new('007', 'qo cg|||||||||'))
        r.append(MARC::DataField.new('245', '1', '0',
          MARC::Subfield.new('a', 'kit: 245h'),
          MARC::Subfield.new('h', '[kit]'),
        ))
      end
    end

    it 'is a music score' do
      expect(result[field]).to eq ['Music/Score']
    end
  end

  context '245h [kit], 007/00 r -> Image' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::ControlField.new('007', 'ro cg|||||||||'))
        r.append(MARC::DataField.new('245', '1', '0',
          MARC::Subfield.new('a', 'kit: 245h'),
          MARC::Subfield.new('h', '[kit]'),
        ))
      end
    end

    it 'is an image' do
      expect(result[field]).to eq ['Image']
    end
  end

  context '245h [kit], 007/00 s -> Sound recording' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::ControlField.new('007', 'so cg|||||||||'))
        r.append(MARC::DataField.new('245', '1', '0',
          MARC::Subfield.new('a', 'kit: 245h'),
          MARC::Subfield.new('h', '[kit]'),
        ))
      end
    end

    it 'is a sound recording' do
      expect(result[field]).to eq ['Sound Recording']
    end
  end

  context '245h [kit], 007/00 v -> Video' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::ControlField.new('007', 'vo cg|||||||||'))
        r.append(MARC::DataField.new('245', '1', '0',
          MARC::Subfield.new('a', 'kit: 245h'),
          MARC::Subfield.new('h', '[kit]'),
        ))
      end
    end

    it 'is a video' do
      expect(result[field]).to eq ['Video']
    end
  end

  context '245h [kit], 007/00 z -> Nothing so Other' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01952c d  2200457Ia 4500'
        r.append(MARC::ControlField.new('007', 'zo cg|||||||||'))
        r.append(MARC::DataField.new('245', '1', '0',
          MARC::Subfield.new('a', 'kit: 245h'),
          MARC::Subfield.new('h', '[kit]'),
        ))
      end
    end

    it 'is Nothing so Other' do
      expect(result[field]).to eq ['Other']
    end
  end
end
