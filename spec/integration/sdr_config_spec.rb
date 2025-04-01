# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SDR indexing' do
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sdr_config.rb')
    end
  end
  let(:record) { PurlRecord.new(druid, purl_url: 'https://purl.stanford.edu') }
  let(:meta_json_body) do
    { '$schemaVersion': 1, sitemap: false, searchworks: searchworks, earthworks: false }
  end
  let(:searchworks) { true }

  def stub_purl_request(druid, body)
    stub_request(:get, "https://purl.stanford.edu/#{druid}.xml").to_return(status: 200, body:)
  end

  def stub_meta_json_request(druid)
    stub_request(:get, "https://purl.stanford.edu/#{druid}.meta_json").to_return(status: 200, body: meta_json_body.to_json)
  end

  before do
    stub_request(:get, "https://purl.stanford.edu/#{druid}.json").to_return(status: 404)
  end

  context 'with a missing object' do
    let(:druid) { 'abc' }

    before do
      stub_request(:get, "https://purl.stanford.edu/#{druid}.xml").to_return(status: 404)
      stub_meta_json_request(druid)
    end

    it 'maps the data the same way as it does currently' do
      expect(result).to be_nil
    end
  end

  context 'with bk264hq9320' do
    let(:druid) { 'bk264hq9320' }
    let(:collection_druid) { 'nj770kg7809' }

    before do
      stub_purl_request(druid, File.read(file_fixture("#{druid}.xml").to_s))
      stub_purl_request(collection_druid, File.read(file_fixture("#{collection_druid}.xml").to_s))
      stub_meta_json_request(collection_druid)
    end

    it 'maps the data the same way as it does currently' do
      expect(result).to include(
        {
          'id' => ['bk264hq9320'],
          'hashed_id_ssi' => ['6f9a6cccb27e922d48ee5803d9433648'],
          'druid' => ['bk264hq9320'],
          'title_245a_search' => ['Trustees Demo reel'],
          'title_245_search' => ['Trustees Demo reel.'],
          'title_sort' => ['Trustees Demo reel'],
          'title_245a_display' => ['Trustees Demo reel'],
          'title_display' => ['Trustees Demo reel'],
          'title_full_display' => ['Trustees Demo reel.'],
          'author_7xx_search' => ['Stanford University. News and Publications Service'],
          'author_other_facet' => ['Stanford University. News and Publications Service'],
          'author_sort' => ["\u{10FFFF} Trustees Demo reel"],
          'author_corp_display' => ['Stanford University. News and Publications Service'],
          'pub_search' => ['cau', 'Stanford (Calif.)'],
          'pub_year_isi' => [2004],
          'pub_date_sort' => ['2004'],
          'imprint_display' => ['Stanford (Calif.), February  9, 2004'],
          'pub_date' => ['2004'],
          'pub_year_ss' => ['2004'],
          'pub_year_tisim' => [2004],
          'creation_year_isi' => [2004],
          'format_main_ssim' => ['Video'],
          'language' => ['English'],
          'physical' => ['1 MiniDV tape'],
          'url_suppl' => [
            'http://www.oac.cdlib.org/findaid/ark:/13030/c8dn43sv',
            'https://purl.stanford.edu/nj770kg7809'
          ],
          'url_fulltext' => ['https://purl.stanford.edu/bk264hq9320'],
          'access_facet' => ['Online'],
          'building_facet' => ['Stanford Digital Repository'],
          'collection' => ['9665836'],
          'collection_with_title' => ['9665836-|-Stanford University, News and Publication Service, audiovisual recordings, 1936-2011 (inclusive)'],
          'all_search' => [' Trustees Demo reel Stanford University. News and Publications Service pro producer moving image cau Stanford (Calif.) 2004-02-09 eng English videocassette 1 MiniDV tape access reformatted digital video/mp4 image/jpeg NTSC Sound Color Reformatted by Stanford University Libraries in 2017. sc1125_s02_b11_04-0209-1 Stanford University. Libraries. Department of Special Collections and University Archives SC1125 https://purl.stanford.edu/bk264hq9320 Stanford University, News and Publication Service, Audiovisual Recordings (SC1125) http://www.oac.cdlib.org/findaid/ark:/13030/c8dn43sv English eng CSt human prepared Stanford University, News and Publication Service, audiovisual recordings, 1936-2011 (inclusive) https://purl.stanford.edu/nj770kg7809 The materials are open for research use and may be used freely for non-commercial purposes with an attribution. For commercial permission requests, please contact the Stanford University Archives (universityarchives@stanford.edu). '] # rubocop:disable Layout/LineLength
        }
      )

      expect(result).to include 'modsxml'

      expect(result).not_to include(
        'title_variant_search', 'author_meeting_display', 'author_person_display', 'author_person_full_display', 'author_1xx_search',
        'topic_search', 'geographic_search', 'subject_other_search', 'subject_other_subvy_search', 'subject_all_search',
        'topic_facet', 'geographic_facet', 'era_facet', 'publication_year_isi', 'genre_ssim', 'summary_search', 'toc_search', 'file_id',
        'set', 'set_with_title'
      )
    end

    context 'not released to searchworks' do
      let(:searchworks) { false }
      it { expect(result['collection_with_title']).to be nil }
    end
  end

  context 'with vv853br8653' do
    let(:druid) { 'vv853br8653' }
    let(:collection_druid) { 'zc193vn8689' }

    before do
      stub_purl_request(druid, File.read(file_fixture("#{druid}.xml").to_s))
      stub_purl_request(collection_druid, File.read(file_fixture("#{collection_druid}.xml").to_s))
      stub_meta_json_request(collection_druid)
    end

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
                         'Environment', 'Oceans', 'Inland Waters', 'North Pacific Ocean', '1978', '2005'],
          'license' => 'CC by-nc: CC BY-NC Attribution-NonCommercial',
          'name' => ['Abundance Estimates of the Pacific Salmon Conservation Assessment Database, 1978-2008'],
          'sameAs' => 'https://searchworks.stanford.edu/view/vv853br8653'
        }
      )
    end
  end

  describe 'stanford_work_facet_hsim' do
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

    before do
      stub_purl_request(druid, data)
      stub_purl_request(collection_druid, collection_data)
      stub_meta_json_request(collection_druid)
    end

    context 'with an honors thesis' do
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

    context 'with a capstone thesis' do
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

    context 'with a master\'s thesis' do
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

    context 'with a doctoral thesis' do
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

    context 'with some other thesis' do
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

    before do
      stub_purl_request(druid, data)
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

  describe 'content metadata' do
    let(:druid) { 'abc' }
    let(:data) do
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
      stub_purl_request(druid, data)
    end

    it 'maps the right data' do
      expect(result['dor_content_type_ssi']).to eq ['image']
      expect(result['dor_resource_content_type_ssim']).to eq %w[object preview]
      expect(result['dor_file_mimetype_ssim']).to eq ['application/zip', 'image/jpeg']
      expect(result['dor_resource_count_isi']).to eq [2]
    end
  end

  describe 'rights metadata' do
    let(:druid) { 'abc' }
    let(:data) do
      <<-XML
        <publicObject>
          <rightsMetadata>
            <access type="discover">
              <machine>
                <world/>
              </machine>
            </access>
            <access type="read">
              <machine>
                <world/>
              </machine>
            </access>
            <use>
              <human type="useAndReproduction">Property rights reside with the repository.</human>
            </use>
          </rightsMetadata>
          <mods xmlns="http://www.loc.gov/mods/v3"></mods>
        </publicObject>
      XML
    end

    before do
      stub_purl_request(druid, data)
    end

    it 'maps the right data' do
      expect(result['dor_read_rights_ssim']).to eq ['world']
    end
  end

  describe 'dates' do
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

    before do
      stub_purl_request(druid, data)
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

    describe 'copyright_year_isi with multiple potential years' do
      let(:mods_fragment) do
        <<-XML
        <originInfo>
          <copyrightDate encoding="w3cdtf" keyDate="yes">1980</copyrightDate>
        <publisher>Stoneware Inc.</publisher>
        </originInfo>
        <originInfo>
          <copyrightDate encoding="w3cdtf" qualifier="inferred" point="start">1982</copyrightDate>
          <copyrightDate encoding="w3cdtf" qualifier="inferred" point="end">1984</copyrightDate>
        </originInfo>
        XML
      end

      it 'maps the right data' do
        expect(result['copyright_year_isi']).to eq ['1980']
      end
    end
  end

  describe 'pub_country' do
    let(:druid) { 'abc' }
    let(:data) do
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

    before do
      stub_purl_request(druid, data)
    end

    it 'maps the right data' do
      expect(result['pub_country']).to eq ['Antigua and Barbuda']
    end
  end

  context 'with zz400gd3785' do
    let(:druid) { 'zz400gd3785' }
    let(:collection_druid) { 'sg213ph2100' }

    before do
      stub_purl_request(druid, File.read(file_fixture("#{druid}.xml").to_s))
      stub_purl_request(collection_druid, File.read(file_fixture("#{collection_druid}.xml").to_s))
      stub_meta_json_request(collection_druid)
    end

    it 'maps the data' do
      expect(result).to include(
        {
          'summary_search' => ['Topographical and street map of the western part of the city of San Francisco, with red indicating fire area.  Annotations:  “Area, approximately 4 square miles”;  entire title reads: “Reproduction from the Official Map of San Francisco, Showing the District Swept by Fire of April 18, 19, 20, 1906.”'], # rubocop:disable Layout/LineLength
          'iiif_manifest_url_ssim' => ['https://purl.stanford.edu/zz400gd3785/iiif/manifest']
        }
      )
    end
  end

  context 'with df650pk4327' do
    let(:druid) { 'df650pk4327' }
    let(:collection_druid) { 'hn730ks3626' }

    before do
      stub_purl_request(druid, File.read(file_fixture("#{druid}.xml").to_s))
      stub_purl_request(collection_druid, File.read(file_fixture("#{collection_druid}.xml").to_s))
      stub_meta_json_request(collection_druid)
    end

    it 'turns mods author data into a structure' do
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
    let(:druid) { 'bk264hq9320' }
    let(:collection_druid) { 'nj770kg7809' }

    before do
      stub_purl_request(druid, File.read(file_fixture("#{druid}.xml").to_s))
      stub_purl_request(collection_druid, File.read(file_fixture("#{collection_druid}.xml").to_s))
      stub_meta_json_request(collection_druid)
      allow(Settings.sdr_events).to receive(:enabled).and_return(true)
      allow(SdrEvents).to receive_messages(
        report_indexing_success: true,
        report_indexing_deleted: true,
        report_indexing_skipped: true,
        report_indexing_errored: true
      )
    end

    context 'when the item has no public XML' do
      before { allow(record).to receive(:public_xml).and_return(nil) }

      it 'creates an indexing skipped event with message' do
        expect(result).to be_nil
        expect(SdrEvents).to have_received(:report_indexing_skipped)
          .with(druid, message: 'Item is in processing or does not exist', target: 'Searchworks')
      end
    end

    context 'when the item has a catkey' do
      before { allow(record).to receive(:catkey).and_return('12345') }

      it 'creates an indexing skipped event with message' do
        expect(result).to be_nil
        expect(SdrEvents).to have_received(:report_indexing_skipped)
          .with(druid, message: 'Item has a catkey', target: 'Searchworks')
      end
    end

    context 'when indexing raised an error' do
      before do
        allow(Honeybadger).to receive(:notify)
        allow(indexer).to receive(:logger).and_return(Logger.new('/dev/null')) # suppress logger output
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
