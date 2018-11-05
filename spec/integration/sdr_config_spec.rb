require 'spec_helper'

describe 'SDR indexing' do
  subject(:result) { indexer.map_record(PublicXmlRecord.new('bk264hq9320')) }

  def stub_purl_request(druid, body)
    without_partial_double_verification do
      if defined?(JRUBY_VERSION)
        allow(Manticore).to receive(:get).with("https://purl.stanford.edu/#{druid}.xml").and_return(double(code: 200, body: body))
      else
        allow(HTTP).to receive(:get).with("https://purl.stanford.edu/#{druid}.xml").and_return(double(body: body, status: double(ok?: true)))
      end
    end
  end

  def stub_mods_request(druid, body)
    without_partial_double_verification do
      if defined?(JRUBY_VERSION)
        allow(Manticore).to receive(:get).with("https://purl.stanford.edu/#{druid}.mods").and_return(double(code: 200, body: body))
      else
        allow(HTTP).to receive(:get).with("https://purl.stanford.edu/#{druid}.mods").and_return(double(body: body, status: double(ok?: true)))
      end
    end
  end

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sdr_config.rb')
    end
  end

  context 'with a missing object' do
    before do
      without_partial_double_verification do
        if defined?(JRUBY_VERSION)
          allow(Manticore).to receive(:get).with('https://purl.stanford.edu/bk264hq9320.xml').and_return(double(code: 404))
        else
          allow(HTTP).to receive(:get).with('https://purl.stanford.edu/bk264hq9320.xml').and_return(double(status: double(ok?: false)))
        end
      end
    end

    it 'maps the data the same way as it does currently' do
      expect(result).to be_nil
    end
  end

  context 'with bk264hq9320' do
    before do
      stub_purl_request('bk264hq9320', File.read(file_fixture('bk264hq9320.xml').to_s))
      stub_purl_request('nj770kg7809', File.read(file_fixture('nj770kg7809.xml').to_s))
    end

    it 'maps the data the same way as it does currently' do
      expect(result).to include "id" => ["bk264hq9320"],
                                "druid" => ["bk264hq9320"],
                                "title_245a_search" => ["Trustees Demo reel"],
                                "title_245_search" => ["Trustees Demo reel."],
                                "title_sort" => ["Trustees Demo reel"],
                                "title_245a_display" => ["Trustees Demo reel"],
                                "title_display" => ["Trustees Demo reel"],
                                "title_full_display" => ["Trustees Demo reel."],
                                "author_7xx_search" =>["Stanford University. News and Publications Service"],
                                "author_other_facet" =>["Stanford University. News and Publications Service"],
                                "author_sort" => ["􏿿 Trustees Demo reel"],
                                "author_corp_display" =>["Stanford University. News and Publications Service"],
                                "pub_search" =>["cau", "Stanford (Calif.)"],
                                "pub_year_isi" =>[2004],
                                "pub_date_sort" => ["2004"],
                                "imprint_display" => ["Stanford (Calif.), February 9, 2004"],
                                "pub_date" => ["2004"],
                                "pub_year_ss" => ["2004"],
                                "pub_year_tisim" =>[2004],
                                "creation_year_isi" =>[2004],
                                "format_main_ssim" =>["Video"],
                                "language" =>["English"],
                                "physical" =>["1 MiniDV tape"],
                                "url_suppl" =>[
                                  "http://www.oac.cdlib.org/findaid/ark:/13030/c8dn43sv",
                                  "https://purl.stanford.edu/nj770kg7809"
                                ],
                                "url_fulltext" => ["https://purl.stanford.edu/bk264hq9320"],
                                "access_facet" => ["Online"],
                                "building_facet" => ["Stanford Digital Repository"],
                                "collection" =>["9665836"],
                                "collection_with_title" =>["9665836-|-Stanford University, News and Publication Service, audiovisual recordings, 1936-2011 (inclusive)"],
                                "all_search" => [" Trustees Demo reel Stanford University. News and Publications Service pro producer moving image cau Stanford (Calif.) 2004-02-09 eng English videocassette 1 MiniDV tape access reformatted digital video/mp4 image/jpeg NTSC Sound Color Reformatted by Stanford University Libraries in 2017. sc1125_s02_b11_04-0209-1 Stanford University. Libraries. Department of Special Collections and University Archives SC1125 https://purl.stanford.edu/bk264hq9320 Stanford University, News and Publication Service, Audiovisual Recordings (SC1125) http://www.oac.cdlib.org/findaid/ark:/13030/c8dn43sv English eng CSt human prepared Stanford University, News and Publication Service, audiovisual recordings, 1936-2011 (inclusive) https://purl.stanford.edu/nj770kg7809 The materials are open for research use and may be used freely for non-commercial purposes with an attribution. For commercial permission requests, please contact the Stanford University Archives (universityarchives@stanford.edu). "]

      expect(result).to include "modsxml"

      expect(result).not_to include "title_variant_search", "author_meeting_display", "author_person_display", "author_person_full_display", "author_1xx_search",
                                    "topic_search", "geographic_search", "subject_other_search", "subject_other_subvy_search", "subject_all_search",
                                    "topic_facet", "geographic_facet", "era_facet", "publication_year_isi", "genre_ssim", "summary_search", "toc_search", "file_id",
                                    "set", "set_with_title"
    end
  end
  context 'with vv853br8653' do
    subject(:result) { indexer.map_record(PublicXmlRecord.new('vv853br8653')) }

    before do
      stub_purl_request('vv853br8653', File.read(file_fixture('vv853br8653.xml').to_s))
      stub_purl_request('zc193vn8689', File.read(file_fixture('zc193vn8689.xml').to_s))
    end
    it 'maps schema.org data for geo content' do
      expect(result['schema_dot_org_struct'].first).to include '@context': 'http://schema.org',
                                                                '@type': 'Dataset',
                                                                citation: /Pinsky/,
                                                                description: [/This dataset/, /The Conservation/],
                                                                distribution: [
                                                                  {
                                                                    '@type': 'DataDownload',
                                                                    contentUrl: 'https://stacks.stanford.edu/file/druid:vv853br8653/data.zip',
                                                                    encodingFormat: 'application/zip'
                                                                  }
                                                                ],
                                                                identifier: ['https://purl.stanford.edu/vv853br8653'],
                                                                includedInDataCatalog: {
                                                                  '@type': 'DataCatalog',
                                                                  name: 'https://earthworks.stanford.edu'
                                                                },
                                                                keywords: ['Marine habitat conservation', 'Freshwater habitat conservation', 'Pacific salmon', 'Conservation', 'Watersheds', 'Environment', 'Oceans', 'Inland Waters', 'North Pacific Ocean', '1978', '2005'],
                                                                license: 'CC by-nc: CC BY-NC Attribution-NonCommercial',
                                                                name: ['Abundance Estimates of the Pacific Salmon Conservation Assessment Database, 1978-2008'],
                                                                sameAs: 'https://searchworks.stanford.edu/view/vv853br8653'
    end

  end

  describe 'stanford_work_facet_hsim' do
    subject(:result) { indexer.map_record(PublicXmlRecord.new('abc')) }

    before do
      stub_purl_request(druid, data)
      stub_purl_request(collection_druid, collection_data)
    end

    let(:druid) { 'abc' }
    let(:collection_druid) { 'abccoll' }
    let(:collection_label) { '' }
    let(:data) do
      <<-XML
        <publicObject>
          <mods xmlns="http://www.loc.gov/mods/v3">
            #{mods_fragment}
          </mods>
          <rdf:RDF xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:hydra="http://projecthydra.org/ns/relations#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <rdf:Description rdf:about="info:fedora/druid:#{druid}">
              <fedora:isMemberOfCollection rdf:resource="info:fedora/druid:#{collection_druid}"/>
            </rdf:Description>
          </rdf:RDF>
        </publicObject>
      XML
    end
    let(:collection_data) do
      <<-XML
        <publicObject>
          <identityMetadata>
            <objectLabel>#{collection_label}</objectLabel>
          </identityMetadata>
        </publicObject>
      XML
    end

    context 'with an honors thesis' do
      let(:mods_fragment) do
        <<-XML
          <genre authority="marcgt">thesis</genre>
        XML
      end
      let(:collection_label) { "Undergraduate Honors Theses, Department of Communication, Stanford University" }

      it 'maps to Thesis/Dissertation > Bachelor\'s > Undergraduate honors thesis' do
        expect(result['stanford_work_facet_hsim'].first).to eq 'Thesis/Dissertation|Bachelor\'s|Undergraduate honors thesis'
      end
    end

    context 'with a capstone thesis' do
      let(:mods_fragment) do
        <<-XML
          <genre authority="marcgt">thesis</genre>
        XML
      end
      let(:collection_label) { "Stanford University Urban Studies Capstone Projects and Theses" }

      it 'maps to Thesis/Dissertation > Bachelor\'s > Unspecified' do
        expect(result['stanford_work_facet_hsim'].first).to eq 'Thesis/Dissertation|Bachelor\'s|Unspecified'
      end

    end

    context 'with a master\'s thesis' do
      let(:mods_fragment) do
        <<-XML
          <genre authority="marcgt">thesis</genre>
        XML
      end
      let(:collection_label) { "Masters Theses in Russian, East European and Eurasian Studies" }

      it 'maps to Thesis/Dissertation > Master\'s > Unspecified' do
        expect(result['stanford_work_facet_hsim'].first).to eq 'Thesis/Dissertation|Master\'s|Unspecified'

      end

    end

    context 'with a doctoral thesis' do
      let(:mods_fragment) do
        <<-XML
          <genre authority="marcgt">thesis</genre>
        XML
      end
      let(:collection_label) { "PhD Dissertations, Stanford Earth" }

      it 'maps to Thesis/Dissertation > Doctoral > Unspecified' do
        expect(result['stanford_work_facet_hsim'].first).to eq 'Thesis/Dissertation|Doctoral|Unspecified'

      end

    end

    context 'with some other thesis' do
      let(:mods_fragment) do
        <<-XML
          <genre authority="marcgt">thesis</genre>
        XML
      end
      let(:collection_label) { "Stanford University Libraries Theses" }

      it 'maps to Thesis/Dissertation > Unspecified' do
        expect(result['stanford_work_facet_hsim'].first).to eq 'Thesis/Dissertation|Unspecified'
      end

    end

    context 'with a student report' do
      let(:mods_fragment) do
        <<-XML
          <genre authority="marcgt">student project report</genre>
        XML
      end
      it 'maps to Other student work > Student report' do
        expect(result['stanford_work_facet_hsim'].first).to eq 'Other student work|Student report'
      end
    end
  end

  describe 'identifiers' do
    subject(:result) { indexer.map_record(PublicXmlRecord.new('abc')) }

    before do
      stub_purl_request(druid, data)
    end

    let(:druid) { 'abc' }
    let(:data) do
      <<-XML
        <publicObject>
          <mods xmlns="http://www.loc.gov/mods/v3">
            <identifier type="isbn">isbn-id</identifier>
            <identifier type="issn">issn-id</identifier>
            <identifier type="oclc">oclc-id</identifier>
            <identifier type="lccn">lccn-id-1</identifier>
            <identifier type="lccn">lccn-id-2</identifier>
            <identifier type="garbage">garbage-id</identifier>
            <identifier>no-type-id</identifier>
          </mods>
        </publicObject>
      XML
    end

    it 'maps the appropriate identifier types' do
      expect(result['isbn_search']).to eq ['isbn-id']
      expect(result['isbn_display']).to eq ['isbn-id']
      expect(result['issn_search']).to eq ['issn-id']
      expect(result['issn_display']).to eq ['issn-id']
      expect(result['oclc']).to eq ['oclc-id']
      expect(result['lccn']).to eq ['lccn-id-1']
    end
  end

  context 'dates' do
    subject(:result) { indexer.map_record(PublicXmlRecord.new('abc')) }

    before do
      stub_purl_request(druid, data)
    end

    let(:druid) { 'abc' }
    let(:data) do
      <<-XML
        <publicObject>
          <mods xmlns="http://www.loc.gov/mods/v3">
            #{mods_fragment}
          </mods>
        </publicObject>
      XML
    end

    describe 'beginning_year_isi' do
      let(:mods_fragment) do
        <<-XML
          <originInfo>
            <issuance>continuing</issuance>
            <dateIssued point="start">1743-01</dateIssued>
          </originInfo>
          XML
      end

      it 'maps the right data' do
        expect(result['beginning_year_isi']).to eq ['1743']
      end
    end

    describe 'ending_year_isi' do
      let(:mods_fragment) do
        <<-XML
          <originInfo>
            <issuance>serial</issuance>
            <dateIssued point="end">1743-01-01</dateIssued>
          </originInfo>
          XML
      end

      it 'maps the right data' do
        expect(result['ending_year_isi']).to eq ['1743']
      end
    end

    describe 'earliest_year_isi' do
      let(:mods_fragment) do
        <<-XML
          <typeOfResource collection="yes" />
          <originInfo>
            <dateCreated point="start">2011</dateIssued>
          </originInfo>
          XML
      end

      it 'maps the right data' do
        expect(result['earliest_year_isi']).to eq ['2011']
      end
    end

    describe 'latest_year_isi' do
      let(:mods_fragment) do
        <<-XML
          <typeOfResource collection="yes" />
          <originInfo>
            <dateCreated point="end">2016</dateIssued>
          </originInfo>
          XML
      end

      it 'maps the right data' do
        expect(result['latest_year_isi']).to eq ['2016']
      end
    end

    describe 'earliest_poss_year_isi' do
      let(:mods_fragment) do
        <<-XML
          <originInfo>
            <dateCreated point="start" qualifier="maybe">2016</dateIssued>
          </originInfo>
          XML
      end

      it 'maps the right data' do
        expect(result['earliest_poss_year_isi']).to eq ['2016']
      end
    end

    describe 'latest_poss_year_isi' do
      let(:mods_fragment) do
        <<-XML
          <originInfo>
            <dateCreated point="end" qualifier="maybe">2016</dateIssued>
          </originInfo>
          XML
      end

      it 'maps the right data' do
        expect(result['latest_poss_year_isi']).to eq ['2016']
      end
    end


    describe 'production_year_isi' do
      let(:mods_fragment) do
        <<-XML
          <originInfo eventType="production">
            <dateIssued>2012</dateIssued>
          </originInfo>
          XML
      end

      it 'maps the right data' do
        expect(result['production_year_isi']).to eq ['2012']
      end
    end

    describe 'release_year_isi' do
      let(:mods_fragment) do
        <<-XML
          <originInfo eventType="distribution">
            <dateIssued>1987</dateIssued>
          </originInfo>
          XML
      end

      it 'maps the right data' do
        expect(result['release_year_isi']).to eq ['1987']
      end
    end

    describe 'copyright_year_isi' do
      let(:mods_fragment) do
        <<-XML
          <originInfo>
            <copyrightDate>1923</copyrightDate>
          </originInfo>
          XML
      end

      it 'maps the right data' do
        expect(result['copyright_year_isi']).to eq ['1923']
      end
    end
  end

  context 'pub_country' do
    subject(:result) { indexer.map_record(PublicXmlRecord.new('abc')) }

    before do
      stub_purl_request(druid, data)
    end

    let(:druid) { 'abc' }
    let(:data) do
      <<-XML
        <publicObject>
          <mods xmlns="http://www.loc.gov/mods/v3">
            #{mods_fragment}
          </mods>
        </publicObject>
      XML
    end

    describe 'pub_country' do
      let(:mods_fragment) do
        <<-XML
          <originInfo>
            <place>
              <placeTerm type="code" authority="marccountry">
                aq
              </placeTerm>
            </place>
            <place>
              <placeTerm type="code" authority="whatever">
                aa
              </placeTerm>
            </place>
          </originInfo>
          XML
      end

      it 'maps the right data' do
        expect(result['pub_country']).to eq ['Antigua and Barbuda']
      end
    end
  end
  context 'with zz400gd3785' do
    subject(:result) { indexer.map_record(PublicXmlRecord.new('zz400gd3785')) }
    before do
      stub_purl_request('zz400gd3785', File.read(file_fixture('zz400gd3785.xml').to_s))
      stub_purl_request('sg213ph2100', File.read(file_fixture('sg213ph2100.xml').to_s))
    end
    it 'maps the data' do
      expect(result).to include 'summary_display' => ['Topographical and street map of the western part of the city of San Francisco, with red indicating fire area.  Annotations:  “Area, approximately 4 square miles”;  entire title reads: “Reproduction from the Official Map of San Francisco, Showing the District Swept by Fire of April 18, 19, 20, 1906.”']
    end
  end
  context 'with df650pk4327' do
    subject(:result) { indexer.map_record(PublicXmlRecord.new('df650pk4327')) }
    before do
      stub_purl_request('df650pk4327', File.read(file_fixture('df650pk4327.xml').to_s))
      stub_mods_request('df650pk4327', File.read(file_fixture('df650pk4327.mods')))
      stub_purl_request('hn730ks3626', File.read(file_fixture('hn730ks3626.xml').to_s))
    end
    it 'turns mods author data into a structure' do
      expect(
        result['author_struct'].length
      ).to eq 3
      expect(
        result['author_struct'].first
      ).to include(link: 'Snydman, Stuart', post_text: '(Author)', search: '"Snydman, Stuart"')
    end
    it 'dates not available are nil' do
      %w[beginning_year_isi ending_year_isi earliest_year_isi latest_year_isi earliest_poss_year_isi latest_poss_year_isi release_year_isi production_year_isi copyright_year_isi].each do |field|
        expect(result[field]).to be_nil
      end
    end
  end
end
