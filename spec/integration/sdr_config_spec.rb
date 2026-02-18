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

  describe 'storing compacted cocina' do
    let(:compact_struct) { JSON.parse(result['cocina_struct'].first) }

    it 'removes blank values' do
      # 'note' is an empty array in fixture
      expect(compact_struct.dig('description', 'title', 0, 'structuredValue', 0)).not_to have_key('note')
    end

    it 'maps the keys needed for display' do
      expect(compact_struct.keys).to include('description', 'identification', 'access')
    end
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

    it 'maps the main contributor name with date for search' do
      expect(result['author_1xx_search']).to eq ['Rifat Paşa, Mehmet Sadık, 1807-1856']
    end

    it 'maps the additional contributor names with date for search' do
      expect(result['author_7xx_search']).to eq [
        'Gabbay, Yehezkel, 1825-1898',
        'Jerusalmi, Isaac, 1928-2018',
        'Taube Center for Jewish Studies (Stanford University), Sephardic Studies Project'
      ]
    end

    it 'maps the personal contributor names with dates for faceting and display' do
      %w[author_person_facet author_person_display author_person_full_display].each do |field|
        expect(result[field]).to eq [
          'Rifat Paşa, Mehmet Sadık, 1807-1856',
          'Gabbay, Yehezkel, 1825-1898',
          'Jerusalmi, Isaac, 1928-2018'
        ]
      end
    end

    it 'maps the impersonal contributor names for faceting' do
      expect(result['author_other_facet']).to eq ['Taube Center for Jewish Studies (Stanford University), Sephardic Studies Project', '[Isaac Jerushalmi]']
    end

    it 'maps the sort contributor name with title' do
      expect(result['author_sort']).to eq ['Rifat Paşa Mehmet Sadık Mehmet Sadik Rifat Pashas Risalei ahlak']
    end

    it 'maps the organization contributor names for display' do
      expect(result['author_corp_display']).to eq ['Taube Center for Jewish Studies (Stanford University), Sephardic Studies Project', '[Isaac Jerushalmi]']
    end

    it 'maps the structured version of the author names for linking' do
      expect(result['author_struct']).to contain_exactly(
        {
          'link' => 'Rifat Paşa, Mehmet Sadık, 1807-1856',
          'search' => '"Rifat Paşa, Mehmet Sadık"',
          'post_text' => '(author)'
        }.to_json,
        {
          'link' => 'Gabbay, Yehezkel, 1825-1898',
          'search' => '"Gabbay, Yehezkel"',
          'post_text' => '(translator)'
        }.to_json,
        {
          'link' => 'Jerusalmi, Isaac, 1928-2018',
          'search' => '"Jerusalmi, Isaac"',
          'post_text' => '(editor)'
        }.to_json,
        {
          'link' => 'Taube Center for Jewish Studies (Stanford University), Sephardic Studies Project',
          'search' => '"Taube Center for Jewish Studies (Stanford University), Sephardic Studies Project"'
        }.to_json,
        {
          'link' => '[Isaac Jerushalmi]',
          'search' => '"[Isaac Jerushalmi]"',
          'post_text' => '(publisher)'
        }.to_json
      )
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

  describe 'publication fields' do
    let(:druid) { 'bm971cx9348' }
    let(:collection_druid) { 'yh583fk3400' }

    it 'maps the publication year as a string for display/sort' do
      expect(result['pub_date']).to eq ['1920 -']
      expect(result['pub_year_ss']).to eq ['1920 -']
      expect(result['pub_date_sort']).to eq ['1920 -']
    end

    it 'maps the places of publication for search' do
      expect(result['pub_search']).to eq %w[England London]
    end

    it 'maps the publication year as an integer' do
      expect(result['publication_year_isi']).to eq [1920]
    end

    it 'maps the full imprint statement for display' do
      expect(result['imprint_display']).to eq ['2nd ed. - London : H.M. Stationery Off., [192-?]-[193-?]']
    end

    it 'maps the publication country' do
      expect(result['pub_country']).to eq ['England']
    end
  end

  describe 'form fields' do
    let(:druid) { 'sw705fr7011' }
    let(:collection_druid) { 'vm093fg5170' }

    it 'maps the format to searchworks vocab for faceting' do
      expect(result['format_hsim']).to eq ['Sound recording']
    end

    it 'maps the genres' do
      expect(result['genre_ssim']).to eq ['Oral histories']
    end

    it 'maps the language names' do
      expect(result['language']).to eq ['English']
    end

    it 'maps the extent descriptions' do
      expect(result['physical']).to eq ['1 audiotape', '1 transcript']
    end
  end

  describe 'note fields' do
    context 'with an abstract' do
      let(:druid) { 'bc559yb0972' }
      let(:collection_druid) { 'kn733hp1726' }

      it 'maps the abstract' do
        # rubocop:disable Layout/LineLength
        expect(result['summary_search']).to eq ['This polygon shapefile contains mineral resource areas as defined in the General Plan adopted May 24, 1994 for the County of Santa Cruz, California. These Areas were classified by the State Geologist and designated by the State Mining and Geology Board as regionally or statewide significant Mineral Resource Areas and Areas classified by the State as MRZ-2 Zones (areas containing significant mineral deposits), excluding those areas with existing land uses and/or land use designations which conflict with mineral resource extraction. Mineral Resource Areas are classified via Special Report 146 Part IV, Mineral Land Classification: Aggregate Materials in the San Francisco and Monterey Bay Area; and designated by the State Mining and Geology Board via the California Surface Mining and Reclamation Act (SMARA) Designation Report No. 7, Designation of Regionally Significant Construction Aggregate Resource Areas in the South San Francisco Bay, North San Francisco Bay, Monterey Bay Production - Consumption Regions. This layer is part of a collection of GIS data created for Santa Cruz County, California.']
        # rubocop:enable Layout/LineLength
      end
    end

    context 'with a table of contents' do
      let(:druid) { 'bm971cx9348' }
      let(:collection_druid) { 'yh583fk3400' }

      it 'maps the table of contents' do
        expect(result['toc_search']).to eq ['-- pt.2. Abergavenny -- pt.5. Merthyr Tydfil']
      end
    end
  end

  describe 'access fields' do
    let(:druid) { 'kf879tn8532' }

    it 'maps the access facet to Online' do
      expect(result['access_facet']).to eq ['Online']
    end

    it 'maps the library code facet to SDR' do
      expect(result['library_code_facet_ssim']).to eq ['SDR']
    end

    it 'maps the building facet to Stanford Digital Repository' do
      expect(result['building_facet']).to eq ['Stanford Digital Repository']
    end

    it 'maps the purl url as the full text url' do
      expect(result['url_fulltext']).to eq ['https://purl.stanford.edu/kf879tn8532']
    end

    it 'maps the iiif manifest url' do
      expect(result['iiif_manifest_url_ssim']).to eq ['https://purl.stanford.edu/kf879tn8532/iiif3/manifest']
    end

    it 'maps the URLs of related resources' do
      expect(result['url_suppl']).to eq [
        'https://purl.stanford.edu/xs812fm6103',
        'https://purl.stanford.edu/wn542dy8318'
      ]
    end
  end

  describe 'identifier fields' do
    let(:druid) { 'bt553vr2845' }
    let(:collection_druid) { 'yh583fk3400' }

    it 'maps the ISBNs for search and display' do
      expect(result['isbn_search']).to eq %w[0452008999 9780452008991]
      expect(result['isbn_display']).to eq %w[0452008999 9780452008991]
    end

    it 'maps the LCCN' do
      expect(result['lccn']).to eq ['84062811']
    end

    context 'with an OCLC ID' do
      let(:druid) { 'bx658jh7339' }
      let(:collection_druid) { 'jh957jy1101' }

      it 'maps the OCLC ID' do
        expect(result['oclc']).to eq ['693231462']
      end
    end

    context 'with an ISSN' do
      let(:druid) { 'sh330kw8676' }
      let(:collection_druid) { 'cj445qq4021' }

      it 'maps the ISSN for search and display' do
        expect(result['issn_search']).to eq ['0164-5846']
        expect(result['issn_display']).to eq ['0164-5846']
      end
    end
  end

  describe 'structural metadata fields' do
    let(:druid) { 'bk264hq9320' }
    let(:collection_druid) { 'nj770kg7809' }

    it 'maps the content type' do
      expect(result['dor_content_type_ssi']).to eq ['media']
    end

    it 'maps the file MIME types' do
      expect(result['dor_file_mimetype_ssim']).to eq ['video/mp4', 'image/jp2']
    end

    it 'maps the fileset types' do
      expect(result['dor_resource_content_type_ssim']).to eq %w[video image]
    end

    it 'maps the fileset count' do
      expect(result['dor_resource_count_isi']).to eq [3]
    end

    it 'maps the thumbnail IIIF ID' do
      expect(result['file_id']).to eq ['bk264hq9320%2Fbk264hq9320_img_1']
    end

    context 'with a virtual object' do
      let(:druid) { 'ws947mh3822' }
      let(:collection_druid) { 'gh795jd5965' }
      let(:member_druid) { 'ts786ny5936' }

      # NOTE: this item has hundreds of members; we want to ensure that we only
      # fetch as many members as needed to find a thumbnail, not all of them.
      # If more than the first (ts786ny5936) are fetched, this test will fail,
      # because we only stub the first member's metadata request.
      before do
        stub_request(:get, "https://purl.stanford.edu/#{member_druid}.json").to_return(status: 200, body: File.new(file_fixture("#{member_druid}.json")))
      end

      it 'uses the members to derive a thumbnail' do
        expect(result['file_id']).to eq ['ts786ny5936%2FPC0170_s1_E_0204']
      end
    end
  end

  describe 'collection fields' do
    context 'with an object that is in a collection' do
      let(:druid) { 'bc559yb0972' }
      let(:collection_druid) { 'kn733hp1726' }

      it 'maps the searchworks ID for the collection' do
        expect(result['collection']).to eq ['a11415965']
      end

      it 'maps the collection info for display' do
        expect(result['collection_with_title']).to eq ["a11415965-|-Santa Cruz County, California GIS Maps \u0026 Data"]
      end
    end

    context 'with a member of a virtual object' do
      let(:druid) { 'fn851zf9475' }
      let(:collection_druid) { 'fh138mm2023' }
      let(:parent_druid) { 'dg050kz7339' }

      before do
        stub_request(:get, "https://purl.stanford.edu/#{parent_druid}.json").to_return(status: 200, body: File.new(file_fixture("#{parent_druid}.json")))
      end

      it 'maps the searchworks ID for the parent object' do
        expect(result['set']).to eq ['dg050kz7339'] # no catkey for this object
      end

      it 'maps the parent object info for display' do
        expect(result['set_with_title']).to eq ['dg050kz7339-|-[Thomas Bros. maps of Palo Alto, San Jose, Santa Clara and vicinities]']
      end
    end

    context 'with a collection' do
      let(:druid) { 'gh795jd5965' }

      it 'maps the collection type' do
        expect(result['collection_type']).to eq ['Digital Collection']
      end
    end
  end

  describe 'schema.org metadata' do
    subject(:schema_org) { result.dig('schema_dot_org_struct', 0) }

    context 'with a non-geo object' do
      let(:druid) { 'bt553vr2845' }
      let(:collection_druid) { 'yh583fk3400' }

      it { is_expected.to be_nil }
    end

    context 'with a geo object' do
      let(:druid) { 'vv853br8653' }
      let(:collection_druid) { 'zc193vn8689' }
      let(:parsed_content) { JSON.parse(schema_org) }

      it 'maps the metadata to schema.org vocabulary for a dataset' do
        expect(parsed_content).to include(
          {
            '@context' => 'http://schema.org',
            '@type' => 'Dataset',
            # rubocop:disable Layout/LineLength
            'citation' => 'Pinsky, M.L., Springmeyer, D.B., Goslin, M.N., Augerot, X (2009). Abundance Estimates of the Pacific Salmon Conservation Assessment Database, 1978-2008. Stanford Digital Repository. Available at: http://purl.stanford.edu/vv853br8653',
            'description' => [
              'This dataset is a visualization of abundance estimates for six species of Pacific salmon (Oncorhynchus spp.): Chinook, Chum, Pink, Steelhead, Sockeye, and Coho in catchment areas of the Northern Pacific Ocean, including Canada, China, Japan, Russia, and the United States. Catchment polygons included in this layer range in dates from 1978 to 2008. Sources dating from 1950 to 2005, including published literature and agency reports were consulted in order to create these data. In addition to abundance estimates, the PCSA database includes information on distribution, diversity, run-timings, land cover/land-use, dams, hatcheries, data sources, drainages, and administrative categories and provides a consistent format for comparing watersheds across the range of wild Pacific salmon.', 'The Conservation Science team at the Wild Salmon Center has created a geographic database, the Pacific Salmon Conservation Assessment (PSCA) that covers the whole range of wild Pacific Salmon. By providing estimations of salmon abundance and diversity, these data can provide opportunities to conduct range-wide analysis for conservation planning, prioritizing, and assessments.  The primary goal in developing the PSCA database is to guide proactive international salmon conservation.'
            ],
            # rubocop:enable Layout/LineLength
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
            'keywords' => ['Marine habitat conservation', 'Freshwater habitat conservation', 'Pacific salmon', 'Conservation', 'Watersheds', 'Environment', 'Oceans', 'Inland Waters', '1978 - 2005', 'North Pacific Ocean'],
            'license' => 'https://creativecommons.org/licenses/by-nc/3.0/legalcode',
            'name' => ['Abundance Estimates of the Pacific Salmon Conservation Assessment Database, 1978-2008'],
            'sameAs' => 'https://searchworks.stanford.edu/view/vv853br8653'
          }
        )
      end

      context 'when the object is not released to earthworks' do
        before { allow(record).to receive(:released_to_earthworks?).and_return(false) }

        it 'does not include the includedInDataCatalog property' do
          expect(parsed_content).not_to include('includedInDataCatalog')
        end
      end
    end
  end

  describe 'student work facet values' do
    # n.b. these are real druids, but we overwrite the Cocina data in order to not need
    # a different fixture for every case. these come from an urban studies thesis.
    let(:druid) { 'fn236kc3118' }
    let(:collection_druid) { 'mc415rv2595' }

    # actual data used in each test
    let(:metadata_json) { {}.to_json }
    let(:collection_body) { { 'label' => collection_label }.to_json }
    let(:body) do
      {
        'description' => {
          'form' => [
            {
              'structuredValue' => [
                { 'value' => 'Text', 'type' => 'type' },
                { 'value' => resource_type, 'type' => 'subtype' }
              ],
              'type' => 'resource type',
              'source' => {
                'value' => 'Stanford self-deposit resource types'
              }
            }
          ]
        },
        'structural' => {
          'isMemberOf' => ["druid:#{collection_druid}"]
        }
      }.to_json
    end

    subject(:facet_value) { result['stanford_work_facet_hsim'].first }

    context 'with a student report' do
      let(:resource_type) { 'Report' }
      let(:collection_label) { 'Stanford University Student Reports' }

      it { is_expected.to eq 'Other student work|Student report' }
    end

    context 'with an honors thesis' do
      let(:resource_type) { 'Thesis' }
      let(:collection_label) { 'Undergraduate Honors Theses, Department of Communication, Stanford University' }

      it { is_expected.to eq 'Thesis/Dissertation|Bachelor\'s|Undergraduate honors thesis' }
    end

    context 'with a capstone thesis' do
      let(:resource_type) { 'Thesis' }
      let(:collection_label) { 'Stanford University Urban Studies Capstone Projects and Theses' }

      it { is_expected.to eq 'Thesis/Dissertation|Bachelor\'s|Unspecified' }
    end

    context 'with a masters thesis' do
      let(:resource_type) { 'Thesis' }
      let(:collection_label) { 'Masters Theses in Russian, East European and Eurasian Studies' }

      it { is_expected.to eq 'Thesis/Dissertation|Master\'s|Unspecified' }
    end

    context 'with a doctoral thesis' do
      let(:resource_type) { 'Thesis' }
      let(:collection_label) { 'PhD Dissertations, Stanford Earth' }

      it { is_expected.to eq 'Thesis/Dissertation|Doctoral|Unspecified' }
    end

    context 'with some other thesis' do
      let(:resource_type) { 'Thesis' }
      let(:collection_label) { 'Stanford University Libraries Theses' }

      it { is_expected.to eq 'Thesis/Dissertation|Unspecified' }
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
        allow(record).to receive(:content_type).and_raise('Error message')
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
