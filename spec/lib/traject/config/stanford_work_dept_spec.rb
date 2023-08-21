# frozen_string_literal: true

RSpec.describe 'Stanford work and department config' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end
  subject(:result) { indexer.map_record(stub_record_from_marc(record)) }
  let(:work_field) { 'stanford_work_facet_hsim' }
  let(:dept_field) { 'stanford_dept_sim' }

  describe 'Bachelor\'s of Art (BA)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'a4820195'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis (B.A.)--Stanford University, 2002.')))
        r.append(MARC::DataField.new('710', '2', ' ',
                                     MARC::Subfield.new('a', 'Stanford University.'),
                                     MARC::Subfield.new('b', 'Department of Geophysics')))
      end
    end

    it 'should map to BA and not Undergraduate honors' do
      expect(result[work_field]).to eq ['Thesis/Dissertation|Bachelor\'s|Bachelor of Arts (BA)']
      expect(result[work_field]).not_to eq ['Thesis/Dissertation|Bachelor\'s|Undergraduate honors thesis']
      expect(result[dept_field]).to eq ['Department of Geophysics']
    end
  end

  describe 'Doctor of Musical Arts (DMA)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'a1343750'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'D.M.A. term project Department of Music, Stanford University, 1989.')))
        r.append(MARC::DataField.new('710', '2', ' ',
                                     MARC::Subfield.new('a', 'Stanford University.'),
                                     MARC::Subfield.new('b', 'Department of Music.'),
                                     MARC::Subfield.new('t', 'Projects.'),
                                     MARC::Subfield.new('p', 'D.M.A. Term.')))
      end
    end

    it 'should map to DMA and not MA' do
      expect(result[work_field]).to eq ['Thesis/Dissertation|Doctoral|Doctor of Musical Arts (DMA)']
      expect(result[work_field]).not_to eq ['Thesis/Dissertation|Master\'s|Master of Arts (MA)']
      expect(result[dept_field]).to eq ['Department of Music']
    end
  end

  describe 'Doctor of Education (EdD)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'a965475'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('g', 'Thesis'),
                                     MARC::Subfield.new('b', 'Ed.D.'),
                                     MARC::Subfield.new('c', 'Stanford University'),
                                     MARC::Subfield.new('d', '1977.')))
        r.append(MARC::DataField.new('710', '2', ' ',
                                     MARC::Subfield.new('a', 'Stanford University.'),
                                     MARC::Subfield.new('b', 'Department of School of Education.')))
      end
    end

    it 'should map to EdD' do
      expect(result[work_field]).to eq ['Thesis/Dissertation|Doctoral|Doctor of Education (EdD)']
      expect(result[dept_field]).to eq ['Department of School of Education']
    end
  end

  describe 'Master of Education (EdM)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'a2303030'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis (Ed.M.)--Leland Stanford Junior University, 1934.')))
      end
    end

    it 'should map to EdM' do
      expect(result[work_field]).to eq ['Thesis/Dissertation|Master\'s|Master of Education (EdM)']
    end
  end

  describe 'Thesis (Ed.S.)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'a2285433'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis (Ed.S.)--Stanford University.')))
      end
    end

    it 'should map to Unspecified' do
      expect(result[work_field]).to eq ['Thesis/Dissertation|Unspecified']
    end
  end

  describe 'Engineer' do
    context 'term \'Engineering\'' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01737cam a2200445Ka 4500'
          r.append(MARC::ControlField.new('001', 'a11688582'))
          r.append(MARC::DataField.new('502', ' ', ' ',
                                       MARC::Subfield.new('a', 'Thesis (Engineering)--Stanford University, 2016.')))
          r.append(MARC::DataField.new('710', '2', ' ',
                                       MARC::Subfield.new('a', 'Stanford University.'),
                                       MARC::Subfield.new('b', 'Department of Aeronautics and Astronautics.')))
        end
      end

      it 'should map to Engineer' do
        expect(result[work_field]).to eq ['Thesis/Dissertation|Master\'s|Engineer']
        expect(result[dept_field]).to eq ['Department of Aeronautics and Astronautics']
      end
    end

    context 'term \'Engineer\'' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01737cam a2200445Ka 4500'
          r.append(MARC::ControlField.new('001', 'a5650590'))
          r.append(MARC::DataField.new('502', ' ', ' ',
                                       MARC::Subfield.new('b', 'Engineer'),
                                       MARC::Subfield.new('c', 'Stanford University'),
                                       MARC::Subfield.new('d', '1912')))
          r.append(MARC::DataField.new('710', '2', ' ',
                                       MARC::Subfield.new('a', 'Stanford University.'),
                                       MARC::Subfield.new('b', 'Department of Geology.')))
        end
      end

      it 'should map to Engineer' do
        expect(result[work_field]).to eq ['Thesis/Dissertation|Master\'s|Engineer']
        expect(result[dept_field]).to eq ['Department of Geology']
      end
    end

    context 'term \'Degree of Engineer\'' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01737cam a2200445Ka 4500'
          r.append(MARC::ControlField.new('001', 'a2950747'))
          r.append(MARC::DataField.new('502', ' ', ' ',
                                       MARC::Subfield.new('b', 'Degree of Engineer'),
                                       MARC::Subfield.new('c', 'Stanford University'),
                                       MARC::Subfield.new('d', '1994')))
          r.append(MARC::DataField.new('710', '2', ' ',
                                       MARC::Subfield.new('a', 'Stanford University.'),
                                       MARC::Subfield.new('b', 'Department of Civil Engineering.')))
        end
      end

      it 'should map to Engineer' do
        expect(result[work_field]).to eq ['Thesis/Dissertation|Master\'s|Engineer']
        expect(result[dept_field]).to eq ['Department of Civil Engineering']
      end
    end

    context 'term \'Engr.\'' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01737cam a2200445Ka 4500'
          r.append(MARC::ControlField.new('001', 'a2161308'))
          r.append(MARC::DataField.new('502', ' ', ' ',
                                       MARC::Subfield.new('a', 'Thesis (Engr.)--Dept. of Electrical Engineering, Stanford University.')))
        end
      end

      it 'should map to Engineer' do
        expect(result[work_field]).to eq ['Thesis/Dissertation|Master\'s|Engineer']
      end
    end

    context 'term \'English\'' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01737cam a2200445Ka 4500'
          r.append(MARC::ControlField.new('001', 'a2230657'))
          r.append(MARC::DataField.new('502', ' ', ' ',
                                       MARC::Subfield.new('a', 'Thesis (M.A.)--Dept. of English, Stanford University.')))
        end
      end

      it 'should not map to Engineer' do
        expect(result[work_field]).to eq ['Thesis/Dissertation|Master\'s|Master of Arts (MA)']
        expect(result[work_field]).not_to eq ['Thesis/Dissertation|Master\'s|Engineer']
      end
    end
  end

  describe 'Doctor of Jurisprudence (JD)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'a1795310'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('b', 'J.D.'),
                                     MARC::Subfield.new('c', 'Stanford University'),
                                     MARC::Subfield.new('d', '1929')))
      end
    end

    it 'should map to JD' do
      expect(result[work_field]).to eq ['Thesis/Dissertation|Doctoral|Doctor of Jurisprudence (JD)']
    end
  end

  describe 'Doctor of the Science of Law (JSD)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'a7912414'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis (J.S.D)--Stanford University, 2008.')))
        r.append(MARC::DataField.new('710', '2', ' ',
                                     MARC::Subfield.new('a', 'Stanford University.'),
                                     MARC::Subfield.new('b', 'School of Law.')))
      end
    end

    it 'should map to JSD' do
      expect(result[work_field]).to eq ['Thesis/Dissertation|Doctoral|Doctor of the Science of Law (JSD)']
      expect(result[dept_field]).to eq ['School of Law']
    end
  end

  describe 'Master of the Science of Law (JSM)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'a1811178'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis (J.S.M.)--Stanford University, 1972.')))
      end
    end

    it 'should map to JSM' do
      expect(result[work_field]).to eq ['Thesis/Dissertation|Master\'s|Master of the Science of Law (JSM)']
    end
  end

  describe 'Master of Laws (LLM)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'a1803872'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis (L.L.M.) - Stanford University.')))
      end
    end

    it 'should map to LLM' do
      expect(result[work_field]).to eq ['Thesis/Dissertation|Master\'s|Master of Laws (LLM)']
    end
  end

  describe 'Master of Arts (MA)' do
    context 'term \'A.M.\'' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01737cam a2200445Ka 4500'
          r.append(MARC::ControlField.new('001', 'a2001059'))
          r.append(MARC::DataField.new('502', ' ', ' ',
                                       MARC::Subfield.new('a', 'Thesis (A.M.)--Leland Stanford Junior University.')))
          r.append(MARC::DataField.new('710', '2', ' ',
                                       MARC::Subfield.new('a', 'Stanford University.'),
                                       MARC::Subfield.new('b', 'Department of Chemistry')))
        end
      end

      it 'should map to MA' do
        expect(result[work_field]).to eq ['Thesis/Dissertation|Master\'s|Master of Arts (MA)']
        expect(result[dept_field]).to eq ['Department of Chemistry']
      end
    end

    context 'term \'M.A.\'' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01737cam a2200445Ka 4500'
          r.append(MARC::ControlField.new('001', 'a5730269'))
          r.append(MARC::DataField.new('502', ' ', ' ',
                                       MARC::Subfield.new('g', 'Thesis'),
                                       MARC::Subfield.new('b', 'M.A.'),
                                       MARC::Subfield.new('c', 'Stanford University'),
                                       MARC::Subfield.new('d', '1939.')))
        end
      end

      it 'should map to MA' do
        expect(result[work_field]).to eq ['Thesis/Dissertation|Master\'s|Master of Arts (MA)']
      end
    end

    context 'term \'(M.A.)--\'' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01737cam a2200445Ka 4500'
          r.append(MARC::ControlField.new('001', 'a2188938'))
          r.append(MARC::DataField.new('502', ' ', ' ',
                                       MARC::Subfield.new('a', 'The editor\'s thesis (M.A.)--Dept. of Modern European Languages, Stanford University.')))
        end
      end

      it 'should map to MA' do
        expect(result[work_field]).to eq ['Thesis/Dissertation|Master\'s|Master of Arts (MA)']
      end
    end

    context 'term \'(M.A)--\'' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01737cam a2200445Ka 4500'
          r.append(MARC::ControlField.new('001', 'a5628179'))
          r.append(MARC::DataField.new('502', ' ', ' ',
                                       MARC::Subfield.new('a', 'Thesis (M.A)--Stanford University, 1931.')))
        end
      end

      it 'should map to MA' do
        expect(result[work_field]).to eq ['Thesis/Dissertation|Master\'s|Master of Arts (MA)']
      end
    end

    context 'term \'drama master\'s\'' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01737cam a2200445Ka 4500'
          r.append(MARC::ControlField.new('001', 'anotMA'))
          r.append(MARC::DataField.new('502', ' ', ' ',
                                       MARC::Subfield.new('a', 'Stanford University drama master\'s thesis')))
        end
      end

      it 'should map to Unspecified master\'s' do
        expect(result[work_field]).to eq ['Thesis/Dissertation|Master\'s|Unspecified']
      end
    end
  end

  describe 'Doctor of Medicine (MD)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'a11652845'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis (M.D.)--Stanford University, 1931.')))
        r.append(MARC::DataField.new('710', '2', ' ',
                                     MARC::Subfield.new('a', 'Stanford University'),
                                     MARC::Subfield.new('b', 'School of Medicine.'),
                                     MARC::Subfield.new('b', 'Department of Medicine.')))
      end
    end

    it 'should map to MD' do
      expect(result[work_field]).to eq ['Thesis/Dissertation|Doctoral|Doctor of Medicine (MD)']
      expect(result[dept_field]).to eq ['School of Medicine']
      expect(result[dept_field]).not_to eq ['Department of Medicine']
    end
  end

  describe 'Master of Fine Arts (MFA)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'a10197046'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis (M.F.A.)--Stanford University, 2013.')))
        r.append(MARC::DataField.new('710', '2', ' ',
                                     MARC::Subfield.new('a', 'Stanford University'),
                                     MARC::Subfield.new('b', 'Master of Fine Arts.')))
        r.append(MARC::DataField.new('710', '2', ' ',
                                     MARC::Subfield.new('a', 'Stanford University'),
                                     MARC::Subfield.new('b', 'Department of Art and Art History.')))
      end
    end

    it 'should map to MFA' do
      expect(result[work_field]).to eq ['Thesis/Dissertation|Master\'s|Master of Fine Arts (MFA)']
      expect(result[dept_field]).to eq ['Master of Fine Arts',
                                        'Department of Art and Art History']
    end
  end

  describe 'Master of Liberal Arts (MLA)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'a10370180'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis (M.L.A.)--Stanford University, 2013.')))
        r.append(MARC::DataField.new('710', '2', ' ',
                                     MARC::Subfield.new('a', 'Stanford University.'),
                                     MARC::Subfield.new('b', 'Master of Liberal Arts Program.')))
      end
    end

    it 'should map to MLA' do
      expect(result[work_field]).to eq ['Thesis/Dissertation|Master\'s|Master of Liberal Arts (MLA)']
      expect(result[dept_field]).to eq ['Master of Liberal Arts Program']
    end
  end

  describe 'Master of Legal Studies (MLS)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'a5799855'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis (M.L.S.)--Stanford University, 2003.')))
        r.append(MARC::DataField.new('710', '2', ' ',
                                     MARC::Subfield.new('a', 'Stanford Program in International Legal Studies.')))
      end
    end

    it 'should map to MLS' do
      expect(result[work_field]).to eq ['Thesis/Dissertation|Master\'s|Master of Legal Studies (MLS)']
      expect(result[dept_field]).to eq ['Stanford Program in International Legal Studies']
    end
  end

  describe 'Master of Science (MS)' do
    context 'term \'M.S.\'' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01737cam a2200445Ka 4500'
          r.append(MARC::ControlField.new('001', 'a2478369'))
          r.append(MARC::DataField.new('502', ' ', ' ',
                                       MARC::Subfield.new('a', 'Thesis (M.S.)--Stanford University, 1993.')))
          r.append(MARC::DataField.new('710', '2', ' ',
                                       MARC::Subfield.new('a', 'Stanford University.'),
                                       MARC::Subfield.new('b', 'Department of Applied Earth Sciences.')))
        end
      end

      it 'should map to MS' do
        expect(result[work_field]).to eq ['Thesis/Dissertation|Master\'s|Master of Science (MS)']
        expect(result[dept_field]).to eq ['Department of Applied Earth Sciences']
      end
    end

    context 'term \'Master of Science\'' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01737cam a2200445Ka 4500'
          r.append(MARC::ControlField.new('001', 'a4106221'))
          r.append(MARC::DataField.new('502', ' ', ' ',
                                       MARC::Subfield.new('b', 'Degree of Master of Science'),
                                       MARC::Subfield.new('c', 'Stanford University'),
                                       MARC::Subfield.new('d', '1998')))
          r.append(MARC::DataField.new('710', '2', ' ',
                                       MARC::Subfield.new('a', 'Stanford University.'),
                                       MARC::Subfield.new('b', 'Department of Biological Sciences.')))
        end
      end

      it 'should map to MS' do
        expect(result[work_field]).to eq ['Thesis/Dissertation|Master\'s|Master of Science (MS)']
        expect(result[dept_field]).to eq ['Department of Biological Sciences']
      end
    end
  end

  describe 'Doctor of Philosophy (PhD)' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'a12080422'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis (Ph.D.)--Stanford University, 2017.')))
        r.append(MARC::DataField.new('710', '2', ' ',
                                     MARC::Subfield.new('a', 'Stanford University.'),
                                     MARC::Subfield.new('b', 'Department of Electrical Engineering.')))
      end
    end

    it 'should map to PhD' do
      expect(result[work_field]).to eq ['Thesis/Dissertation|Doctoral|Doctor of Philosophy (PhD)']
      expect(result[dept_field]).to eq ['Department of Electrical Engineering']
    end
  end

  describe 'Student report' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'a8390172'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Student Report--Stanford University, 2009.')))
        r.append(MARC::DataField.new('710', '2', ' ',
                                     MARC::Subfield.new('a', 'Stanford University.'),
                                     MARC::Subfield.new('b', 'Department of Petroleum Engineering.')))
      end
    end

    it 'should map to Student report' do
      expect(result[work_field]).to eq ['Other student work|Student report']
      expect(result[dept_field]).to eq ['Department of Petroleum Engineering']
    end
  end

  describe 'Graduate School of Business' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'a10037295'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis--Graduate School of Business, Stanford University.')))
        r.append(MARC::DataField.new('710', '2', ' ',
                                     MARC::Subfield.new('a', 'Stanford University.'),
                                     MARC::Subfield.new('b', 'Graduate School of Business'),
                                     MARC::Subfield.new('t', 'Dissertation.'),
                                     MARC::Subfield.new('d', '1979.')))
      end
    end

    it 'should map to Doctoral Unspecified' do
      expect(result[work_field]).to eq ['Thesis/Dissertation|Doctoral|Unspecified']
      expect(result[dept_field]).to eq ['Graduate School of Business']
    end
  end

  describe 'Undergraduate honors thesis' do
    context 'term \'Honors\'' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01737cam a2200445Ka 4500'
          r.append(MARC::ControlField.new('001', 'a2759546'))
          r.append(MARC::DataField.new('502', ' ', ' ',
                                       MARC::Subfield.new('a', 'Honors thesis (B.A.)--Stanford University.')))
        end
      end

      it 'should map to Undergraduate honors thesis' do
        expect(result[work_field]).to eq ['Thesis/Dissertation|Bachelor\'s|Undergraduate honors thesis']
        expect(result[work_field]).not_to eq ['Thesis/Dissertation|Bachelor\'s|Bachelor of Arts (BA)']
      end
    end

    context 'term \'Honors project\'' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01737cam a2200445Ka 4500'
          r.append(MARC::ControlField.new('001', 'a750717'))
          r.append(MARC::DataField.new('502', ' ', ' ',
                                       MARC::Subfield.new('a', 'Senior Honors project - Department of Music, Stanford University.')))
        end
      end

      it 'should map to Undergraduate honors thesis' do
        expect(result[work_field]).to eq ['Thesis/Dissertation|Bachelor\'s|Undergraduate honors thesis']
      end
    end
  end

  describe 'Doctoral dissertation' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'a4086853'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Doctoral dissertation, Stanford University.')))
      end
    end

    it 'should map to Doctoral Unspecified' do
      expect(result[work_field]).to eq ['Thesis/Dissertation|Doctoral|Unspecified']
    end
  end

  describe 'Master\'s project' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'a8109556'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Master\'s project--Stanford University, 2005.')))
      end
    end

    it 'should map to Master\'s Unspecified' do
      expect(result[work_field]).to eq ['Thesis/Dissertation|Master\'s|Unspecified']
    end
  end

  describe 'Thesis without degree level' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'a2163948'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('g', 'Thesis'),
                                     MARC::Subfield.new('c', 'Stanford University'),
                                     MARC::Subfield.new('d', '1930.')))
      end
    end

    it 'should map to Unspecified' do
      expect(result[work_field]).to eq ['Thesis/Dissertation|Unspecified']
    end
  end

  describe 'Degree level with interspersed whitespace' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'aWithSpaces'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis (Ed. D. )--Stanford University, 2008.')))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis (Ph. D.) - Dept, of Music, Stanford University.')))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis (M. F. A.) -- Stanford University.')))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis (M. S.)--Stanford University, 1983.')))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis (B.A. Music) -- Stanford University.')))
      end
    end

    it 'should map to correct facet values' do
      expect(result[work_field]).to eq ['Thesis/Dissertation|Doctoral|Doctor of Education (EdD)',
                                        'Thesis/Dissertation|Doctoral|Doctor of Philosophy (PhD)',
                                        'Thesis/Dissertation|Master\'s|Master of Fine Arts (MFA)',
                                        'Thesis/Dissertation|Master\'s|Master of Science (MS)',
                                        'Thesis/Dissertation|Bachelor\'s|Bachelor of Arts (BA)']
    end
  end

  describe 'Degree level without whitespace' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'aWithOutSpaces'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis(A.M.)--Leland Stanford Junior University.')))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis(B.A.)--Stanford University, 2002.')))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis (E.Eng.)--Dept. of Electrical Engineering, Stanford University.')))
      end
    end

    it 'should map to correct facet values' do
      expect(result[work_field]).to eq ['Thesis/Dissertation|Master\'s|Master of Arts (MA)',
                                        'Thesis/Dissertation|Bachelor\'s|Bachelor of Arts (BA)',
                                        'Thesis/Dissertation|Master\'s|Engineer']
    end
  end

  describe 'Degree level without periods' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'aPeriodsMissing'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis (JSD)--Stanford University, 2008.')))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis Phd.D.)--School of Education, Stanford University.')))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis (LL.M.)--Stanford University, 1943.')))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis (MFA) --Stanford University.')))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('a', 'Thesis M.A Stanford University.')))
      end
    end

    it 'should map to correct facet values' do
      expect(result[work_field]).to eq ['Thesis/Dissertation|Doctoral|Doctor of the Science of Law (JSD)',
                                        'Thesis/Dissertation|Doctoral|Doctor of Philosophy (PhD)',
                                        'Thesis/Dissertation|Master\'s|Master of Laws (LLM)',
                                        'Thesis/Dissertation|Master\'s|Master of Fine Arts (MFA)',
                                        'Thesis/Dissertation|Master\'s|Master of Arts (MA)']
    end
  end

  describe 'Non-Stanford thesis' do
    let(:record) do
      MARC::Record.new.tap do |r|
        r.leader = '01737cam a2200445Ka 4500'
        r.append(MARC::ControlField.new('001', 'a3312224'))
        r.append(MARC::DataField.new('502', ' ', ' ',
                                     MARC::Subfield.new('b', 'M.A.'),
                                     MARC::Subfield.new('c', 'California State University, Fresno.'),
                                     MARC::Subfield.new('d', '1996')))
        r.append(MARC::DataField.new('710', '2', ' ',
                                     MARC::Subfield.new('a', 'California State University, Fresno.'),
                                     MARC::Subfield.new('b', 'Department of English.')))
      end
    end

    it 'should not map to Stanford work facet' do
      expect(result[work_field]).to be_nil
      expect(result[dept_field]).to be_nil
    end
  end

  describe 'Department facet' do
    context 'Stanford 710 with multiple subfields b' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01737cam a2200445Ka 4500'
          r.append(MARC::ControlField.new('001', 'a5638754'))
          r.append(MARC::DataField.new('502', ' ', ' ',
                                       MARC::Subfield.new('b', 'Ph. D.'),
                                       MARC::Subfield.new('c', 'Stanford University'),
                                       MARC::Subfield.new('d', '1924')))
          r.append(MARC::DataField.new('710', '2', ' ',
                                       MARC::Subfield.new('a', 'Stanford University'),
                                       MARC::Subfield.new('b', 'Department of Pharmacology.'),
                                       MARC::Subfield.new('b', 'School of Medicine.')))
        end
      end

      it 'should map first subfield b only' do
        expect(result[work_field]).to eq ['Thesis/Dissertation|Doctoral|Doctor of Philosophy (PhD)']
        expect(result[dept_field]).to eq ['Department of Pharmacology']
        expect(result[dept_field]).not_to eq ['School of Medicine']
      end
    end

    context 'non-Stanford 710 field' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01737cam a2200445Ka 4500'
          r.append(MARC::ControlField.new('001', 'a11073269'))
          r.append(MARC::DataField.new('502', ' ', ' ',
                                       MARC::Subfield.new('a', 'Thesis (Ph.D.); Supercedes report DE98059289; Thesis submitted to Stanford Univ., CA (US); TH: Thesis (Ph.D.); PBD: May 1997; PBD: 1 May 1997')))
          r.append(MARC::DataField.new('710', '2', ' ',
                                       MARC::Subfield.new('a', 'Stanford Linear Accelerator Center.')))
          r.append(MARC::DataField.new('710', '2', ' ',
                                       MARC::Subfield.new('a', 'United States.'),
                                       MARC::Subfield.new('b', 'Dept. of Energy. '),
                                       MARC::Subfield.new('b', 'Office of Energy Research')))
        end
      end

      it 'should not map subfield b' do
        expect(result[work_field]).to eq ['Thesis/Dissertation|Doctoral|Doctor of Philosophy (PhD)']
        expect(result[dept_field]).to eq ['Stanford Linear Accelerator Center']
        expect(result[dept_field]).not_to eq ['Dept. of Energy']
        expect(result[dept_field]).not_to eq ['Department of Energy']
      end
    end

    context 'empty 710 subfield b' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01737cam a2200445Ka 4500'
          r.append(MARC::ControlField.new('001', 'a2101659'))
          r.append(MARC::DataField.new('502', ' ', ' ',
                                       MARC::Subfield.new('g', 'Thesis'),
                                       MARC::Subfield.new('b', 'Ph.D.'),
                                       MARC::Subfield.new('c', 'Stanford University'),
                                       MARC::Subfield.new('d', '1960.')))
          r.append(MARC::DataField.new('710', '2', ' ',
                                       MARC::Subfield.new('a', 'Stanford University.'),
                                       MARC::Subfield.new('b', ' ')))
        end
      end

      it 'should not create an empty department facet value' do
        expect(result[work_field]).to eq ['Thesis/Dissertation|Doctoral|Doctor of Philosophy (PhD)']
        expect(result[dept_field]).to eq ['Stanford University']
        expect(result[dept_field]).not_to be_empty
      end
    end

    context 'Dept.' do
      let(:record) do
        MARC::Record.new.tap do |r|
          r.leader = '01737cam a2200445Ka 4500'
          r.append(MARC::ControlField.new('001', 'a12116908'))
          r.append(MARC::DataField.new('502', ' ', ' ',
                                       MARC::Subfield.new('a', 'Thesis (Ph.D.)--Stanford University, 2017.')))
          r.append(MARC::DataField.new('710', '2', ' ',
                                       MARC::Subfield.new('a', 'Stanford University.'),
                                       MARC::Subfield.new('b', 'Dept. of Material Sci & Eng.')))
        end
      end

      it 'should be replaced by Department' do
        expect(result[work_field]).to eq ['Thesis/Dissertation|Doctoral|Doctor of Philosophy (PhD)']
        expect(result[dept_field]).to eq ['Department of Material Sci & Eng']
      end
    end
  end
end
