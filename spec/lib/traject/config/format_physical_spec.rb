RSpec.describe 'Format physical config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end
  subject(:result) { indexer.map_record(record) }
  let(:field) { 'format_physical_ssim'}

  context 'with 007/00 = m (Film)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01103cem a22002777a 4500'
        r.append(MARC::ControlField.new('007', 'm'))
      end
    end

    it 'is a film' do
      expect(result[field]).to eq ['Film']
    end
  end

  context 'with 007/00 = g (insufficient to determine format)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01103cem a22002777a 4500'
        r.append(MARC::ControlField.new('007', 'g'))
      end
    end

    it 'is a undetermined' do
      expect(result[field]).to eq nil
    end
  end

  context 'with 007/00 = hb (microfilm)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01103cem a22002777a 4500'
        r.append(MARC::ControlField.new('007', 'hb'))
      end
    end

    it 'is a microfilm' do
      expect(result[field]).to eq ['Microfilm']
    end
  end

  context '007/00 = s, access = At Library, 007/01 = d but length = 2' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01103cem a22002777a 4500'
        r.append(MARC::ControlField.new('007', 'sd'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'F152 .A28'),
          MARC::Subfield.new('w', 'LC'),
          MARC::Subfield.new('i', '36105018746623'),
          MARC::Subfield.new('l', 'HAS-DIGIT'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    it 'has a 007 that is too short to have a format_physical_ssim' do
      expect(result[field]).to eq nil
    end
  end

  context '007/00 = s, access = At Library, 007/01 = d, 007/03 = f' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01103cem a22002777a 4500'
        r.append(MARC::ControlField.new('007', 'sd f'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'F152 .A28'),
          MARC::Subfield.new('w', 'LC'),
          MARC::Subfield.new('i', '36105018746623'),
          MARC::Subfield.new('l', 'HAS-DIGIT'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    it 'is a CD' do
      expect(result[field]).to eq ['CD']
    end
  end

  context '007/00 = s, access = At Library, 007/01 = d, 007/03 = f' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01103cem a22002777a 4500'
        r.append(MARC::ControlField.new('007', 's     j'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'F152 .A28'),
          MARC::Subfield.new('w', 'LC'),
          MARC::Subfield.new('i', '36105018746623'),
          MARC::Subfield.new('l', 'HAS-DIGIT'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    it 'is an Audiocassette' do
      expect(result[field]).to eq ['Audiocassette']
    end
  end

  context '007/00 = s, access = At Library, 007/01 = d, 007/03 = blank' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01103cem a22002777a 4500'
        r.append(MARC::ControlField.new('007', 'sd    j'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'F152 .A28'),
          MARC::Subfield.new('w', 'LC'),
          MARC::Subfield.new('i', '36105018746623'),
          MARC::Subfield.new('l', 'HAS-DIGIT'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    it 'is undetermined' do
      expect(result[field]).to eq nil
    end
  end

  context '007/00 = s, 007/01 = d, 007/03 = f but  access != At Library' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01103cem a22002777a 4500'
        r.append(MARC::ControlField.new('007', 'sd    j'))
      end
    end

    it 'is undetermined' do
      expect(result[field]).to eq nil
    end
  end

  context 'with 007/00 = v (insufficient)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01103cem a22002777a 4500'
        r.append(MARC::ControlField.new('007', 'v'))
      end
    end

    it 'is a undetermined' do
      expect(result[field]).to eq nil
    end
  end

  context 'with 007/00 = v and 007/04 = blank (other video)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01103cem a22002777a 4500'
        r.append(MARC::ControlField.new('007', 'v    '))
      end
    end

    it 'is an other video' do
      expect(result[field]).to eq ['Other video']
    end
  end

  context 'with 007/00 = v and 007/04 = g' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01103cem a22002777a 4500'
        r.append(MARC::ControlField.new('007', 'v   g'))
      end
    end

    it 'is a laser disc' do
      expect(result[field]).to eq ['Laser disc']
    end
  end

  context 'with an empty 007' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01103cem a22002777a 4500'
        r.append(MARC::ControlField.new('007', ''))
      end
    end

    it 'is undetermined' do
      expect(result[field]).to eq nil
    end
  end

  context 'with no 007' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01103cem a22002777a 4500'
      end
    end

    it 'is undetermined' do
      expect(result[field]).to eq nil
    end
  end

  context 'with no 007, but a 538' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01103cem a22002777a 4500'
        r.append(MARC::DataField.new('538', ' ', ' ', MARC::Subfield.new('a', 'DVD')))
      end
    end

    it 'is a DVD' do
      expect(result[field]).to eq ['DVD']
    end
  end


  context 'with some garbage in the 007' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01291cgm a2200289 a 4500'
        r.append(MARC::ControlField.new('007', 'gd|cu  jc'))
      end
    end

    it 'is a DVD' do
      expect(result[field]).to eq nil
    end
  end

  context 'with 007/00 = gs' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01291cgm a2200289 a 4500'
        r.append(MARC::ControlField.new('007', 'gs|cu  jc'))
      end
    end

    it 'is a slide' do
      expect(result[field]).to eq ['Slide']
    end
  end

  context 'when the 300a contains slide' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01291cgm a2200289 a 4500'
        r.append(MARC::DataField.new('300', ' ', ' ',
          MARC::Subfield.new('a', '1 pair of stereoscopic slides +'),
          MARC::Subfield.new('e', 'legend and diagram.')
        ))
      end
    end

    it 'is a slide' do
      expect(result[field]).to eq ['Slide']
    end
  end

#   /**
#    *  Spec (per Vitus 2013-11, email to gryph-search with Excel spreadsheet attachment):
#    *   (007/00 = k AND  007/01 = h)  OR  300a contains "photograph"
#    */

  context 'with 007/00 = kj boo' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01427ckm a2200265 a 4500'
        r.append(MARC::ControlField.new('007', 'kj boo'))
      end
    end

    it 'is a undetermined' do
      expect(result[field]).to eq nil
    end
  end

  context 'with 007/00 = kh boo' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01427ckm a2200265 a 4500'
        r.append(MARC::ControlField.new('007', 'kh boo'))
      end
    end

    it 'is a photo' do
      expect(result[field]).to eq ['Photo']
    end
  end

  context 'when the 300a contains photograph' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01291cgm a2200289 a 4500'
        r.append(MARC::DataField.new('300', ' ', ' ',
          MARC::Subfield.new('a', '1 photograph (1 leaf).')
        ))
      end
    end

    it 'is a photo' do
      expect(result[field]).to eq ['Photo']
    end
  end

#   /**
#    *  Spec (per Vitus 2013-11, email to gryph-search with Excel spreadsheet attachment):
#    *   (007/00 = r)  OR  300a contains "remote-sensing image"
#    */
  context 'with 007/00 = r' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01103cem a22002777a 4500'
        r.append(MARC::ControlField.new('007', 'r  uuuuuuuu'))
      end
    end

    it 'is a remote sensing image' do
      expect(result['format_main_ssim']).to eq ['Map']
      expect(result[field]).to eq ['Remote-sensing image']
    end
  end

  context 'when the 300a contains remote sensing image (without hyphens)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01103cem a22002777a 4500'
        r.append(MARC::DataField.new('300', ' ', ' ',
          MARC::Subfield.new('a', '1 remote sensing image ;')
        ))
      end
    end

    it 'is a remote sensing image' do
      expect(result[field]).to eq ['Remote-sensing image']
    end
  end

  context 'when the 300a contains remote-sensing image  (with hyphen)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01103cem a22002777a 4500'
        r.append(MARC::DataField.new('300', ' ', ' ',
          MARC::Subfield.new('a', 'remote-sensing images; ')
        ))
      end
    end

    it 'is a remote sensing image' do
      expect(result[field]).to eq ['Remote-sensing image']
    end
  end

  context 'based on 8833535' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02229cjm a2200409Ia 4500'
        r.append(MARC::ControlField.new('007', 'sd fungnnmmneu'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'F152 .A28'),
          MARC::Subfield.new('w', 'LC'),
          MARC::Subfield.new('i', '36105018746623'),
          MARC::Subfield.new('l', 'HAS-DIGIT'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    it 'is a CD' do
      expect(result[field]).to eq ['CD']
    end
  end

  context 'based on 8833535, but online' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02229cjm a2200409Ia 4500'
        r.append(MARC::ControlField.new('007', 'sd fungnnmmneu'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'INTERNET RESOURCE'),
          MARC::Subfield.new('w', 'ASIS'),
          MARC::Subfield.new('i', '2475606-5001'),
          MARC::Subfield.new('l', 'INTERNET'),
          MARC::Subfield.new('m', 'SUL')
        ))
      end
    end

    it 'is not a CD, since it is online-only' do
      expect(result[field]).to eq nil
    end
  end

  context '007 but byte 3 is z   (Other)  (based on 5665607)    think there are about 1600 of these' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02229cjm a2200409Ia 4500'
        r.append(MARC::ControlField.new('007', 'sd zsngnnmmned'))
        r.append(MARC::DataField.new('300', ' ', ' ',
          MARC::Subfield.new('a', '1 sound disc :'),
          MARC::Subfield.new('b', 'digital ;'),
          MARC::Subfield.new('c', '4 3/4 in.')
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

    it 'is a CD' do
      expect(result[field]).to eq ['CD']
    end
  end

  context 'no 007, but 300  (based on 314009)  think there are about 1800 of these' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02229cjm a2200409Ia 4500'
        r.append(MARC::ControlField.new('007', 'sd zsngnnmmned'))
        r.append(MARC::DataField.new('300', ' ', ' ',
          MARC::Subfield.new('a', '1 sound disc :'),
          MARC::Subfield.new('b', 'digital ;'),
          MARC::Subfield.new('c', '4 3/4 in.')
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

    it 'is a CD' do
      expect(result[field]).to eq ['CD']
    end
  end

  context 'it looks in 300-field descriptions to find things that are CDs' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02229cjm a2200409Ia 4500'
        r.append(MARC::DataField.new('300', ' ', ' ',
          MARC::Subfield.new('a', field_value)
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

    [
      "1 sound disc (1 hr., 1 min.) : digital, stereo. ; 4 3/4 in.",
      "1 sound disc (1:06:59) : digital, stereo. ; 4 3/4 in. + pamphlet.",
      "1 sound disc (39:46) : digital, stereo. ; 4 3/4 in.",
      "1 sound disc (40 min., 29 sec.) : digital, stereo. ; 4 3/4 in.",
      "1 sound disc (43 min.) : digital, stereo. ; 4 3/4 in. + pamphlet.",
      "1 sound disc (43 min.) : digital, stereo. ; 4 3/4 in.",
      "1 sound disc (44 min.) digital, stereo. ; 4 3/4 in.",
      "1 sound disc (51 min.) : digital. ; 4 3/4 in.",
      "1 sound disc (68:57 min.) : digital, analog ; 4 3/4 in.",
      "1 sound disc : digital ; 4 3/4 in.",
      "1 sound disc : digital, 4 3/4 in.",
      "1 sound disc : digital, chiefly mono. ; 4 3/4 in.",
      "1 sound disc : digital, monaural ; 4 3/4 in. + pamphlet.",
      "1 sound disc : digital, mono. ; 4 3/4 in.",
      "1 sound disc : digital, stereo ; 4 3/4 in.",
      "1 sound disc : digital, stereo. 4 3/4 in.",
      "1 sound disc : digital, stereo. ; 4 3/4 in. + booklet.",
      "1 sound disc : digital, stereo. ; 4 3/4 in. + pamphlet.",
      "1 sound disc : digital, stereo. ; 4 3/4 in.",
      "2 sound discs : digital ; 4 3/4 in.",
      "2 sound discs : digital, stereo. ; 4 3/4 in.",
      "2 sound discs : digital, stereo., HJ ; 4 3/4 in.",
      "1 sound disc (ca. 1 hr. 6 min.) : digital, stereo. ; 4 3/4 in.",
      "3 sound discs (ca. 151 min.) : digital ; 4 3/4 in.",
      "3 sound discs (ca. 2 hrs., 56 min.) : digital, stereo. ; 4 3/4 in. + 1 booklet (147 p.).",
      "1 sound disc : digital, mono. ; c 4 3/4in.",
      "1 sound disc ; 4 3/4 in.",
      "1 compact sound disc : digital, stereo. ; 4 3/4 in.",
      #     // look!  centimeters
      "1 sound disc : digital, mono. ; 12 cm.",
      "2 sound discs : digital, mono. ; 12 cm.",
      "1 sound disc : digital ; 12 cm.",
      #     // audio disc not sound disc
      "2 audio discs : digital, CD audio ; 4 3/4 in.",
      "1 audio disc : digital, CD audio, 4 3/4 in.",
      "1 audio disc : digital, CD audio, mono ; 4 3/4 in.",
      #     // CD audio, not digital
      "1 audio disc : 4 3/4 in.",
      "1 audio disc : CD audio ; 4 3/4 in.",
      "1 audio disc : CD audio, 4 3/4 in.",
      "1 audio disc : CD-R, 4 3/4 in.",
      "1 audio disc : CD-R, CD audio ; 4 3/4 in.",
      "1 audio disc : digital ; 4 3/4 in.",
      "1 audio disc : digital, CD audio ; 4 3/4 in.",
      "1 audio disc : digital, CD audio, 4 3/4 in.",
      "1 audio disc : digital, CD audio, mono ; 4 3/4 in."
    ].each do |f300_values|
      context "with #{f300_values}" do
        let(:field_value) { f300_values }

        it 'is a CD' do
          expect(result[field]).to eq ['CD']
        end
      end
    end

    [
      "1 sound disc (6 hr.) : DVD audio, digital ; 4 3/4 in.",
      "1 sound disc : digital, DVD ; 4 3/4 in.",
      "1 sound disc : digital, DVD audio ; 4 3/4 in.",
      "1 sound disc : digital, DVD audio; 4 3/4 in.",
      "1 sound disc : digital, SACD ; 4 3/4 in. + 1 BluRay audio disc.",
      "1 online resource (1 sound file)",
      "2s. 12in. 33.3rpm.",
      "1 sound disc : 33 1/3 rpm, stereo ; 12 in.",
      "1 sound disc : analog, 33 1/3 rpm, stereo. ; 12 in.",
      "1 sound disc : 33 1/3 rpm ; 12 in.",
      "1 sound disc (47 min) : analog, 33 1/3 rpm., stereo. ; 12 in."
    ].each do |f300_values|
      context "with #{f300_values}" do
        let(:field_value) { f300_values }

        it 'is not a CD' do
          expect(result[field] || []).not_to include 'CD'
        end
      end
    end
  end

  context 'recording 78' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01002cjm a2200313Ma 4500'
        r.append(MARC::ControlField.new('007', 'sd dmsdnnmslne'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'F152 .A28'),
          MARC::Subfield.new('w', 'LC'),
          MARC::Subfield.new('i', '36105018746623'),
          MARC::Subfield.new('l', 'HAS-DIGIT'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    it 'is a shellac 78' do
      expect(result[field]).to eq ['78 rpm (shellac)']
    end
  end

  context 'recording 78, but online' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01002cjm a2200313Ma 4500'
        r.append(MARC::ControlField.new('007', 'sd dmsdnnmslne'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'INTERNET RESOURCE'),
          MARC::Subfield.new('w', 'ASIS'),
          MARC::Subfield.new('i', '2475606-5001'),
          MARC::Subfield.new('l', 'INTERNET'),
          MARC::Subfield.new('m', 'SUL')
        ))
      end
    end

    it 'is no longer a shellac 78' do
      expect(result[field]).to eq nil
    end
  end

  context 'based on 309570' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02683cjm a2200565ua 4500'
        r.append(MARC::ControlField.new('007', 'sdubsmennmplue'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'F152 .A28'),
          MARC::Subfield.new('w', 'LC'),
          MARC::Subfield.new('i', '36105018746623'),
          MARC::Subfield.new('l', 'HAS-DIGIT'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    it 'is a vinyl' do
      expect(result[field]).to eq ['Vinyl disc']
    end
  end

  context 'based on 309570, but online' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02683cjm a2200565ua 4500'
        r.append(MARC::ControlField.new('007', 'sdubsmennmplue'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'INTERNET RESOURCE'),
          MARC::Subfield.new('w', 'ASIS'),
          MARC::Subfield.new('i', '2475606-5001'),
          MARC::Subfield.new('l', 'INTERNET'),
          MARC::Subfield.new('m', 'SUL')
        ))
      end
    end

    it 'is no longer a vinyl' do
      expect(result[field]).to eq nil
    end
  end

  context 'no 007, but 300 (based on 6594)   there are 873 of these, with this exact 300 value' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02683cjm a2200565ua 4500'
        r.append(MARC::DataField.new('300', ' ', ' ',
          MARC::Subfield.new('a', '2s. 12in. 33.3rpm.'),
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

    it 'is a vinyl' do
      expect(result[field]).to eq ['Vinyl disc']
    end
  end

  context 'no 007, but 300 (based on 307863) 500 with approx this 300 value' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02683cjm a2200565ua 4500'
        r.append(MARC::DataField.new('300', ' ', ' ',
          MARC::Subfield.new('a', '1 sound disc :'),
          MARC::Subfield.new('b', 'analog, 33 1/3 rpm, stereo. ;'),
          MARC::Subfield.new('c', '12 in.')
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

    it 'is a vinyl' do
      expect(result[field]).to eq ['Vinyl disc']
    end
  end

  context 'it looks in 300-field descriptions to find things that are vinyls' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '02683cjm a2200565ua 4500'
        r.append(MARC::DataField.new('300', ' ', ' ',
          MARC::Subfield.new('a', field_value)
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

    [
      "1 disc.  33 1/3 rpm. stereo. 12 in.",
      "1 disc.  33.3 rpm. stereo. 12 in.",
      "1 disc. 33 1/3 rpm.  quad. 12 in.",
      "1 disc. 33 1/3 rpm. 12 in.",
      "1 disc. 33 1/3 rpm. quad. 12 in.",
      "1 disc. 33 1/3 rpm. stereo. 12 in.",
      "1 s.  12 in.  33 1/3 rpm.  stereophonic.",
      "1 s. 12 in. 33 1/3 rpm. microgroove.",
      "1 sound disc (38 min.) : 33 1/3 rpm, mono. ; 12 in.",
      "1 sound disc : 33 1/3 rpm ; 12 in. + insert.",
      "1 sound disc : 33 1/3 rpm ; 12 in.",
      "1 sound disc : 33 1/3 rpm, ; 12 in.",
      "1 sound disc : 33 1/3 rpm, monaural ; 12 in.",
      "1 sound disc : 33 1/3 rpm, stereo ; 12 in. + insert ([4] p.)",
      "1 sound disc : 33 1/3 rpm, stereo. ; 12 in.",
      "1 sound disc : analog, 33 1/3 rpm ; 12 in.",
      "1 sound disc : analog, 33 1/3 rpm, mono. ; 12 in.",
      "1 sound disc : analog, 33 1/3 rpm, stereo ; 12 in.",
      "1 sound disc : analog, 33 1/3 rpm, stereo. ; 12 in. + insert.",
      "1 sound disc analog, 33 1/3 rpm, stereo. ; 12 in.",
      "1 sound disc: analog, stereo, 33 1/3 rpm, 12 in.",
      "1-1/4s. 12in. 33.3rpm.",
      "1/2 s. 12in. 33.3rpm. stereophonic.",
      "1/2 s. 33 1/3 rpm. stereophonic. 12 in.",
      "1/3s. 12in.  33.3rpm. stereophonic.",
      "1/6s. 12in. 33.3rpm.",
      "10s. 12in. 33.3rpm.",
      "1s. 10in. 33.3rpm.",
      "1s. 12in. 33.3rpm.",
      "2 discs. 33 1/3 rpm.  stereo. 12 in.",
      "2 discs. 33 1/3 rpm. stereo. 12 in.",
      "2 s.  12 in.  33 1/3 rpm.  microgroove.  stereophonic.",
      "2 s.  12 in.  33 1/3 rpm. stereophonic.",
      "2 s. 12 in. 33.3 rpm.",
      "2s.  12in.  33 1/3rpm. stereophonic.",
      "2s. 12in. 33 1/3rpm. stereophonic.",
      "3 discs. 33 1/3 rpm.  stereo. 12 in.",
      "4s.  12in.  33.3rpm. stereophonic.",
      "4s. 12in. 33.3rpm. stereophonic.",
      "5 sound discs : 33 1/3 rpm ; 12 in.",
      "on side 1 of 1 disc. 33 1/3 rpm. stereo. 12 in.",
    ].each do |f300_values|
      context "with #{f300_values}" do
        let(:field_value) { f300_values }

        specify { expect(result[field]).to eq ['Vinyl disc'] }
      end
    end

    [
      "1 sound disc : digital ; 4 3/4 in.",
      "1 sound disc : digital, stereo. ; 4 3/4 in.",
      "1 videodisc (133 min.) : sd., col. ; 4 3/4 in.",
      "1 score (18 p.) ; 22 x 28 cm. + 4 parts ; 33 cm. + 1 sound disc (digital ; 4 3/4 in.)",
      "1 sound disc (33 min.) : digital, stereo. ; 4 3/4 in.",
      "1 sound disc (6 hr.) : DVD audio, digital ; 4 3/4 in.",
      "1 sound disc : digital, DVD ; 4 3/4 in.",
      "1 sound disc : digital, DVD audio ; 4 3/4 in.",
      "1 sound disc : digital, DVD audio; 4 3/4 in.",
      "1 sound disc : digital, SACD ; 4 3/4 in. + 1 BluRay audio disc.",
      "1 online resource (1 sound file)"
    ].each do |f300_values|
      context "with #{f300_values}" do
        let(:field_value) { f300_values }

        specify { expect(result[field] || []).not_to include 'Vinyl disc' }
      end
    end
  end

  context 'with 007: based on 4730355' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01205cim a2200337Ia 4500'
        r.append(MARC::ControlField.new('007', 'ss lunjlc-----'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'F152 .A28'),
          MARC::Subfield.new('w', 'LC'),
          MARC::Subfield.new('i', '36105018746623'),
          MARC::Subfield.new('l', 'HAS-DIGIT'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    it 'is a cassette' do
      expect(result[field]).to eq ['Audiocassette']
    end
  end

  context 'with 007: based on 4730355 not if online only' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01205cim a2200337Ia 4500'
        r.append(MARC::ControlField.new('007', 'ss lunjlc-----'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'INTERNET RESOURCE'),
          MARC::Subfield.new('w', 'ASIS'),
          MARC::Subfield.new('i', '2475606-5001'),
          MARC::Subfield.new('l', 'INTERNET'),
          MARC::Subfield.new('m', 'SUL')
        ))
      end
    end

    it 'is undetermined' do
      expect(result[field]).to eq nil
    end
  end

#   /**
#    *  Spec (per Vitus 2013-11, email to gryph-search with Excel spreadsheet attachment):
#    *   (007/00 = h AND  007/01 = b,c,d,h or j)  OR  300a contains "microfilm"
#    *    Naomi addition:  OR  if  callnum.startsWith("MFILM")
#    *    Question:  (what if 245h has "microform" -- see 9646614 for example)
#    */
  context 'with a 007/01 that is not correct for Microfilm' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01543cam a2200325Ka 4500'
        r.append(MARC::ControlField.new('007', 'ha afu   buca'))
      end
    end

    it 'is undetermined' do
      expect(result[field]).to eq nil
    end
  end

  context 'with 007/01 - b' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01543cam a2200325Ka 4500'
        r.append(MARC::ControlField.new('007', 'hb afu   buca'))
      end
    end

    it 'is a microfilm' do
      expect(result[field]).to eq ['Microfilm']
    end
  end

  context 'with 007/01 - c' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01543cam a2200325Ka 4500'
        r.append(MARC::ControlField.new('007', 'hc afu   buca'))
      end
    end

    it 'is a microfilm' do
      expect(result[field]).to eq ['Microfilm']
    end
  end

  context 'with 007/01 - d' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01543cam a2200325Ka 4500'
        r.append(MARC::ControlField.new('007', 'hd afu   buca'))
      end
    end

    it 'is a microfilm' do
      expect(result[field]).to eq ['Microfilm']
    end
  end

  context 'with 007/01 - h' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01543cam a2200325Ka 4500'
        r.append(MARC::ControlField.new('007', 'hh afu   buca'))
      end
    end

    it 'is a microfilm' do
      expect(result[field]).to eq ['Microfilm']
    end
  end

  context 'with 007/01 - j' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01543cam a2200325Ka 4500'
        r.append(MARC::ControlField.new('007', 'hj afu   buca'))
      end
    end

    it 'is a microfilm' do
      expect(result[field]).to eq ['Microfilm']
    end
  end

  context 'with a callnum in 999' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01543cam a2200325Ka 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'MFILM N.S. 17443'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('i', '9636901-1001'),
          MARC::Subfield.new('l', 'MEDIA-MTXT'),
          MARC::Subfield.new('m', 'GREEN'),
          MARC::Subfield.new('t', 'NH-MICR')
        ))
      end
    end

    it 'is a microfilm' do
      expect(result[field]).to eq ['Microfilm']
    end
  end

  context 'when the 300a contains microfilm' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01543cam a2200325Ka 4500'
        r.append(MARC::DataField.new('300', ' ', ' ',
          MARC::Subfield.new('a', '21 microfilm reels ;')
        ))
      end
    end

    it 'is a microfilm' do
      expect(result[field]).to eq ['Microfilm']
    end
  end

#   /**
#    *  Spec (per Vitus 2013-11, email to gryph-search with Excel spreadsheet attachment):
#    *   (007/00 = h AND  007/01 = e,f or g)  OR  300a contains "microfiche"
#    *    Naomi addition:  OR  if  callnum.startsWith("MFICHE")
#    *    Question:  (what if 245h has "microform" -- see 9646614 for example)
#    */
  context 'with a 007/01 that is not correct for Microfilm' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01543cam a2200325Ka 4500'
        r.append(MARC::ControlField.new('007', 'ha afu   buca'))
      end
    end

    it 'is undetermined' do
      expect(result[field]).to eq nil
    end
  end

  context 'with 007/01 - e' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01543cam a2200325Ka 4500'
        r.append(MARC::ControlField.new('007', 'he bmb024bbca'))
      end
    end

    it 'is a microfiche' do
      expect(result[field]).to eq ['Microfiche']
    end
  end

  context 'with 007/01 - f' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01543cam a2200325Ka 4500'
        r.append(MARC::ControlField.new('007', 'hf bmb024bbca'))
      end
    end

    it 'is a microfiche' do
      expect(result[field]).to eq ['Microfiche']
    end
  end

  context 'with 007/01 - g' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01543cam a2200325Ka 4500'
        r.append(MARC::ControlField.new('007', 'hg bmb024bbca'))
      end
    end

    it 'is a microfiche' do
      expect(result[field]).to eq ['Microfiche']
    end
  end

  context 'with a callnum in 999' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01543cam a2200325Ka 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'MFICHE 1183 N.5.1.7205'),
          MARC::Subfield.new('w', 'ALPHANUM'),
          MARC::Subfield.new('i', '9636901-1001'),
          MARC::Subfield.new('l', 'MEDIA-MTXT'),
          MARC::Subfield.new('m', 'GREEN'),
          MARC::Subfield.new('t', 'NH-MICR')
        ))
      end
    end

    it 'is a microfiche' do
      expect(result[field]).to eq ['Microfiche']
    end
  end

  context 'when the 300a contains microfiche' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01543cam a2200325Ka 4500'
        r.append(MARC::DataField.new('300', ' ', ' ',
          MARC::Subfield.new('a', 'microfiches :')
        ))
      end
    end

    it 'is a microfilm' do
      expect(result[field]).to eq ['Microfiche']
    end
  end
#
#   /**
#    *  Spec from email chain Nov 2013
#    *  INDEX-89 - Video Physical Formats
#    *  The order of checking for data
#      *     i. call number
#      *    ii. 538$a
#      *   iii. 300$b and 347$b
#      *   iv. 007
#      * "Other video" not needed if there is a more specific value already determined
#    **/
  context 'with 007/00 - m' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', 'ma afu   buca'))
      end
    end

    it 'is a film' do
      expect(result[field]).to eq ['Film']
    end
  end

  context 'with a call number starts with ZDVD' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'ZDVD')
        ))
      end
    end

    it 'is a DVD' do
      expect(result[field]).to eq ['DVD']
    end
  end

  context 'with a call number starts with ZDVD' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'ZDVD')
        ))
      end
    end

    it 'is a DVD' do
      expect(result[field]).to eq ['DVD']
    end
  end

  context 'with a call number starts with MDVD' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'MDVD')
        ))
      end
    end

    it 'is a DVD' do
      expect(result[field]).to eq ['DVD']
    end
  end

  context 'with a call number starts with ADVD' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'ADVD')
        ))
      end
    end

    it 'is a DVD' do
      expect(result[field]).to eq ['DVD']
    end
  end

  context 'with a 538 contains "DVD"' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::DataField.new('538', ' ', ' ',
          MARC::Subfield.new('a', 'ADVD')
        ))
      end
    end

    it 'is a DVD' do
      expect(result[field]).to eq ['DVD']
    end
  end

  context 'with 007/00 - v, 007/04 = v' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', 'vb cvaizq'))
      end
    end

    it 'is a DVD' do
      expect(result[field]).to eq ['DVD']
    end
  end

  context 'with 007/00 = v, 007/04 = z and 538$a contains DVD' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', 'vb czaizq'))
        r.append(MARC::DataField.new('538', ' ', ' ',
          MARC::Subfield.new('a', 'DVD')
        ))
      end
    end

    it 'is a DVD' do
      expect(result[field]).to include 'DVD'
    end
  end

  context 'with call number contains "BLU-RAY"' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'ZDVD 12345 BLU-RAY')
        ))
      end
    end

    it 'is a Blu-ray' do
      expect(result[field]).to include 'Blu-ray'
    end
  end

  context 'with a 538 that contains "Bluray"' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.append(MARC::DataField.new('538', ' ', ' ',
          MARC::Subfield.new('a', 'Bluray')
        ))
      end
    end

    it 'is a Blu-ray' do
      expect(result[field]).to include 'Blu-ray'
    end
  end

  context 'with a 538 that contains "Blu ray"' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.append(MARC::DataField.new('538', ' ', ' ',
          MARC::Subfield.new('a', 'Blu ray')
        ))
      end
    end

    it 'is a Blu-ray' do
      expect(result[field]).to include 'Blu-ray'
    end
  end

  context 'with a 538 that contains "Blu-ray"' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.append(MARC::DataField.new('538', ' ', ' ',
          MARC::Subfield.new('a', 'Blu-ray')
        ))
      end
    end

    it 'is a Blu-ray' do
      expect(result[field]).to include 'Blu-ray'
    end
  end

  context 'with 007/00 - v, 007/04 = s' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', 'vb csaizq'))
      end
    end

    it 'is a Blu-ray' do
      expect(result[field]).to eq ['Blu-ray']
    end
  end

  context 'with call number that starts with ZVC' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'ZVC')
        ))
      end
    end

    it 'is a VHS' do
      expect(result[field]).to include 'Videocassette (VHS)'
    end
  end

  context 'with call number that starts with ARTVC' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'ARTVC')
        ))
      end
    end

    it 'is a VHS' do
      expect(result[field]).to include 'Videocassette (VHS)'
    end
  end

  context 'with call number that starts with MVC' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'MVC')
        ))
      end
    end

    it 'is a VHS' do
      expect(result[field]).to include 'Videocassette (VHS)'
    end
  end

  context 'with call number that starts with AVC' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'AVC')
        ))
      end
    end

    it 'is a VHS' do
      expect(result[field]).to include 'Videocassette'
    end
  end

  context 'with a 538 that contains "VHS"' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.append(MARC::DataField.new('538', ' ', ' ',
          MARC::Subfield.new('a', 'VHS')
        ))
      end
    end

    it 'is a VHS' do
      expect(result[field]).to include 'Videocassette (VHS)'
    end
  end

  context 'with 007/00 - v, 007/04 = b' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', 'vb cbsaizq'))
      end
    end

    it 'is a VHS videocassette' do
      expect(result[field]).to eq ['Videocassette (VHS)']
    end
  end

  context 'with 007/00 - v, 007/04 = a' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', 'vb vaaizq'))
      end
    end

    it 'is a beta videocassette' do
      expect(result[field]).to eq ['Videocassette (Beta)']
    end
  end

  context 'with 007/00 = v, 300$b = MP4' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::DataField.new('300', ' ', ' ',
          MARC::Subfield.new('b', 'MP4')
        ))
      end
    end

    it 'is a  MPEG-4' do
      expect(result[field]).to eq ['MPEG-4']
    end
  end

  context 'with 007/00 = v, 347$b = MPEG-4' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::DataField.new('347', ' ', ' ',
          MARC::Subfield.new('b', 'MPEG-4')
        ))
      end
    end

    it 'is a  MPEG-4' do
      expect(result[field]).to eq ['MPEG-4']
    end
  end

  context 'with 007/00 - v, 007/04 = q' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', 'vb vqaizq'))
      end
    end

    it 'is a Hi-8 mm' do
      expect(result[field]).to eq ['Hi-8 mm']
    end
  end

  context 'with 007/00 != v or m' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', '    vaizq'))
      end
    end

    it 'is undetermined' do
      expect(result[field]).to eq nil
    end
  end

  context 'with 007/00 = v but 007/04 != a, b, i, j, q, s, v  and no 300, 347, and 538' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', 'v   zxaizq'))
      end
    end

    it 'is undetermined' do
      expect(result[field]).to eq ['Other video']
    end
  end

  context 'with (not a MP4) from 300$b or 347$b' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', '    vaizq'))
        r.append(MARC::DataField.new('300', ' ', ' ',
          MARC::Subfield.new('b', 'M')
        ))
        r.append(MARC::DataField.new('347', ' ', ' ',
          MARC::Subfield.new('b', 'M')
        ))
      end
    end

    it 'is undetermined' do
      expect(result[field]).to eq nil
    end
  end

  context 'with (not a BLURAY) 538 does not contain "Bluray" or "VHS"' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::DataField.new('538', ' ', ' ',
          MARC::Subfield.new('a', 'Junk')
        ))
      end
    end

    it 'is undetermined' do
      expect(result[field]).to eq nil
    end
  end

  context 'with a call number that starts with ZVD' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'ZVD')
        ))
      end
    end

    it 'is a laser disc' do
      expect(result[field]).to eq ['Laser disc']
    end
  end

  context 'with a call number that starts with MVD' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'MVD')
        ))
      end
    end

    it 'is a laser disc' do
      expect(result[field]).to eq ['Laser disc']
    end
  end

  context 'with 538a contains CAV' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::DataField.new('538', ' ', ' ',
          MARC::Subfield.new('a', 'CAV')
        ))
      end
    end

    it 'is a laser disc' do
      expect(result[field]).to eq ['Laser disc']
    end
  end

  context 'with 538a contains CLV' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::DataField.new('538', ' ', ' ',
          MARC::Subfield.new('a', 'CLV')
        ))
      end
    end

    it 'is a laser disc' do
      expect(result[field]).to eq ['Laser disc']
    end
  end

  context 'with 007/00 - v, 007/04 = g' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', 'vb vgaizq'))
      end
    end

    it 'is a laser disc' do
      expect(result[field]).to eq ['Laser disc']
    end
  end

  context 'with 007/00 = v and 007/04 = z and 538a contains CAV' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', 'vd czaizq'))
        r.append(MARC::DataField.new('538', ' ', ' ',
          MARC::Subfield.new('a', 'CAV')
        ))
      end
    end

    it 'is a laser disc' do
      expect(result[field]).to include 'Laser disc'
    end
  end

  context 'with 007/00 = v and 007/04 = z and 538a contains CLV' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', 'vd czaizq'))
        r.append(MARC::DataField.new('538', ' ', ' ',
          MARC::Subfield.new('a', 'CLV')
        ))
      end
    end

    it 'is a laser disc' do
      expect(result[field]).to include 'Laser disc'
    end
  end

  context 'with 007/00 = v and 007/04 = z and 538a contains VCD' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', 'vd czaizq'))
        r.append(MARC::DataField.new('538', ' ', ' ',
          MARC::Subfield.new('a', 'VCD')
        ))
      end
    end

    it 'is a Video CD' do
      expect(result[field]).to include 'Video CD'
    end
  end

  context 'with 007/00 = v and 007/04 = z and 538a contains Video CD' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', 'vd czaizq'))
        r.append(MARC::DataField.new('538', ' ', ' ',
          MARC::Subfield.new('a', 'Video CD')
        ))
      end
    end

    it 'is a Video CD' do
      expect(result[field]).to include 'Video CD'
    end
  end

  context 'with 007/00 = v and 007/04 = z and 538a contains VideoCD' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', 'vd czaizq'))
        r.append(MARC::DataField.new('538', ' ', ' ',
          MARC::Subfield.new('a', 'VideoCD')
        ))
      end
    end

    it 'is a Video CD' do
      expect(result[field]).to include 'Video CD'
    end
  end

  context 'with 007/00 = v and 007/04 = z and 300b contains VCD' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', 'vd czaizq'))
        r.append(MARC::DataField.new('300', ' ', ' ',
          MARC::Subfield.new('b', 'VCD')
        ))
      end
    end

    it 'is a Video CD' do
      expect(result[field]).to include 'Video CD'
    end
  end

  context 'with 007/00 = v and 007/04 = z and 300b contains Video CD' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', 'vd czaizq'))
        r.append(MARC::DataField.new('300', ' ', ' ',
          MARC::Subfield.new('b', 'Video CD')
        ))
      end
    end

    it 'is a Video CD' do
      expect(result[field]).to include 'Video CD'
    end
  end

  context 'with 007/00 = v and 007/04 = z and 300b contains VideoCD' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', 'vd czaizq'))
        r.append(MARC::DataField.new('300', ' ', ' ',
          MARC::Subfield.new('b', 'VideoCD')
        ))
      end
    end

    it 'is a Video CD' do
      expect(result[field]).to include 'Video CD'
    end
  end

  context 'with 007/00 = v and 007/04 = z and 347b contains VCD' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', 'vd czaizq'))
        r.append(MARC::DataField.new('347', ' ', ' ',
          MARC::Subfield.new('b', 'VCD')
        ))
      end
    end

    it 'is a Video CD' do
      expect(result[field]).to include 'Video CD'
    end
  end

  context 'with 007/00 = v and 007/04 = z and 347b contains Video CD' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', 'vd czaizq'))
        r.append(MARC::DataField.new('347', ' ', ' ',
          MARC::Subfield.new('b', 'Video CD')
        ))
      end
    end

    it 'is a Video CD' do
      expect(result[field]).to include 'Video CD'
    end
  end

  context 'with 007/00 = v and 007/04 = z and 347b contains VideoCD' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', 'vd czaizq'))
        r.append(MARC::DataField.new('347', ' ', ' ',
          MARC::Subfield.new('b', 'VideoCD')
        ))
      end
    end

    it 'is a Video CD' do
      expect(result[field]).to include 'Video CD'
    end
  end

  context 'without a 538$a, 300$b or 347$b' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '04711cgm a2200733Ia 4500'
        r.append(MARC::ControlField.new('007', 'vd czaizq'))
      end
    end

    it 'is a other video' do
      expect(result[field]).to eq ['Other video']
    end
  end

