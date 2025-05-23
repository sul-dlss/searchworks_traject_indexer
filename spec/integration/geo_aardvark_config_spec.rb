# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'EarthWorks Aardvark indexing' do
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/geo_aardvark_config.rb')
    end
  end
  let(:druid) { 'vv853br8653' }
  let(:record) { PurlRecord.new(druid) }
  let(:xml_body) do
    File.new(file_fixture("#{druid}.xml"))
  rescue StandardError
    nil
  end
  let(:body) { File.new(file_fixture("#{druid}.json")) }
  let(:metadata_json) { File.new(file_fixture("#{druid}.meta_json")) }

  before do
    stub_request(:get, "https://purl.stanford.edu/#{druid}.xml").to_return(status: xml_body ? 200 : 404, body: xml_body)
    stub_request(:get, "https://purl.stanford.edu/#{druid}.json").to_return(status: 200, body:)
    stub_request(:get, "https://purl.stanford.edu/#{druid}.meta_json").to_return(status: 200, body: metadata_json)
  end

  it 'maps an id' do
    expect(result['id']).to eq ["stanford-#{druid}"]
  end

  it 'maps a hashed id for sitemap generation' do
    expect(result['hashed_id_ssi']).to eq Digest::MD5.hexdigest("stanford-#{druid}")
  end

  it 'maps the title' do
    expect(result['dct_title_s']).to eq 'Abundance Estimates of the Pacific Salmon Conservation Assessment Database, 1978-2008'
  end

  it 'maps the description including all relevant description note fields' do
    expect(result['dct_description_sm'].first).to start_with 'This dataset is a visualization of abundance estimates for six species of Pacific salmon'
    expect(result['dct_description_sm'].last).to start_with 'This layer is presented in the WGS84 coordinate system for web display purposes'
    expect(result['dct_description_sm'].size).to eq 3
  end

  it 'maps the languages' do
    expect(result['dct_language_sm']).to eq ['eng']
  end

  it 'maps the creators' do
    expect(result['dct_creator_sm']).to eq [
      'Pinsky, Malin L.',
      'Springmeyer, Dane B.',
      'Goslin, Matthew N.',
      'Augerot, Xanthippe'
    ]
  end

  it 'maps the publishers' do
    expect(result['dct_publisher_sm']).to eq ['Stanford Digital Repository']
  end

  it 'maps the date issued' do
    expect(result['dct_issued_s']).to eq '2009'
  end

  it 'maps the subjects' do
    expect(result['dct_subject_sm']).to eq [
      'Marine habitat conservation',
      'Freshwater habitat conservation',
      'Pacific salmon',
      'Conservation',
      'Watersheds',
      'Environment',
      'Oceans',
      'Inland Waters'
    ]
  end

  it 'maps the spatial coverages' do
    expect(result['dct_spatial_sm']).to eq ['North Pacific Ocean']
  end

  it 'maps the themes' do
    expect(result['dcat_theme_sm']).to eq ['Environment', 'Oceans', 'Inland Waters']
  end

  it 'maps the temporal coverage' do
    expect(result['dct_temporal_sm']).to eq ['1978–2005']
  end

  it 'maps the date range' do
    expect(result['gbl_dateRange_drsim']).to eq ['[1978 TO 2005]']
  end

  it 'maps the index years' do
    expect(result['gbl_indexYear_im']).to eq (1978..2005).to_a
  end

  it 'hierarchicalizes the index years and maps that to a separate field' do
    expect(result['date_hierarchy_sm'].length).to eq 34 # 28 years, 4 decades, 2 centuries
    expect(result['date_hierarchy_sm']).to include('1900-1999', '2000-2099',
                                                   '1900-1999:1970-1979', '1900-1999:1980-1989', '1900-1999:1990-1999',
                                                   '2000-2099:2000-2009',
                                                   '1900-1999:1980-1989:1980', '2000-2099:2000-2009:2004')
  end

  it 'maps the provider as stanford' do
    expect(result['schema_provider_s']).to eq 'Stanford'
  end

  it 'uses the purl url as an identifier' do
    expect(result['dct_identifier_sm']).to eq ["https://purl.stanford.edu/#{druid}"]
  end

  it 'maps the resource class' do
    expect(result['gbl_resourceClass_sm']).to eq ['Datasets']
  end

  it 'maps the resource types' do
    expect(result['gbl_resourceType_sm']).to eq ['Polygon data']
  end

  it 'maps the file format' do
    expect(result['dct_format_s']).to eq 'Shapefile'
  end

  it 'maps the geometry' do
    expect(result['locn_geometry']).to eq 'ENVELOPE(-180.0, 180.0, 73.990866, 24.23126)'
  end

  it 'maps the bounding box' do
    expect(result['dcat_bbox']).to eq 'ENVELOPE(-180.0, 180.0, 73.990866, 24.23126)'
  end

  it 'maps the rights' do
    expect(result['dct_rights_sm']).to eq [
      'User agrees that, where applicable, content will not be used to identify ' \
      'or to otherwise infringe the privacy or confidentiality rights of individuals. ' \
      'Content distributed via the Stanford Digital Repository may be subject to ' \
      'additional license and use restrictions applied by the depositor.'
    ]
  end

  it 'maps the license' do
    expect(result['dct_license_sm']).to eq ['https://creativecommons.org/licenses/by-nc/3.0/legalcode']
  end

  it 'maps the access rights' do
    expect(result['dct_accessRights_s']).to eq 'Public'
  end

  # No events in cocina descriptive adminMetadata, so we use the top-level one
  it 'maps the top-level modification date as the metadata modification date' do
    expect(result['gbl_mdModified_dt']).to eq '2022-09-28T21:48:32Z'
  end

  it 'maps the metadata version as Aardvark' do
    expect(result['gbl_mdVersion_s']).to eq 'Aardvark'
  end

  it 'maps the WFS/WMS/WCS identifier' do
    expect(result['gbl_wxsIdentifier_s']).to eq 'druid:vv853br8653'
  end

  describe 'URL references' do
    let(:references) { JSON.parse result['dct_references_s'] }

    it 'maps the purl URL' do
      expect(references['http://schema.org/url']).to eq "https://purl.stanford.edu/#{druid}"
    end

    it 'maps the embed URL' do
      expect(references['https://oembed.com']).to eq "https://purl.stanford.edu/embed.json?hide_title=true&url=https%3A%2F%2Fpurl.stanford.edu%2F#{druid}"
    end

    it 'maps the WMS URL' do
      expect(references['http://www.opengis.net/def/serviceType/ogc/wms']).to eq 'https://geowebservices.stanford.edu/geoserver/wms'
    end

    it 'maps the WFS URL' do
      expect(references['http://www.opengis.net/def/serviceType/ogc/wfs']).to eq 'https://geowebservices.stanford.edu/geoserver/wfs'
    end

    it 'maps the searchworks URL when released to searchworks' do
      expect(references['https://schema.org/relatedLink']).to eq 'https://searchworks.stanford.edu/view/vv853br8653'
    end

    it 'maps the downloadUrl as an array of objects with url and label' do
      expect(references['http://schema.org/downloadUrl']).to eq [{ 'label' => 'Zipped object', 'url' => 'https://stacks.stanford.edu/object/vv853br8653' }]
    end
  end

  context 'with contributor names that are structuredValues' do
    let(:druid) { 'rk962wd2562' }
    it 'maps the creators' do
      expect(result['dct_creator_sm']).to eq ['Ptolemy, active 2nd century', 'Waldseemüller, Martin, 1470-1519', 'Schott, Johann, 1477-1548', 'Übelin, Georg, active 15th century-16th century']
    end
  end

  context 'with a shapefile with unzipped metadata (not released to searchworks)' do
    let(:druid) { 'bc559yb0972' }

    # There is an event in cocina descriptive adminMetadata, so we use that (even though it's creation)
    it 'maps the creation date as the metadata modification date' do
      expect(result['gbl_mdModified_dt']).to eq '2015-11-03T00:00:00Z'
    end

    it 'maps the copyright info' do
      expect(result['dct_rightsHolder_sm']).to eq ['This work is in the Public Domain, meaning that it is not subject to copyright.']
    end

    describe 'URL references' do
      let(:references) { JSON.parse result['dct_references_s'] }

      it 'maps the ISO19139 URL' do
        expect(references['http://www.isotc211.org/schemas/2005/gmd']).to eq "https://stacks.stanford.edu/file/druid:#{druid}/MineralResources-iso19139.xml"
      end

      it 'maps the ISO19110 URL' do
        expect(references['http://www.isotc211.org/schemas/2005/gco']).to eq "https://stacks.stanford.edu/file/druid:#{druid}/MineralResources-iso19110.xml"
      end

      it 'maps the FGDC URL' do
        expect(references['http://www.opengis.net/cat/csw/csdgm']).to eq "https://stacks.stanford.edu/file/druid:#{druid}/MineralResources-fgdc.xml"
      end

      it 'does not include a searchworks URL' do
        expect(references['https://schema.org/relatedLink']).to be_nil
      end
    end
  end

  context 'with a DOI and a Purl' do
    let(:druid) { 'fk339wc1276' }
    it 'finds the DOI and appends it to dct_identifier_sm with the purl' do
      expect(result['dct_identifier_sm']).to eq ["https://purl.stanford.edu/#{druid}", "https://doi.org/10.25740/#{druid}"]
    end
  end

  context 'with a scanned map' do
    let(:druid) { 'dc482zx1528' }

    it 'maps the description including all relevant note fields' do
      expect(result['dct_description_sm']).to eq [
        'Publication date estimate from dealer description.',
        'Shows views of tourist attractions.',
        'Includes distance chart in inset.',
        'Hand-painted.'
      ]
    end

    it 'maps the main title' do
      expect(result['dct_title_s']).to eq 'Jōshū Kusatsu Onsenzu'
    end

    it 'maps the alternative titles' do
      expect(result['dct_alternative_sm']).to eq ['Jōshū Kusatsu Onsen zu']
    end

    it 'maps the resource class' do
      expect(result['gbl_resourceClass_sm']).to eq ['Maps']
    end

    it 'maps the file format' do
      expect(result['dct_format_s']).to eq 'JPEG'
    end

    it 'maps the collection membership as memberOf' do
      expect(result['pcdm_memberOf_sm']).to eq ['stanford-bf420qj4978']
    end

    it 'does not include the WFS/WMS/WCS identifier' do
      expect(result['gbl_wxsIdentifier_s']).to be_nil
    end

    describe 'URL references' do
      let(:references) { JSON.parse result['dct_references_s'] }

      it 'maps the IIIF manifest URL' do
        expect(references['http://iiif.io/api/presentation#manifest']).to eq 'https://purl.stanford.edu/dc482zx1528/iiif3/manifest'
      end
    end
  end

  context 'with a scanned map that was georeferenced' do
    let(:druid) { 'kd514jp1398' }

    it 'maps the resource class' do
      expect(result['gbl_resourceClass_sm']).to eq %w[Datasets Maps]
    end

    it 'maps the resource types' do
      expect(result['gbl_resourceType_sm']).to eq ['Raster data']
    end

    it 'maps the georeferenced status' do
      expect(result['gbl_georeferenced_b']).to eq true
    end

    it 'maps the source map' do
      expect(result['dct_source_sm']).to eq ['stanford-df334jk2963']
    end

    it 'does not populate dct_relation_sm' do
      expect(result['dct_relation_sm']).to be_nil
    end

    context 'when the source map does not have a purl' do
      let(:druid) { 'yx324nv8969' }

      it 'does not populate dct_source_sm' do
        expect(result['dct_source_sm']).to be_nil
      end
    end
  end

  context 'with a scanned map that has a georeferenced version' do
    let(:druid) { 'gm036df2527' }

    it 'maps the georeferenced status' do
      expect(result['gbl_georeferenced_b']).to eq false
    end

    it 'populates the link to the georeferenced map in dct_relation_sm' do
      expect(result['dct_relation_sm']).to eq ['https://earthworks.stanford.edu/catalog/stanford-px984sn6906']
    end
  end

  context 'with metadata that has "Digital Map" as its form>genre metadata' do
    let(:druid) { 'df451fk6628' }

    it 'maps the resource class to Maps' do
      expect(result['gbl_resourceClass_sm']).to eq ['Maps']
    end
  end

  context 'with a stanford-only raster image' do
    let(:druid) { 'bb021mm7809' }

    it 'maps the resource class' do
      expect(result['gbl_resourceClass_sm']).to eq ['Datasets']
    end

    it 'maps the resource type' do
      expect(result['gbl_resourceType_sm']).to eq ['Raster data']
    end

    it 'maps the temporal coverage' do
      expect(result['dct_temporal_sm']).to eq ['2014']
    end

    it 'maps the index year' do
      expect(result['gbl_indexYear_im']).to eq [2014]
    end

    it 'hierarchicalizes the index years and maps that to a separate field' do
      expect(result['date_hierarchy_sm'].sort).to eq(%w[2000-2099
                                                        2000-2099:2010-2019
                                                        2000-2099:2010-2019:2014].sort)
    end

    it 'maps the date range' do
      expect(result['gbl_dateRange_drsim']).to eq ['[2014 TO 2014]']
    end

    it 'maps the access rights' do
      expect(result['dct_accessRights_s']).to eq 'Restricted'
    end

    it 'maps the file format' do
      expect(result['dct_format_s']).to eq 'GeoTIFF'
    end

    it 'maps the collection membership as memberOf' do
      expect(result['pcdm_memberOf_sm']).to eq ['stanford-vh286rq6087']
    end

    describe 'URL references' do
      let(:references) { JSON.parse result['dct_references_s'] }

      it 'maps the WMS URL' do
        expect(references['http://www.opengis.net/def/serviceType/ogc/wms']).to eq 'https://geowebservices-restricted.stanford.edu/geoserver/wms'
      end

      it 'maps the WCS URL' do
        expect(references['http://www.opengis.net/def/serviceType/ogc/wcs']).to eq 'https://geowebservices-restricted.stanford.edu/geoserver/wcs'
      end
    end
  end

  context 'with an index map' do
    let(:druid) { 'nq544bf8960' }

    it 'maps the resource class' do
      expect(result['gbl_resourceClass_sm']).to eq ['Datasets']
    end

    it 'maps the resource types' do
      expect(result['gbl_resourceType_sm']).to eq ['Military maps', 'Topographic maps', 'Index maps']
    end

    it 'maps the temporal coverage' do
      expect(result['dct_temporal_sm']).to eq ['1938-1940']
    end

    it 'maps the index year' do
      expect(result['gbl_indexYear_im']).to eq (1938..1940).to_a
    end

    it 'hierarchicalizes the index years and maps that to a separate field' do
      expect(result['date_hierarchy_sm'].sort).to eq(%w[1900-1999
                                                        1900-1999:1930-1939 1900-1999:1940-1949
                                                        1900-1999:1930-1939:1938 1900-1999:1930-1939:1939
                                                        1900-1999:1940-1949:1940].sort)
    end

    it 'maps the date range' do
      expect(result['gbl_dateRange_drsim']).to eq ['[1938 TO 1940]']
    end

    it 'maps the theme' do
      expect(result['dcat_theme_sm']).to eq ['Military']
    end

    it 'maps the file format' do
      expect(result['dct_format_s']).to eq 'Shapefile'
    end

    it 'maps the collection membership as memberOf' do
      expect(result['pcdm_memberOf_sm']).to eq ['stanford-ch237ht4777']
    end

    describe 'URL references' do
      let(:references) { JSON.parse result['dct_references_s'] }

      it 'maps the OpenIndexMaps URL' do
        expect(references['https://openindexmaps.org']).to eq "https://stacks.stanford.edu/file/druid:#{druid}/index_map.json"
      end
    end
  end

  context 'with a stanford-only geodatabase file' do
    let(:druid) { 'pq479rm6462' }

    it 'maps the access rights' do
      expect(result['dct_accessRights_s']).to eq 'Restricted'
    end

    it 'maps the resource class' do
      expect(result['gbl_resourceClass_sm']).to eq ['Datasets']
    end

    it 'maps the file format' do
      expect(result['dct_format_s']).to eq 'Geodatabase'
    end

    describe 'URL references' do
      let(:references) { JSON.parse result['dct_references_s'] }

      it 'maps the purl URL' do
        expect(references['http://schema.org/url']).to eq "https://purl.stanford.edu/#{druid}"
      end

      it 'maps the embed URL' do
        expect(references['https://oembed.com']).to eq "https://purl.stanford.edu/embed.json?hide_title=true&url=https%3A%2F%2Fpurl.stanford.edu%2F#{druid}"
      end
    end
  end

  context 'with line data' do
    let(:druid) { 'mc977kq8162' }

    it 'maps the resource class' do
      expect(result['gbl_resourceClass_sm']).to eq ['Datasets']
    end

    it 'maps the temporal coverage' do
      expect(result['dct_temporal_sm']).to eq ['2002']
    end

    it 'maps the index year' do
      expect(result['gbl_indexYear_im']).to eq [2002]
    end

    it 'hierarchicalizes the index years and maps that to a separate field' do
      expect(result['date_hierarchy_sm'].sort).to eq(%w[2000-2099
                                                        2000-2099:2000-2009
                                                        2000-2099:2000-2009:2002].sort)
    end

    it 'maps the date range' do
      expect(result['gbl_dateRange_drsim']).to eq ['[2002 TO 2002]']
    end

    it 'maps the resource types' do
      expect(result['gbl_resourceType_sm']).to eq ['Line data']
    end

    it 'maps the theme' do
      expect(result['dcat_theme_sm']).to eq ['Transportation']
    end

    it 'maps the file format' do
      expect(result['dct_format_s']).to eq 'Shapefile'
    end

    it 'maps the collection membership as memberOf' do
      expect(result['pcdm_memberOf_sm']).to eq ['stanford-bq589tv8583']
    end

    describe 'URL references' do
      let(:references) { JSON.parse result['dct_references_s'] }

      it 'maps the WMS URL' do
        expect(references['http://www.opengis.net/def/serviceType/ogc/wms']).to eq 'https://geowebservices.stanford.edu/geoserver/wms'
      end

      it 'maps the WFS URL' do
        expect(references['http://www.opengis.net/def/serviceType/ogc/wfs']).to eq 'https://geowebservices.stanford.edu/geoserver/wfs'
      end
    end
  end

  context 'with geoJSON data and unzipped metadata' do
    let(:druid) { 'fk339wc1276' }

    it 'maps the resource class' do
      expect(result['gbl_resourceClass_sm']).to eq ['Datasets']
    end

    describe 'URL references' do
      let(:references) { JSON.parse result['dct_references_s'] }

      it 'maps the ISO19139 URL' do
        expect(references['http://www.isotc211.org/schemas/2005/gmd']).to eq "https://stacks.stanford.edu/file/druid:#{druid}/Stanford_Temperature_Model_4km-iso19139.xml"
      end

      it 'maps the ISO19110 URL' do
        expect(references['http://www.isotc211.org/schemas/2005/gco']).to eq "https://stacks.stanford.edu/file/druid:#{druid}/Stanford_Temperature_Model_4km-iso19110.xml"
      end

      it 'maps the FGDC URL' do
        expect(references['http://www.opengis.net/cat/csw/csdgm']).to eq "https://stacks.stanford.edu/file/druid:#{druid}/Stanford_Temperature_Model_4km-fgdc.xml"
      end

      it 'maps the GeoJSON URL' do
        expect(references['http://geojson.org/geojson-spec.html']).to eq "https://stacks.stanford.edu/file/druid:#{druid}/Stanford_Temperature_Model_4km.geojson"
      end
    end
  end

  context 'with a collection' do
    let(:druid) { 'bq589tv8583' }

    it 'maps the resource class' do
      expect(result['gbl_resourceClass_sm']).to eq ['Collections']
    end

    it 'maps the subjects' do
      expect(result['dct_subject_sm']).to eq %w[Transportation Boundaries Census]
    end

    it 'maps the spatial coverages' do
      expect(result['dct_spatial_sm']).to eq ['San Francisco Bay Area']
    end

    describe 'references' do
      let(:references) { JSON.parse result['dct_references_s'] }

      it 'maps the searchworks URL when released to searchworks and has catkey' do
        expect(references['https://schema.org/relatedLink']).to eq 'https://searchworks.stanford.edu/view/11235662'
      end
    end

    # This record has two differently-formatted events in cocina descriptive
    # adminMetadata; we want to parse both and use the more recent (modified)
    it 'maps the modification date as the metadata modification date' do
      expect(result['gbl_mdModified_dt']).to eq '2002-06-18T15:56:43Z'
    end

    it 'maps the themes' do
      expect(result['dcat_theme_sm']).to eq %w[Transportation Boundaries]
    end

    it 'has no file format' do
      expect(result['dct_format_s']).to be_nil
    end

    describe 'URL references' do
      let(:references) { JSON.parse result['dct_references_s'] }

      it 'has no download URL' do
        expect(references['http://schema.org/downloadUrl']).to be_nil
      end

      it 'has no embed URL' do
        expect(references['https://oembed.com']).to be_nil
      end
    end
  end

  context 'with a record with no geometry' do
    before do
      allow(indexer).to receive(:logger).and_return(Logger.new(File::NULL)) # suppress logger output
      allow(Settings.sdr_events).to receive(:enabled).and_return(true)
      allow(SdrEvents).to receive_messages(
        report_indexing_skipped: true
      )
    end
    let(:druid) { 'cd502cx8669' }

    it 'does not index the record' do
      expect(result).to be_nil
      expect(SdrEvents).to have_received(:report_indexing_skipped).with(druid, { message: 'No geometry available for item', target: 'Earthworks' })
    end
  end
end
