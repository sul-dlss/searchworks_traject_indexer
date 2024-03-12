# frozen_string_literal: true

require 'spec_helper'
require 'benchmark'

# These test enables us to benchmark the query speed.
RSpec.describe Traject::FolioPostgresReader do
  context 'check encoding parsing' do
    encoding_sample_str_json = JSON.generate({ 'title1' => 'Strategii︠a︡ planirovanii︠a︡ izbiratelʹnoĭ kampanii',
                                               'title2' => 'Unencoded string',
                                               'title3' => 'Strategiii︠a planirovaniia︡ izbiratelʹnoĭ kampanii' })
    let(:encoded_string) do
      JSON.parse(described_class.encoding_cleanup(encoding_sample_str_json))
    end

    it 'encodes cyrilic correctly' do
      expect(encoded_string['title1']).to eq('Strategii͡a planirovanii͡a izbiratelʹnoĭ kampanii')
    end

    it 'returns unencoded string without change' do
      expect(encoded_string['title2']).to eq('Unencoded string')
    end

    it 'returns encoded string without change' do
      expect(encoded_string['title3']).to eq('Strategiii︠a planirovaniia︡ izbiratelʹnoĭ kampanii')
    end
  end
end
