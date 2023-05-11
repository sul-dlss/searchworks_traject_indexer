# frozen_string_literal: true

RSpec.describe 'marc_links_struct' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end
  subject(:result) { indexer.map_record(record) }
  let(:record) { MARC::XMLReader.new(StringIO.new(marc)).to_a.first }
  let(:field) { 'marc_links_struct' }
  let(:result_field) { result[field].map { |x| JSON.parse(x, symbolize_names: true) } }

  context 'for a simple 856' do
    let(:marc) do
      <<-XML
        <record>
          <datafield tag='856' ind1='0' ind2='0'>
            <subfield code='3'>Link text 1</subfield>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='y'>Link text 2</subfield>
            <subfield code='z'>Title text1</subfield>
            <subfield code='z'>Title text2</subfield>
          </datafield>
        </record>
      XML
    end

    it 'should place the $3 and $y as the link text' do
      expect(result_field.first[:link_text]).to eq 'Link text 1 Link text 2'
    end
    it 'should place the $z as the link title' do
      expect(result_field.first[:link_title]).to eq 'Title text1 Title text2'
    end
    it 'should include the href' do
      expect(result_field.first[:href]).to eq 'https://library.stanford.edu'
    end
  end

  context 'for a no-label-document' do
    let(:marc) do
      <<-XML
        <record>
          <datafield tag='856' ind1='0' ind2='0'>
            <subfield code='u'>https://library.stanford.edu</subfield>
          </datafield>
        </record>
      XML
    end
    it 'should use the host of the URL if no text is available' do
      expect(result_field.first[:link_text]).to eq 'library.stanford.edu'
    end
  end

  context 'casalini links' do
    let(:marc) do
      <<-XML
        <record>
          <datafield tag='856' ind1='4' ind2='1'>
            <subfield code='3'>Link text</subfield>
            <subfield code='z'>Available to Stanford-affiliated users at:</subfield>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='x'>CasaliniTOC</subfield>
            <subfield code='y'>Link text</subfield>
            <subfield code='z'>(source: Casalini)</subfield>
          </datafield>
          <datafield tag='856' ind1='4' ind2='1'>
            <subfield code='3'>Link text</subfield>
            <subfield code='z'>Available to Stanford-affiliated users at:</subfield>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='y'>Link text</subfield>
            <subfield code='z'>(source: Casalini)</subfield>
          </datafield>
          <datafield tag='856' ind1='4' ind2='1'>
            <subfield code='3'>Link text</subfield>
            <subfield code='z'>Available to Stanford-affiliated users at:</subfield>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='x'>CasaliniTOC</subfield>
            <subfield code='y'>Link text</subfield>
          </datafield>
        </record>
      XML
    end
    it 'places $3 as the link text' do
      expect(result_field.first[:link_text]).to eq 'Link text'
    end
    it 'identifies the link as a Casalini link from value of $x or $z' do
      expect(result_field.all? { |x| x[:casalini] }).to be_truthy
    end
  end

  context 'stanford_only' do
    let(:marc) do
      <<-XML
        <record>
          <datafield tag='856' ind1='0' ind2='0'>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='y'>Link text</subfield>
            <subfield code='z'>Available to stanford affiliated users at:4 at one time</subfield>
          </datafield>
          <datafield tag='856' ind1='0' ind2='0'>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='y'>Link text</subfield>
            <subfield code='z'>Available-to-stanford-affiliated-users-at:</subfield>
          </datafield>
          <datafield tag='856' ind1='0' ind2='0'>
            <subfield code='3'>Available to stanford affiliated users at</subfield>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='y'>Link text</subfield>
          </datafield>
          <datafield tag='856' ind1='0' ind2='0'>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='y'>Link text</subfield>
            <subfield code='z'>Available to stanford affiliated users</subfield>
          </datafield>
        </record>
      XML
    end
    it 'should identify all the permutations of the Stanford Only string as Stanford Only resources' do
      expect(result_field).to be_present
      expect(result_field.all? { |x| x[:stanford_only] }).to be_truthy
      expect(result_field.select { |x| x[:additional_text].present? }.length).to eq 1
    end
  end

  context 'Stanford law only' do
    let(:marc) do
      <<-XML
        <record>
          <datafield tag='856' ind1='0' ind2='0'>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='y'>Link text</subfield>
            <subfield code='z'>Available to stanford law school community</subfield>
          </datafield>
        </record>
      XML
    end

    it 'should show availability text' do
      expect(result_field).to be_present
      expect(result_field.first[:additional_text]).to eq 'Available to stanford law school community'
    end
  end

  context 'fulltext' do
    let(:marc) do
      <<-XML
        <record>
          <datafield tag='856' ind1='0' ind2='0'>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='y'>Link text</subfield>
          </datafield>
          <datafield tag='856' ind1='0' ind2='1'>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='y'>Link text</subfield>
          </datafield>
          <datafield tag='856' ind1='0' ind2='3'>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='y'>Link text</subfield>
          </datafield>
          <datafield tag='856' ind1='0' ind2='4'>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='y'>Link text</subfield>
          </datafield>
        </record>
      XML
    end
    it 'should identify fulltext links' do
      expect(result_field).to be_present
      expect(result_field.all? { |x| x[:fulltext] }).to be_truthy
    end
  end

  context 'managed_purl' do
    let(:marc) do
      <<-XML
        <record>
          <datafield tag='856' ind1='0' ind2='0'>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='x'>SDR-PURL</subfield>
            <subfield code='x'>file:abc123</subfield>
            <subfield code='x'>label:some label</subfield>
            <subfield code='x'>sort:123</subfield>
            <subfield code='y'>Link text 2</subfield>
          </datafield>
        </record>
      XML
    end

    it 'should return the managed purl links' do
      expect(result_field).to be_present
      expect(result_field.all? { |x| x[:managed_purl] }).to be_truthy
    end

    it 'should return the file_id (without "file:")' do
      expect(result_field.first[:file_id]).to eq 'abc123'
    end

    it 'should return the sort (without "sort:")' do
      expect(result_field.first[:sort]).to eq '123'
    end

    it 'should return the label (without "label:")' do
      expect(result_field.first[:link_text]).to eq 'some label'
    end

    context 'when stanford affiliated' do
      let(:marc) do
        <<-XML
          <record>
            <datafield tag='856' ind1='0' ind2='0'>
              <subfield code='u'>https://library.stanford.edu</subfield>
              <subfield code='x'>SDR-PURL</subfield>
              <subfield code='x'>file:abc123</subfield>
              <subfield code='z'>Available to stanford affiliated users at</subfield>
            </datafield>
          </record>
        XML
      end

      it 'does not include empty html from the additional_text that cannot be displayed' do
        expect(result_field.first[:text]).to be_blank
      end
    end
  end

  context 'supplemental' do
    let(:marc) do
      <<-XML
        <record>
          <datafield tag='856' ind1='0' ind2='2'>
            <subfield code='3'>Before text</subfield>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='y'>Link text</subfield>
            <subfield code='z'>Title text1</subfield>
          </datafield>
          <datafield tag='856' ind1='0' ind2='2'>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='y'>Link text</subfield>
            <subfield code='z'>Title text</subfield>
          </datafield>
          <datafield tag='856' ind1='0' ind2='0'>
            <subfield code='3'>this is the table of contents</subfield>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='y'>Link text</subfield>
          </datafield>
          <datafield tag='856' ind1='0' ind2='0'>
            <subfield code='3'>this is sample text</subfield>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='y'>Link text</subfield>
          </datafield>
          <datafield tag='856' ind1='0' ind2='1'>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='y'>Link text</subfield>
            <subfield code='z'>this is the abstract</subfield>
          </datafield>
          <datafield tag='856' ind1='0' ind2=''>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='y'>Link text</subfield>
            <subfield code='z'>this is the description</subfield>
          </datafield>
          <datafield tag='856' ind1='0' ind2=''>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='y'>Link text</subfield>
          </datafield>
        </record>
      XML
    end
    it 'should identify supplemental links' do
      expect(result_field).to be_present
      expect(result_field.any? { |x| x[:fulltext] }).to be_falsey
    end
  end
  context 'finding_aid' do
    let(:marc) do
      <<-XML
        <record>
          <datafield tag='856' ind1='0' ind2='2'>
            <subfield code='3'>FINDING AID:</subfield>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='y'>Link text</subfield>
            <subfield code='z'>Title text1</subfield>
          </datafield>
          <datafield tag='856' ind1='0' ind2='2'>
            <subfield code='u'>https://library.stanford.edu</subfield>
            <subfield code='y'>Link text</subfield>
            <subfield code='z'>This is a finding aid</subfield>
          </datafield>
        </record>
      XML
    end
    it 'should return all finding aid links' do
      expect(result_field).to be_present
      expect(result_field.all? { |x| x[:finding_aid] }).to be_truthy
    end
  end
  describe 'ez-proxy' do
    let(:marc) do
      <<-XML
        <record>
          <datafield tag='856' ind1='0' ind2='0'>
            <subfield code='u'>https://stanford.idm.oclc.org/?url=https://library.stanford.edu</subfield>
          </datafield>
        </record>
      XML
    end

    it 'should place the host of the url parameter as link text if no explicit label is available' do
      expect(result_field.first[:link_text]).to eq 'library.stanford.edu'
    end
  end
  context 'bad URLs' do
    context 'when an 856 has no $u' do
      let(:marc) do
        <<-XML
          <record>
            <datafield tag='856' ind1='0' ind2='0'>
              <subfield code='y'>Some text</subfield>
            </datafield>
          </record>
        XML
      end
      it 'should not return anything' do
        expect(result[field]).not_to be_present
      end
    end

    context 'with URLs with spaces in them' do
      let(:marc) do
        <<-XML
          <record>
            <datafield tag='856' ind1='0' ind2='0'>
              <subfield code='u'>https://stanford.idm.oclc.org/?url=https://library.stanford.edu/url%20that has+spaces</subfield>
            </datafield>
          </record>
        XML
      end

      it 'handles pulling the proxy host' do
        expect(result_field.first[:link_text]).to eq 'library.stanford.edu'
      end
    end
  end

  # this is testing a workaround for a JRuby internal encoding bug that blows up with
  # invalid byte sequence in US-ASCII trying to parse that url.
  context 'for a url with utf-8 data in it' do
    let(:marc) do
      <<-XML
        <record>
          <datafield tag='856' ind1='0' ind2='0'>
            <subfield code='u'>https://stanford.idm.oclc.org/login?url=http://www.bookrail.co.kr/upload/download/BookRail%20%EB%AA%A8%EB%B0%94%EC%9D%BC%20%EB%A7%A4%EB%89%B4%EC%96%BC_2011.06.pdf</subfield>
          </datafield>
        </record>
      XML
    end

    it 'handles pulling the proxy host' do
      expect(result_field.first[:link_text]).to eq 'www.bookrail.co.kr'
    end
  end
end
