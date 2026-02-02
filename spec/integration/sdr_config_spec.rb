# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SDR indexing' do
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sdr_config.rb')
    end
  end
  let(:druid) { 'sw705fr7011' }
  let(:collection_druid) { 'vm093fg5170' }
  let(:record) { PurlRecord.new(druid) }
  let(:body) { File.new(file_fixture("#{druid}.json")) }
  let(:xml_body) { File.new(file_fixture("#{druid}.xml")) }
  let(:metadata_json) { File.new(file_fixture("#{druid}.meta_json")) }
  let(:collection_body) { File.new(file_fixture("#{collection_druid}.json")) }

  before do
    stub_request(:get, "https://purl.stanford.edu/#{druid}.json").to_return(status: 200, body:)
    stub_request(:get, "https://purl.stanford.edu/#{druid}.xml").to_return(status: 200, body: xml_body)
    stub_request(:get, "https://purl.stanford.edu/#{druid}.meta_json").to_return(status: 200, body: metadata_json)
    stub_request(:get, "https://purl.stanford.edu/#{collection_druid}.json").to_return(status: 200, body: collection_body)
    allow(record).to receive(:catkey).and_return(nil) # make sure it is indexable
  end

  it 'maps the druid as the id' do
    expect(result['id']).to eq [druid]
  end

  it 'maps a hashed id for sitemap generation' do
    expect(result['hashed_id_ssi']).to eq [Digest::MD5.hexdigest(druid)]
  end

  it 'maps the druid' do
    expect(result['druid']).to eq [druid]
  end

  it 'maps the entire mods XML record' do
    expect(result['modsxml'].first).to include '<mods'
  end

  it 'maps all text for searching' do
    # rubocop:disable Layout/LineLength
    expect(result['all_search'].first).to eq 'Oral history interview with anonymous, white, female, SNCC volunteer, 0405 (sides 1 and 2), Laurel, Mississippi 0405 28 anonymous ive Interviewee Student Nonviolent Coordinating Committee (U.S.) spn Sponsor 1965 w3cdtf Laurel (Miss.) msu Mississippi sound recording-nonmusical oral histories audiotape reel access audio/mpeg 1 audiotape reformatted digital Magnetic 3.75 ips Mono NAB standard access 1 transcript born digital eng English Reformatted by Stanford University Libraries between 2009-2011. 0405 Civil rights United States Civil rights movements SC0066 Stanford University. Libraries. Department of Special Collections and University Archives eng Latn KZSU Project South Interviews (SC0066) https://oac.cdlib.org/findaid/ark:/13030/tf7489n969/ Transcript CSt original cataloging agency eng English human prepared'
    # rubocop:enable Layout/LineLength
  end

  describe 'title fields' do
    it 'maps the short title' do
      expect(result['title_245a_search']).to eq ['Oral history interview with anonymous, white, female, SNCC volunteer, 0405 (sides 1 and 2), Laurel, Mississippi']
    end

    it 'maps the full title' do
      expect(result['title_full_display']).to eq ['Oral history interview with anonymous, white, female, SNCC volunteer, 0405 (sides 1 and 2), Laurel, Mississippi. 0405.']
      expect(result['title_245_search']).to eq ['Oral history interview with anonymous, white, female, SNCC volunteer, 0405 (sides 1 and 2), Laurel, Mississippi. 0405.']
    end

    it 'maps the display title' do
      expect(result['title_display']).to eq ['Oral history interview with anonymous, white, female, SNCC volunteer, 0405 (sides 1 and 2), Laurel, Mississippi. 0405']
    end

    it 'maps the sort title' do
      expect(result['title_sort']).to eq ['anonymous white female SNCC volunteer 0405 sides 1 and 2 Laurel Mississippi 0405']
      expect(result['title_245a_display']).to eq ['anonymous white female SNCC volunteer 0405 sides 1 and 2 Laurel Mississippi 0405']
    end

    context 'with no titles' do
      before { allow(record.public_cocina).to receive(:display_title).and_return(nil) }

      it 'maps a fallback value' do
        expect(result['title_display']).to eq ['[Untitled]']
      end
    end

    context 'with additional titles' do
      let(:druid) { 'dc482zx1528' }
      let(:collection_druid) { 'bf420qj4978' }

      it 'maps the additional titles' do
        expect(result['title_variant_search']).to eq ['上州草津温泉圖', 'Jōshū Kusatsu Onsen zu']
      end
    end
  end

  describe 'author fields' do
    let(:druid) { 'kf879tn8532' }

    it 'maps the main contributor name for search' do
      expect(result['author_1xx_search']).to eq ['Rifat Paşa, Mehmet Sadık']
    end

    it 'maps the additional contributor names for search' do
      expect(result['author_7xx_search']).to eq ['Gabbay, Yehezkel', 'Jerusalmi, Isaac', 'Taube Center for Jewish Studies (Stanford University), Sephardic Studies Project']
    end

    it 'maps the personal contributor names for faceting' do
      expect(result['author_person_facet']).to eq ['Rifat Paşa, Mehmet Sadık', 'Gabbay, Yehezkel', 'Jerusalmi, Isaac']
    end

    it 'maps the impersonal contributor names for faceting' do
      expect(result['author_other_facet']).to eq ['Taube Center for Jewish Studies (Stanford University), Sephardic Studies Project']
    end

    it 'maps the sort contributor name with title' do
      expect(result['author_sort']).to eq ['Rifat Paşa Mehmet Sadık Mehmet Sadik Rifat Pashas Risalei ahlak']
    end

    it 'maps the organization contributor names for display' do
      expect(result['author_corp_display']).to eq ['Taube Center for Jewish Studies (Stanford University), Sephardic Studies Project']
    end

    it 'maps the main contributor name for display with date' do
      expect(result['author_person_display']).to eq ['Rifat Paşa, Mehmet Sadık, 1807-1856']
      expect(result['author_person_full_display']).to eq ['Rifat Paşa, Mehmet Sadık, 1807-1856']
    end

    it 'maps the structured version of the author names for linking' do
      expect(result['author_struct']).to eq [
        {
          'link' => 'Rifat Paşa, Mehmet Sadık, 1807-1856',
          'search' => '"Rifat Paşa, Mehmet Sadık"',
          'post_text' => '(author)'
        },
        {
          'link' => 'Gabbay, Yehezkel, 1825-1898',
          'search' => '"Gabbay, Yehezkel"',
          'post_text' => '(translator)'
        },
        {
          'link' => 'Jerusalmi, Isaac, 1928-2018',
          'search' => '"Jerusalmi, Isaac"',
          'post_text' => '(editor)'
        },
        {
          'link' => 'Taube Center for Jewish Studies (Stanford University), Sephardic Studies Project',
          'search' => '"Taube Center for Jewish Studies (Stanford University), Sephardic Studies Project"'
        }
      ]
    end
  end

  describe 'subject fields' do
    let(:druid) { 'vv853br8653' }

    it 'maps the topic subjects for search' do
      expect(result['topic_search']).to eq ['Marine habitat conservation', 'Freshwater habitat conservation', 'Pacific salmon', 'Conservation', 'Watersheds', 'Environment', 'Oceans', 'Inland Waters']
    end

    it 'maps the geographic subjects for search' do
      expect(result['geographic_search']).to eq ['North Pacific Ocean']
    end

    it 'maps the temporal and genre subjects for search' do
      expect(result['subject_other_subvy_search']).to eq ['1978 - 2005']
    end

    it 'maps all subjects for search' do
      expect(result['subject_all_search']).to eq ['Marine habitat conservation', 'Freshwater habitat conservation', 'Pacific salmon', 'Conservation', 'Watersheds', 'Environment', 'Oceans', 'Inland Waters', '1978 - 2005', 'North Pacific Ocean']
    end

    it 'maps the topic subjects for faceting' do
      expect(result['topic_facet']).to eq ['Marine habitat conservation', 'Freshwater habitat conservation', 'Pacific salmon', 'Conservation', 'Watersheds', 'Environment', 'Oceans', 'Inland Waters']
    end

    it 'maps the geographic subjects for faceting' do
      expect(result['geographic_facet']).to eq ['North Pacific Ocean']
    end

    it 'maps the temporal subjects for faceting' do
      expect(result['era_facet']).to eq ['1978 - 2005']
    end
  end

  #   it 'maps the data the same way as it does currently' do
  #     expect(result).to include(
  #       {
  #         'id' => ['bk264hq9320'],
  #         'hashed_id_ssi' => ['6f9a6cccb27e922d48ee5803d9433648'],
  #         'druid' => ['bk264hq9320'],
  #         'title_245a_search' => ['Trustees Demo reel'],
  #         'title_245_search' => ['Trustees Demo reel.'],
  #         'title_sort' => ['Trustees Demo reel'],
  #         'title_245a_display' => ['Trustees Demo reel'],
  #         'title_display' => ['Trustees Demo reel'],
  #         'title_full_display' => ['Trustees Demo reel.'],
  #         'author_7xx_search' => ['Stanford University. News and Publications Service'],
  #         'author_other_facet' => ['Stanford University. News and Publications Service'],
  #         'author_sort' => ["\u{10FFFF} Trustees Demo reel"],
  #         'author_corp_display' => ['Stanford University. News and Publications Service'],
  #         'pub_search' => ['cau', 'Stanford (Calif.)'],
  #         'pub_year_isi' => [2004],
  #         'pub_date_sort' => ['2004'],
  #         'imprint_display' => ['Stanford (Calif.), February  9, 2004'],
  #         'pub_date' => ['2004'],
  #         'pub_year_ss' => ['2004'],
  #         'pub_year_tisim' => [2004],
  #         'format_main_ssim' => ['Video'],
  #         'language' => ['English'],
  #         'physical' => ['1 MiniDV tape'],
  #         'url_suppl' => [
  #           'http://www.oac.cdlib.org/findaid/ark:/13030/c8dn43sv',
  #           'https://purl.stanford.edu/nj770kg7809'
  #         ],
  #         'url_fulltext' => ['https://purl.stanford.edu/bk264hq9320'],
  #         'access_facet' => ['Online'],
  #         'building_facet' => ['Stanford Digital Repository'],
  #         'library_code_facet_ssim' => ['SDR'],
  #         'collection' => ['a9665836'],
  #         'collection_with_title' => ['a9665836-|-Stanford University, News and Publication Service, audiovisual recordings, 1936-2011 (inclusive)'],
  #         'all_search' => [' Trustees Demo reel Stanford University. News and Publications Service pro producer moving image cau Stanford (Calif.) 2004-02-09 eng English videocassette 1 MiniDV tape access reformatted digital video/mp4 image/jpeg NTSC Sound Color Reformatted by Stanford University Libraries in 2017. sc1125_s02_b11_04-0209-1 Stanford University. Libraries. Department of Special Collections and University Archives SC1125 https://purl.stanford.edu/bk264hq9320 Stanford University, News and Publication Service, Audiovisual Recordings (SC1125) http://www.oac.cdlib.org/findaid/ark:/13030/c8dn43sv English eng CSt human prepared Stanford University, News and Publication Service, audiovisual recordings, 1936-2011 (inclusive) https://purl.stanford.edu/nj770kg7809 The materials are open for research use and may be used freely for non-commercial purposes with an attribution. For commercial permission requests, please contact the Stanford University Archives (universityarchives@stanford.edu). '] # rubocop:disable Layout/LineLength
  #       }
  #     )

  #     expect(result).to include 'modsxml'

  #     expect(result).not_to include(
  #       'title_variant_search', 'author_meeting_display', 'author_person_display', 'author_person_full_display', 'author_1xx_search',
  #       'topic_search', 'geographic_search', 'subject_other_search', 'subject_other_subvy_search', 'subject_all_search',
  #       'topic_facet', 'geographic_facet', 'era_facet', 'genre_ssim', 'summary_search', 'toc_search', 'file_id',
  #       'set', 'set_with_title'
  #     )
  #   end
  # end

  xcontext 'with vv853br8653' do
    let(:druid) { 'vv853br8653' }
    let(:collection_druid) { 'zc193vn8689' }

    before do
      stub_purl_request(druid, xml: File.read(file_fixture("#{druid}.xml").to_s), json: File.read(file_fixture("#{druid}.json").to_s))
      stub_purl_request(collection_druid, xml: File.read(file_fixture("#{collection_druid}.xml").to_s), json: File.read(file_fixture("#{collection_druid}.json").to_s))
    end

    context 'geo is released to earthworks' do
      it 'maps schema.org data for geo content' do
        expect(JSON.parse(result['schema_dot_org_struct'].first)).to include(
          {
            '@context' => 'http://schema.org',
            '@type' => 'Dataset',
            'citation' => /Pinsky/,
            'description' => [/This dataset/,
                              /The Conservation/],
            'distribution' => [
              {
                '@type' => 'DataDownload',
                'contentUrl' => 'https://stacks.stanford.edu/file/druid:vv853br8653/data.zip',
                'encodingFormat' => 'application/zip'
              }
            ],
            'identifier' => ['https://purl.stanford.edu/vv853br8653'],
            'includedInDataCatalog' => {
              '@type' => 'DataCatalog',
              'name' => 'https://earthworks.stanford.edu'
            },
            'keywords' => ['Marine habitat conservation',
                           'Freshwater habitat conservation', 'Pacific salmon', 'Conservation', 'Watersheds',
                           'Environment', 'Oceans', 'Inland Waters', 'North Pacific Ocean', '1978', '2005',
                           'Geospatial data', 'cartographic dataset'],
            'license' => 'CC by-nc: CC BY-NC Attribution-NonCommercial',
            'name' => ['Abundance Estimates of the Pacific Salmon Conservation Assessment Database, 1978-2008'],
            'sameAs' => 'https://searchworks.stanford.edu/view/vv853br8653'
          }
        )
      end
    end

    context 'geo is not released to earthworks' do
      let(:earthworks) { false }

      it 'maps schema.org data for geo content' do
        expect(JSON.parse(result['schema_dot_org_struct'].first)).to include(
          {
            '@context' => 'http://schema.org',
            '@type' => 'Dataset',
            'citation' => /Pinsky/,
            'description' => [/This dataset/,
                              /The Conservation/],
            'distribution' => [
              {
                '@type' => 'DataDownload',
                'contentUrl' => 'https://stacks.stanford.edu/file/druid:vv853br8653/data.zip',
                'encodingFormat' => 'application/zip'
              }
            ],
            'identifier' => ['https://purl.stanford.edu/vv853br8653'],
            'keywords' => ['Marine habitat conservation',
                           'Freshwater habitat conservation', 'Pacific salmon', 'Conservation', 'Watersheds',
                           'Environment', 'Oceans', 'Inland Waters', 'North Pacific Ocean', '1978', '2005',
                           'Geospatial data', 'cartographic dataset'],
            'license' => 'CC by-nc: CC BY-NC Attribution-NonCommercial',
            'name' => ['Abundance Estimates of the Pacific Salmon Conservation Assessment Database, 1978-2008'],
            'sameAs' => 'https://searchworks.stanford.edu/view/vv853br8653'
          }
        )
      end
    end
  end

  describe 'stanford_work_facet_hsim' do
    let(:druid) { 'abc' }
    let(:collection_druid) { 'abccoll' }
    let(:collection_label) { '' }
    let(:xml_data) do
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
    let(:collection_xml_data) do
      <<-XML
      <publicObject>
        <identityMetadata>
          <objectLabel>#{collection_label}</objectLabel>
        </identityMetadata>
      </publicObject>
      XML
    end
    let(:collection_json_data) do
      {
        'label' => collection_label
      }.to_json
    end

    before do
      stub_purl_request(druid, xml: xml_data, json: '{}')
      stub_purl_request(collection_druid, xml: collection_xml_data, json: collection_json_data)
    end

    xcontext 'with an honors thesis' do
      let(:mods_fragment) do
        <<-XML
          <genre authority="marcgt">thesis</genre>
        XML
      end
      let(:collection_label) { 'Undergraduate Honors Theses, Department of Communication, Stanford University' }

      it 'maps to Thesis/Dissertation > Bachelor\'s > Undergraduate honors thesis' do
        expect(result['stanford_work_facet_hsim'].first).to eq 'Thesis/Dissertation|Bachelor\'s|Undergraduate honors thesis'
      end
    end

    xcontext 'with a capstone thesis' do
      let(:mods_fragment) do
        <<-XML
          <genre authority="marcgt">thesis</genre>
        XML
      end
      let(:collection_label) { 'Stanford University Urban Studies Capstone Projects and Theses' }

      it 'maps to Thesis/Dissertation > Bachelor\'s > Unspecified' do
        expect(result['stanford_work_facet_hsim'].first).to eq 'Thesis/Dissertation|Bachelor\'s|Unspecified'
      end
    end

    xcontext 'with a master\'s thesis' do
      let(:mods_fragment) do
        <<-XML
          <genre authority="marcgt">thesis</genre>
        XML
      end
      let(:collection_label) { 'Masters Theses in Russian, East European and Eurasian Studies' }

      it 'maps to Thesis/Dissertation > Master\'s > Unspecified' do
        expect(result['stanford_work_facet_hsim'].first).to eq 'Thesis/Dissertation|Master\'s|Unspecified'
      end
    end

    xcontext 'with a doctoral thesis' do
      let(:mods_fragment) do
        <<-XML
          <genre authority="marcgt">thesis</genre>
        XML
      end
      let(:collection_label) { 'PhD Dissertations, Stanford Earth' }

      it 'maps to Thesis/Dissertation > Doctoral > Unspecified' do
        expect(result['stanford_work_facet_hsim'].first).to eq 'Thesis/Dissertation|Doctoral|Unspecified'
      end
    end

    xcontext 'with some other thesis' do
      let(:mods_fragment) do
        <<-XML
          <genre authority="marcgt">thesis</genre>
        XML
      end
      let(:collection_label) { 'Stanford University Libraries Theses' }

      it 'maps to Thesis/Dissertation > Unspecified' do
        expect(result['stanford_work_facet_hsim'].first).to eq 'Thesis/Dissertation|Unspecified'
      end
    end

    xcontext 'with a student report' do
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
    let(:druid) { 'abc' }
    let(:xml_data) do
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

    before do
      stub_purl_request(druid, xml: xml_data, json: '{}')
    end

    xit 'maps the appropriate identifier types' do
      expect(result['isbn_search']).to eq ['isbn-id']
      expect(result['isbn_display']).to eq ['isbn-id']
      expect(result['issn_search']).to eq ['issn-id']
      expect(result['issn_display']).to eq ['issn-id']
      expect(result['oclc']).to eq ['oclc-id']
      expect(result['lccn']).to eq ['lccn-id-1']
    end
  end

  describe 'content metadata' do
    let(:druid) { 'abc' }
    let(:xml_data) do
      <<-XML
        <publicObject>
          <contentMetadata type="image">
            <resource id="cocina-fileSet-5925b0a8-fa41-4fb8-94e2-704fce68caf9" sequence="1" type="object">
              <label>Data</label>
              <file id="data.zip" mimetype="application/zip" size="172098005" role="master"></file>
              <file id="data_EPSG_4326.zip" mimetype="application/zip" size="146314425" role="derivative"></file>
            </resource>
            <resource id="cocina-fileSet-569954ba-6239-4222-88a4-2f8d584bfc42" sequence="2" type="preview">
              <label>Preview</label>
              <file id="preview.jpg" mimetype="image/jpeg" size="16749" role="master">
                <imageData height="200" width="300"/>
              </file>
            </resource>
          </contentMetadata>
          <mods xmlns="http://www.loc.gov/mods/v3"></mods>
        </publicObject>
      XML
    end

    before do
      stub_purl_request(druid, xml: xml_data, json: '{}')
    end

    xit 'maps the right data' do
      expect(result['dor_content_type_ssi']).to eq ['image']
      expect(result['dor_resource_content_type_ssim']).to eq %w[object preview]
      expect(result['dor_file_mimetype_ssim']).to eq ['application/zip', 'image/jpeg']
      expect(result['dor_resource_count_isi']).to eq [2]
    end
  end

  describe 'pub_country' do
    let(:druid) { 'abc' }
    let(:xml_data) do
      <<-XML
        <publicObject>
          <mods xmlns="http://www.loc.gov/mods/v3">
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
          </mods>
        </publicObject>
      XML
    end
    let(:json_data) do
      {
        'description' => {
          'event' => [
            {
              'type' => 'publication',
              'location' => [
                { 'code' => 'aq', 'source' => { 'code' => 'marccountry' } },
                { 'code' => 'aa', 'source' => { 'code' => 'whatever' } }
              ]
            }
          ]
        }
      }.to_json
    end

    before do
      stub_purl_request(druid, xml: xml_data, json: json_data)
    end

    xit 'maps the right data' do
      expect(result['pub_country']).to eq ['Antigua and Barbuda']
    end
  end

  context 'with zz400gd3785' do
    let(:druid) { 'zz400gd3785' }
    let(:collection_druid) { 'sg213ph2100' }

    before do
      stub_purl_request(druid, xml: File.read(file_fixture("#{druid}.xml").to_s), json: File.read(file_fixture("#{druid}.json").to_s))
      stub_purl_request(collection_druid, xml: File.read(file_fixture("#{collection_druid}.xml").to_s), json: File.read(file_fixture("#{collection_druid}.json").to_s))
    end

    xit 'maps the data' do
      expect(result).to include(
        {
          'summary_search' => ['Topographical and street map of the western part of the city of San Francisco, with red indicating fire area.  Annotations:  “Area, approximately 4 square miles”;  entire title reads: “Reproduction from the Official Map of San Francisco, Showing the District Swept by Fire of April 18, 19, 20, 1906.”'], # rubocop:disable Layout/LineLength
          'iiif_manifest_url_ssim' => ['https://purl.stanford.edu/zz400gd3785/iiif/manifest']
        }
      )
    end
  end

  xcontext 'with df650pk4327' do
    let(:druid) { 'df650pk4327' }
    let(:collection_druid) { 'hn730ks3626' }

    before do
      stub_purl_request(druid, xml: File.read(file_fixture("#{druid}.xml").to_s), json: File.read(file_fixture("#{druid}.json").to_s))
      stub_purl_request(collection_druid, xml: File.read(file_fixture("#{collection_druid}.xml").to_s), json: File.read(file_fixture("#{collection_druid}.json").to_s))
    end

    xit 'turns mods author data into a structure' do
      expect(
        result['author_struct'].length
      ).to eq 3
      expect(
        JSON.parse(result['author_struct'].first)
      ).to include('link' => 'Snydman, Stuart', 'search' => '"Snydman, Stuart"', 'post_text' => '(Author)')
    end

    it 'dates not available are nil' do
      %w[beginning_year_isi ending_year_isi earliest_year_isi latest_year_isi earliest_poss_year_isi
         latest_poss_year_isi release_year_isi production_year_isi copyright_year_isi].each do |field|
        expect(result[field]).to be_nil
      end
    end
  end

  describe 'SDR events' do
    before do
      allow(indexer).to receive(:logger).and_return(Logger.new(File::NULL)) # suppress logger output
      allow(Settings.sdr_events).to receive(:enabled).and_return(true)
      allow(SdrEvents).to receive_messages(
        report_indexing_success: true,
        report_indexing_deleted: true,
        report_indexing_skipped: true,
        report_indexing_errored: true
      )
    end

    context 'when the item has no public metadata' do
      before { stub_request(:get, "https://purl.stanford.edu/#{druid}.json").to_return(status: 404) }

      it 'creates an indexing skipped event with message' do
        expect(result).to be_nil
        expect(SdrEvents).to have_received(:report_indexing_skipped)
          .with(druid, message: 'No public metadata for item', target: 'Searchworks')
      end
    end

    context 'when the item has a catkey' do
      before { allow(record).to receive(:catkey).and_return('a12345') }

      it 'creates an indexing skipped event with message' do
        expect(result).to be_nil
        expect(SdrEvents).to have_received(:report_indexing_skipped)
          .with(druid, message: 'Item has a catkey', target: 'Searchworks')
      end
    end

    context 'when indexing raised an error' do
      before do
        allow(Honeybadger).to receive(:notify)
        allow(record).to receive(:dor_content_type).and_raise('Error message')
      end

      it 'creates an indexing error event with message and context' do
        expect { result }.to raise_error('Error message')
        expect(SdrEvents).to have_received(:report_indexing_errored)
          .with(
            druid,
            target: 'Searchworks',
            message: 'Error message',
            context: a_hash_including(
              index_step: an_instance_of(String),
              record: an_instance_of(String)
            )
          )
      end
    end
  end
end
