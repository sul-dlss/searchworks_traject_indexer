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
end
