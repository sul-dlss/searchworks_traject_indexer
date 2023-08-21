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

  describe 'url_sfx' do
    let(:field) { 'url_sfx' }

    it 'adds url_sfx fields to records with 956 SFX fields' do
      expect(select_by_id('mult856and956')[field]).to eq ['http://caslon.stanford.edu:3210/sfxlcl3?superLongURL']
      expect(select_by_id('7117119')[field]).to eq ['http://caslon.stanford.edu:3210/sfxlcl3?url_ver=Z39.88-2004&ctx_ver=Z39.88-2004&ctx_enc=info:ofi/enc:UTF-8&rfr_id=info:sid/sfxit.com:opac_856&url_ctx_fmt=info:ofi/fmt:kev:mtx:ctx&sfx.ignore_date_threshold=1&rft.object_id=110978984448763&svc_val_fmt=info:ofi/fmt:kev:mtx:sch_svc&']
      expect(select_by_id('newSfx')[field]).to eq ['http://library.stanford.edu/sfx?reallyLongLotsOfArgs']
    end

    it 'omits url_sfx fields when the 956 is not an SFX field' do
      expect(select_by_id('956BlankIndicators')[field]).to be_nil
      expect(select_by_id('956ind2is0')[field]).to be_nil
    end
  end

  describe 'url_fulltext' do
    let(:field) { 'url_fulltext' }

    it 'adds url_fulltext fields to records with fulltext url(s) in docs' do
      expect(select_by_id('856ind2is0')[field]).to eq ['http://www.netLibrary.com/urlapi.asp?action=summary&v=1&bookid=122436']
      expect(select_by_id('856ind2is0Again')[field]).to eq ['http://www.url856.com/fulltext/ind2_0']
      expect(select_by_id('856ind2is1NotToc')[field]).to eq ['http://www.url856.com/fulltext/ind2_1/not_toc']
      # empty/blank ind2 is most likely not fulltext
      expect(select_by_id('856ind2isBlankFulltext')[field]).to be_blank
      expect(select_by_id('956BlankIndicators')[field]).to eq ['http://www.url956.com/fulltext/blankIndicators']
      expect(select_by_id('956ind2is0')[field]).to eq ['http://www.url956.com/fulltext/ind2_is_0']
      expect(select_by_id('956and856TOC')[field]).to eq ['http://www.url956.com/fulltext/ind2_is_blank']
      expect(select_by_id('mult856and956')[field]).to eq ['http://www.sciencemag.org/',
                                                          'http://www.jstor.org/journals/00368075.html', 'http://www.sciencemag.org/archive/']
      expect(select_by_id('956and856TOCand856suppl')[field]).to eq ['http://www.url956.com/fulltext/ind2_is_blank']
    end

    it 'omits url_fulltext to records with a SFX url' do
      expect(select_by_id('mult856and956')[field]).not_to include 'http://caslon.stanford.edu:3210/sfxlcl3?superLongURL'
    end

    it 'omits url_fulltext fields for docs with no fulltext url in bib rec' do
      expect(select_by_id('856ind2is1TocSubz')[field]).to be_nil
      expect(select_by_id('856ind2is1TocSub3')[field]).to be_nil
      expect(select_by_id('856ind2is2suppl')[field]).to be_nil
      expect(select_by_id('856ind2isBlankTocSubZ')[field]).to be_nil
      expect(select_by_id('856ind2isBlankTocSub3')[field]).to be_nil
      expect(select_by_id('856tocAnd856SupplNoFulltext')[field]).to be_nil
    end

    it 'omits url_fulltext fields for docs with jackson forms for off-site paging requests' do
      expect(select_by_id('123http')[field]).to be_nil
      expect(select_by_id('124http')[field]).to be_nil
    end

    describe 'Blank 2nd indicators' do
      let(:records) do
        [
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '856',
                '4',
                nil,
                MARC::Subfield.new('u', 'http://example.com/')
              )
            )
          end
        ]
      end

      it 'are not considered full text' do
        expect(results.first[field]).to be_blank
      end
    end

    describe '2nd indicators of 3' do
      let(:records) do
        [
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '856',
                '4',
                '3',
                MARC::Subfield.new('u', 'http://example.com/')
              )
            )
          end
        ]
      end

      it 'are considered full text' do
        expect(results.first[field]).to eq ['http://example.com/']
      end
    end

    describe '2nd indicators of 4' do
      let(:records) do
        [
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '856',
                '4',
                '4',
                MARC::Subfield.new('u', 'http://example.com/')
              )
            )
          end
        ]
      end

      it 'are considered full text' do
        expect(results.first[field]).to eq ['http://example.com/']
      end
    end
  end

  describe 'url_fulltext' do
    let(:field) { 'url_suppl' }

    it 'adds url_suppl fields to ..uh.. book?' do
      expect(select_by_id('856ind2is1TocSubz')[field]).to eq ['http://www.url856.com/ind2_1/toc_subz']
      expect(select_by_id('856ind2is1TocSub3')[field]).to eq ['http://www.url856.com/ind2_1/toc_sub3']
      expect(select_by_id('856ind2is2suppl')[field]).to eq ['http://www.url856.com/ind2_2/supplementaryMaterial']
      expect(select_by_id('856ind2isBlankTocSubZ')[field]).to eq ['http://www.url856.com/ind2_blank/toc_subz']
      expect(select_by_id('856ind2isBlankTocSub3')[field]).to eq ['http://www.url856.com/ind2_blank/toc_sub3']
      expect(select_by_id('956and856TOC')[field]).to eq ['http://www.url856.com/toc']
      expect(select_by_id('956and856TOCand856suppl')[field]).to eq ['http://www.url856.com/toc', 'http://www.url856.com/ind2_2/supplMaterial']
      expect(select_by_id('856tocAnd856SupplNoFulltext')[field]).to eq ['http://www.url856.com/toc', 'http://www.url856.com/ind2_2/supplMaterial']
      expect(select_by_id('7423084')[field]).to eq ['http://www.loc.gov/catdir/samples/prin031/2001032103.html',
                                                    'http://www.loc.gov/catdir/toc/prin031/2001032103.html',
                                                    'http://www.loc.gov/catdir/description/prin022/2001032103.html']
    end

    it 'omits url_fulltext for with no urlSuppl_store in bib rec' do
      expect(select_by_id('856ind2is0')[field]).to be_nil
      expect(select_by_id('856ind2is0Again')[field]).to be_nil
      expect(select_by_id('856ind2is1NotToc')[field]).to be_nil
      expect(select_by_id('856ind2isBlankFulltext')[field]).to be_nil
      expect(select_by_id('956BlankIndicators')[field]).to be_nil
      expect(select_by_id('956ind2is0')[field]).to be_nil
      expect(select_by_id('mult856and956')[field]).to be_nil
    end

    describe '2nd indicators of 3' do
      let(:records) do
        [
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '856',
                '4',
                nil,
                MARC::Subfield.new('u', 'http://example.com/')
              )
            )
          end
        ]
      end

      it 'are not considered full text' do
        expect(results.first[field]).to be_blank
      end
    end
  end

  describe 'url_restricted' do
    let(:field) { 'url_restricted' }
    let(:fixture_name) { 'restrictedUrlTests.mrc' }

    it 'maps the right values' do
      expect(select_by_id('restrictedUrl1')[field]).to eq ['http://restricted.org']
      expect(select_by_id('restrictedUrl2')[field]).to eq ['http://restricted.org']
      expect(select_by_id('fulltextAndRestricted1')[field]).to eq ['http://restricted.org']
      expect(select_by_id('fulltextAndRestricted2')[field]).to eq ['http://restricted.org']
      expect(select_by_id('supplAndRestricted1')[field]).to eq ['http://restricted.org']
      expect(select_by_id('supplAndRestricted2')[field]).to eq ['http://restricted.org']
      expect(select_by_id('restrictedFullTextAndSuppl')[field]).to eq ['http://restricted.org']

      expect(select_by_id('fulltextUrl')[field]).to be_nil
      expect(select_by_id('supplUrl')[field]).to be_nil
      expect(select_by_id('supplUrlRestricted')[field]).to be_nil
    end

    it 'still retains unrestricted fulltext urls' do
      expect(select_by_id('fulltextUrl')['url_fulltext']).to eq ['http://www.fulltext.org/']
      expect(select_by_id('fulltextAndRestricted1')['url_fulltext']).to eq ['http://restricted.org', 'http://www.fulltext.org/']
      expect(select_by_id('fulltextAndRestricted2')['url_fulltext']).to eq ['http://www.fulltext.org/', 'http://restricted.org']
    end

    it 'still retains any sort of suppl urls (do not included restriced supplemental urls in url_restricted field.' do
      expect(select_by_id('supplUrl')['url_suppl']).to eq ['http://www.suppl.com']
      expect(select_by_id('supplUrlRestricted')['url_suppl']).to eq ['http://www.suppl.com/restricted']
      expect(select_by_id('supplAndRestricted1')['url_suppl']).to eq ['http://www.suppl.com']
      expect(select_by_id('supplAndRestricted2')['url_suppl']).to eq ['http://www.suppl.com']
      expect(select_by_id('restrictedFullTextAndSuppl')['url_suppl']).to eq ['http://www.suppl.com/restricted']
    end

    describe '2nd indicators of 3' do
      let(:records) do
        [
          MARC::Record.new.tap do |r|
            r.append(
              MARC::DataField.new(
                '856',
                '4',
                nil,
                MARC::Subfield.new('u', 'http://example.com/')
              )
            )
          end
        ]
      end

      it 'are not considered full text' do
        expect(results.first[field]).to be_blank
      end
    end
  end

  describe 'url field ordering' do
    let(:fixture_name) { 'urlOrderingTests.mrc' }

    it 'preserves field ordering from marc21 input to marc21 stored in record' do
      expect(select_by_id('fulltextOnly')['url_fulltext']).to eq ['http://first.org', 'http://second.org']

      expect(select_by_id('fulltextAndRestricted1')['url_restricted']).to eq ['http://restricted.org/first', 'http://restricted.org/second']
      expect(select_by_id('fulltextAndRestricted1')['url_fulltext']).to eq ['http://first.org', 'http://second.org',
                                                                            'http://restricted.org/first', 'http://restricted.org/second']

      expect(select_by_id('fulltextAndRestricted2')['url_restricted']).to eq ['http://restricted.org/first', 'http://restricted.org/second']
      expect(select_by_id('fulltextAndRestricted2')['url_fulltext']).to eq ['http://first.org',
                                                                            'http://restricted.org/first', 'http://second.org', 'http://restricted.org/second']

      expect(select_by_id('fulltextAndRestricted3')['url_restricted']).to eq ['http://restricted.org/first', 'http://restricted.org/second']
      expect(select_by_id('fulltextAndRestricted3')['url_fulltext']).to eq ['http://restricted.org/first',
                                                                            'http://first.org', 'http://second.org', 'http://restricted.org/second']

      expect(select_by_id('fulltextAndRestricted4')['url_restricted']).to eq ['http://restricted.org/first', 'http://restricted.org/second']
      expect(select_by_id('fulltextAndRestricted4')['url_fulltext']).to eq ['http://first.org',
                                                                            'http://restricted.org/first', 'http://restricted.org/second', 'http://second.org']

      expect(select_by_id('fulltextAndSuppl1')['url_restricted']).to eq ['http://restricted.org/first', 'http://restricted.org/second']
      expect(select_by_id('fulltextAndSuppl1')['url_fulltext']).to eq ['http://www.fulltext.org/first',
                                                                       'http://www.fulltext.org/second', 'http://restricted.org/first', 'http://restricted.org/second']
      expect(select_by_id('fulltextAndSuppl1')['url_suppl']).to eq ['http://www.suppl.com/first', 'http://www.suppl.com/second']

      expect(select_by_id('fulltextAndSuppl2')['url_restricted']).to eq ['http://restricted.org/first', 'http://restricted.org/second']
      expect(select_by_id('fulltextAndSuppl2')['url_fulltext']).to eq ['http://restricted.org/first',
                                                                       'http://www.fulltext.org/first', 'http://www.fulltext.org/second', 'http://restricted.org/second']
      expect(select_by_id('fulltextAndSuppl2')['url_suppl']).to eq ['http://www.suppl.com/first', 'http://www.suppl.com/second']

      expect(select_by_id('fulltextAndSuppl3')['url_restricted']).to eq ['http://restricted.org/first', 'http://restricted.org/second']
      expect(select_by_id('fulltextAndSuppl3')['url_fulltext']).to eq ['http://www.fulltext.org/first',
                                                                       'http://restricted.org/first', 'http://www.fulltext.org/second', 'http://restricted.org/second']
      expect(select_by_id('fulltextAndSuppl3')['url_suppl']).to eq ['http://www.suppl.com/first', 'http://www.suppl.com/second']

      expect(select_by_id('fulltextAndSuppl4')['url_restricted']).to eq ['http://restricted.org/first', 'http://restricted.org/second']
      expect(select_by_id('fulltextAndSuppl4')['url_fulltext']).to eq ['http://restricted.org/first',
                                                                       'http://restricted.org/second', 'http://www.fulltext.org/first', 'http://www.fulltext.org/second']
      expect(select_by_id('fulltextAndSuppl4')['url_suppl']).to eq ['http://www.suppl.com/first', 'http://www.suppl.com/second']
    end
  end
end
