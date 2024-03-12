# frozen_string_literal: true

require 'spec_helper'
require 'benchmark'

# These test enables us to benchmark the query speed.
RSpec.describe Traject::FolioPostgresReader do
  describe '.encoding_cleanup' do
    it 'encodes cyrilic correctly' do
      expect(described_class.encoding_cleanup('Strategii︠a︡ planirovanii︠a︡ izbiratelʹnoĭ kampanii')).to eq('Strategii͡a planirovanii͡a izbiratelʹnoĭ kampanii')
    end

    it 'returns unencoded string without change' do
      expect(described_class.encoding_cleanup('https://link.gale.com/apps/ECCO?u=stan90222')).to eq('https://link.gale.com/apps/ECCO?u=stan90222')
    end

    it 'returns encoded string without change' do
      expect(described_class.encoding_cleanup('Strategiii︠a planirovaniia︡ izbiratelʹnoĭ kampanii')).to eq('Strategiii︠a planirovaniia︡ izbiratelʹnoĭ kampanii')
    end
  end
end
