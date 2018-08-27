require 'traject'
require './lib/traject/readers/marc_combining_reader.rb'

RSpec.describe 'bad jruby handling of #slice_when (https://github.com/jruby/jruby/issues/5275)' do
  it 'handles single-record record merging' do
    doc = Traject::MarcCombiningReader.new(
      File.open(file_fixture('44794.marc').to_s, 'r'),
      'marc_source.type' => 'binary'
    ).each.first
    expect(doc).not_to be_nil
  end
end
