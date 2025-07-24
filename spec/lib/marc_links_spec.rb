# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MarcLinks::Processor do
  subject(:marc_link) { described_class.new(field) }

  describe '#as_h' do
    subject { marc_link.as_h }

    context 'with a 856g' do
      let(:field) do
        MARC::DataField.new('856', '4', '0',
                            ['g', 'https://doi.org/10.58748/brujula16'],
                            ['u', 'https://www.somelink.edu'],
                            ['n', 'Open Access'],
                            %w[7 0])
      end

      it { is_expected.to include(href: 'https://doi.org/10.58748/brujula16', link_text: 'doi.org') }
    end

    context 'with two 856u' do
      let(:field) do
        MARC::DataField.new('856', '4', '0',
                            ['u', 'https://www.somelink.edu'],
                            ['u', 'https://www.otherlink.edu'],
                            %w[7 0])
      end

      it {
        is_expected.to include(href: 'https://www.somelink.edu', link_text: 'www.somelink.edu',
                               additional_links: [{ href: 'https://www.otherlink.edu' }])
      }
    end

    context 'with a 8567 = 0' do
      let(:field) do
        MARC::DataField.new('856', '4', '0',
                            ['u', 'https://www.somelink.edu'],
                            %w[7 0])
      end

      it { is_expected.to include(access: 'open') }
    end

    context 'with a 8567 = 1' do
      let(:field) do
        MARC::DataField.new('856', '4', '0',
                            ['u', 'https://www.somelink.edu'],
                            %w[7 1])
      end

      it { is_expected.to include(access: 'restricted') }
    end
  end

  describe '#link_is_fulltext?' do
    context '956 tag with an SFX link' do
      let(:field) { MARC::DataField.new('956', ' ', '0', ['u', 'https://library.stanford.edu/sfx?one=one']) }

      it { expect(marc_link.link_is_fulltext?).to be false }
    end

    context '956 tag that is not an SFX link' do
      let(:field) { MARC::DataField.new('956', ' ', '0', ['u', 'https://www.somelink.edu']) }

      it { expect(marc_link.link_is_fulltext?).to be true }
    end

    context '856 tag where the second indicator is 0' do
      let(:field) { MARC::DataField.new('856', ' ', '0', ['u', 'https://www.somelink.edu']) }

      it { expect(marc_link.link_is_fulltext?).to be true }
    end

    context '856 tag where the second indicator is 1' do
      let(:field) { MARC::DataField.new('856', ' ', '1', ['u', 'https://www.somelink.edu']) }

      it { expect(marc_link.link_is_fulltext?).to be true }
    end

    context '856 tag where the second indicator is 2' do
      let(:field) { MARC::DataField.new('856', ' ', '2', ['u', 'https://www.somelink.edu']) }

      it { expect(marc_link.link_is_fulltext?).to be false }
    end

    context '856 tag where the second indicator is 3' do
      let(:field) { MARC::DataField.new('856', ' ', '3', ['u', 'https://www.somelink.edu']) }

      it { expect(marc_link.link_is_fulltext?).to be true }
    end

    context '856 tag where the second indicator is 4' do
      let(:field) { MARC::DataField.new('856', ' ', '4', ['u', 'https://www.somelink.edu']) }

      it { expect(marc_link.link_is_fulltext?).to be true }
    end

    context '856 tag where the second indicator is 0 and the link is for a table of contents' do
      let(:field) { MARC::DataField.new('856', ' ', '0', ['u', 'https://www.somelink.edu'], ['z', 'Table of Contents']) }

      it { expect(marc_link.link_is_fulltext?).to be false }
    end
  end

  describe '#link_is_supplemental?' do
    context '856 tag where the second indicator is 0' do
      let(:field) { MARC::DataField.new('856', ' ', '0', ['u', 'https://www.somelink.edu']) }

      it { expect(marc_link.link_is_supplemental?).to be false }
    end

    context '856 tag where the second indicator is 2' do
      let(:field) { MARC::DataField.new('856', ' ', '2', ['u', 'https://www.somelink.edu']) }

      it { expect(marc_link.link_is_supplemental?).to be true }
    end

    context '856 tag where the second indicator is 3' do
      let(:field) { MARC::DataField.new('856', ' ', '3', ['u', 'https://www.somelink.edu']) }

      it { expect(marc_link.link_is_supplemental?).to be false }
    end

    context '856 tag where the second indicator is 4' do
      let(:field) { MARC::DataField.new('856', ' ', '4', ['u', 'https://www.somelink.edu']) }

      it { expect(marc_link.link_is_supplemental?).to be false }
    end

    context '856 tag where the second indicator is 4 and the link is for an abstract' do
      let(:field) { MARC::DataField.new('856', ' ', '4', ['u', 'https://www.somelink.edu'], %w[z Abstract]) }

      it { expect(marc_link.link_is_supplemental?).to be true }
    end
  end

  describe '#stanford_only?' do
    context 'Subfield 3 contains "Available to Stanford affiliated users at: some url"' do
      let(:field) { MARC::DataField.new('856', ' ', ' ', ['3', 'Available to Stanford affiliated users at: some url']) }

      it { expect(marc_link.stanford_only?).to be true }
    end

    context 'Subfield z contains "Available to Stanford-affiliated users at: some url"' do
      let(:field) { MARC::DataField.new('856', ' ', ' ', ['z', 'Available to Stanford-affiliated users at: some url']) }

      it { expect(marc_link.stanford_only?).to be true }
    end

    context 'Subfield 3 contains "Available to Stanford affiliated users"' do
      let(:field) { MARC::DataField.new('856', ' ', ' ', ['3', 'Available to Stanford affiliated users']) }

      it { expect(marc_link.stanford_only?).to be true }
    end

    context 'Subfield z contains "Available to Stanford-affiliated users"' do
      let(:field) { MARC::DataField.new('856', ' ', ' ', ['z', 'Available to Stanford-affiliated users']) }

      it { expect(marc_link.stanford_only?).to be true }
    end

    context 'Subfield z contains "Access restricted to Stanford community"' do
      let(:field) { MARC::DataField.new('856', ' ', ' ', ['z', 'Access restricted to Stanford community']) }

      it { expect(marc_link.stanford_only?).to be true }
    end

    context 'Subfield z contains a note that does not indicate the link is restricted' do
      let(:field) { MARC::DataField.new('856', ' ', ' ', ['z', 'Some random note']) }

      it { expect(marc_link.stanford_only?).to be false }
    end
  end
end
