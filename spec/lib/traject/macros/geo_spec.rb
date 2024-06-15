# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../lib/traject/macros/geo'

RSpec.describe Traject::Macros::Geo do
  include Traject::Macros::Geo

  let(:accumulator) { [] }
  let(:context) { Traject::Indexer::Context.new(source_record: record, output_hash:) }
  let(:output_hash) { {} }
  let(:druid) { 'fk339wc1276' }
  let(:body) { File.read(file_fixture("#{druid}.json")) }
  let(:record) { PurlRecord.new(druid) }
  let(:settings) do
    {
      'geoserver.pub_url' => 'https://geowebservices.stanford.edu/geoserver',
      'geoserver.stan_url' => 'https://geowebservices-restricted.stanford.edu/geoserver'
    }
  end

  before do
    stub_request(:get, "https://purl.stanford.edu/#{druid}.xml").to_return(status: 404)
    stub_request(:get, "https://purl.stanford.edu/#{druid}.json").to_return(status: 200, body:)
    macro.call(record, accumulator, context)
  end

  describe 'wms_url' do
    let(:macro) { wms_url }

    context 'with a public geo object' do
      let(:druid) { 'vv853br8653' }

      it 'returns the public geoserver WMS URL' do
        expect(accumulator).to eq ['https://geowebservices.stanford.edu/geoserver/wms']
      end
    end

    context 'with a stanford-only geo object' do
      let(:druid) { 'bb021mm7809' }

      it 'returns the stanford-only geoserver WMS URL' do
        expect(accumulator).to eq ['https://geowebservices-restricted.stanford.edu/geoserver/wms']
      end
    end

    context 'with a non-geo object' do
      let(:druid) { 'dc482zx1528' }

      it 'does nothing' do
        expect(accumulator).to be_empty
      end
    end
  end

  describe 'wfs_url' do
    let(:macro) { wfs_url }

    context 'with a public geojson file' do
      let(:output_hash) { { 'dct_format_s' => ['GeoJSON'] } }

      it 'returns the public geoserver WFS URL' do
        expect(accumulator).to eq ['https://geowebservices.stanford.edu/geoserver/wfs']
      end
    end

    context 'with a stanford-only shapefile' do
      let(:druid) { 'pq479rm6462' }
      let(:output_hash) { { 'dct_format_s' => ['Shapefile'] } }

      it 'returns the stanford-only geoserver WFS URL' do
        expect(accumulator).to eq ['https://geowebservices-restricted.stanford.edu/geoserver/wfs']
      end
    end

    context 'with a raster' do
      let(:output_hash) { { 'dct_format_s' => ['GeoTIFF'] } }

      it 'does nothing' do
        expect(accumulator).to be_empty
      end
    end
  end

  describe 'wcs_url' do
    let(:macro) { wcs_url }

    context 'with a public geotiff file' do
      let(:output_hash) { { 'dct_format_s' => ['GeoTIFF'] } }

      it 'returns the public geoserver WCS URL' do
        expect(accumulator).to eq ['https://geowebservices.stanford.edu/geoserver/wcs']
      end
    end

    context 'with a stanford-only arcgrid' do
      let(:druid) { 'pq479rm6462' }
      let(:output_hash) { { 'dct_format_s' => ['ArcGRID'] } }

      it 'returns the stanford-only geoserver WCS URL' do
        expect(accumulator).to eq ['https://geowebservices-restricted.stanford.edu/geoserver/wcs']
      end
    end

    context 'with a vector' do
      let(:output_hash) { { 'dct_format_s' => ['GeoJSON'] } }

      it 'does nothing' do
        expect(accumulator).to be_empty
      end
    end
  end

  describe 'format_envelope_dms' do
    let(:druid) { 'dc482zx1528' }
    let(:macro) { format_envelope_dms }

    context 'with a valid coordinate string' do
      let(:accumulator) { [Cocina::Models::DescriptiveValue.new(value: 'W 123°23ʹ16ʺ--W 122°31ʹ22ʺ/N 39°23ʹ57ʺ--N 38°17ʹ53ʺ').as_json] }

      it 'returns the solr-formatted ENVELOPE string' do
        expect(accumulator).to eq ['ENVELOPE(-123.38777777777779, -122.52277777777778, 39.399166666666666, 38.29805555555556)']
      end
    end

    context 'with an invalid coordinate string' do
      let(:accumulator) { [Cocina::Models::DescriptiveValue.new(value: 'invalid').as_json] }

      it 'returns an empty array' do
        expect(accumulator).to be_empty
      end
    end
  end

  describe 'format_envelope_bbox' do
    let(:macro) { format_envelope_bbox }

    context 'with a valid bounding box' do
      let(:accumulator) do
        [
          Cocina::Models::DescriptiveStructuredValue.new(
            structuredValue: [
              { type: 'west', value: '-122.182222' },
              { type: 'east', value: '-122.182222' },
              { type: 'north', value: '37.421944' },
              { type: 'south', value: '37.421944' }
            ]
          ).as_json
        ]
      end

      it 'returns the solr-formatted ENVELOPE string' do
        expect(accumulator).to eq ['ENVELOPE(-122.182222, -122.182222, 37.421944, 37.421944)']
      end
    end

    context 'with an invalid bounding box' do
      let(:accumulator) do
        [
          Cocina::Models::DescriptiveStructuredValue.new(
            structuredValue: [
              { type: 'west', value: '-122.182222' },
              { type: 'east', value: '-122.182222' },
              { type: 'north', value: '37.421944' },
              { type: 'south', value: 'invalid' }
            ]
          ).as_json
        ]
      end

      it 'returns an empty array' do
        expect(accumulator).to be_empty
      end
    end
  end
end