#   /**
#    *  SW-1531 - Piano Organ roll value
#    *  if 007/00 = 's' and 007/01 = 'q' or
#    *  if 338$a or 300$a contains "audio roll"
#    *
#    **/
  context 'with 007/00 = sq' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01103cem a22002777a 4500'
        r.append(MARC::ControlField.new('007', 'sq'))
        r.append(MARC::DataField.new('999', ' ', ' ',
          MARC::Subfield.new('a', 'F152 .A28'),
          MARC::Subfield.new('w', 'LC'),
          MARC::Subfield.new('i', '36105018746623'),
          MARC::Subfield.new('l', 'HAS-DIGIT'),
          MARC::Subfield.new('m', 'GREEN')
        ))
      end
    end

    it 'is a piano/organ roll' do
      expect(result[field]).to eq ['Piano/Organ roll']
    end
  end

  context 'when the 300a contains audio roll' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01103cem a22002777a 4500'
        r.append(MARC::DataField.new('300', ' ', ' ',
          MARC::Subfield.new('a', '1 audio roll')
        ))
      end
    end

    it 'is a piano/organ roll' do
      expect(result[field]).to eq ['Piano/Organ roll']
    end
  end

  context 'when the 338a contains audio roll' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01103cem a22002777a 4500'
        r.append(MARC::DataField.new('338', ' ', ' ',
          MARC::Subfield.new('a', '1 audio roll')
        ))
      end
    end

    it 'is a piano/organ roll' do
      expect(result[field]).to eq ['Piano/Organ roll']
    end
  end

  context 'when the 338a contains audio and roll' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01103cem a22002777a 4500'
        r.append(MARC::DataField.new('338', ' ', ' ',
          MARC::Subfield.new('a', '1 audio and roll')
        ))
      end
    end

    it 'is undetermined' do
      expect(result[field]).to eq nil
    end
  end

  describe 'characteristics_ssim' do
    let(:field) { 'characteristics_ssim' }

    context 'with a 344' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('344', ' ', ' ',
            MARC::Subfield.new('a', 'analog')
          ))
        end
      end

      it 'has the right data' do
        expect(result[field]).to eq ['Sound: analog.']
      end
    end

    context 'with a 345' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('345', ' ', ' ',
            MARC::Subfield.new('a', '3D')
          ))
        end
      end

      it 'has the right data' do
        expect(result[field]).to eq ['Projection: 3D.']
      end
    end

    context 'with a 346' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('346', ' ', ' ',
            MARC::Subfield.new('a', 'Beta')
          ))
        end
      end

      it 'has the right data' do
        expect(result[field]).to eq ['Video: Beta.']
      end
    end

    context 'with a 347' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.append(MARC::DataField.new('347', ' ', ' ',
            MARC::Subfield.new('a', 'audio file')
          ))
        end
      end

      it 'has the right data' do
        expect(result[field]).to eq ['Digital: audio file.']
      end
    end
  end
end
