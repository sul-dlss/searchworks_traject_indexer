require 'spec_helper'

describe 'SDR indexing' do
  subject(:result) { indexer.map_record(PublicXmlRecord.new('bk264hq9320')) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sdr_config.rb')
    end
  end

  context 'with bk264hq9320' do
    before do
      without_partial_double_verification do
        if defined?(JRUBY_VERSION)
          allow(Manticore).to receive(:get).with('https://purl.stanford.edu/bk264hq9320.xml').and_return(double(body: File.read(file_fixture('bk264hq9320.xml').to_s)))
          allow(Manticore).to receive(:get).with('https://purl.stanford.edu/nj770kg7809.xml').and_return(double(body: File.read(file_fixture('nj770kg7809.xml').to_s)))
        else
          allow(HTTP).to receive(:get).with('https://purl.stanford.edu/bk264hq9320.xml').and_return(double(body: File.read(file_fixture('bk264hq9320.xml').to_s)))
          allow(HTTP).to receive(:get).with('https://purl.stanford.edu/nj770kg7809.xml').and_return(double(body: File.read(file_fixture('nj770kg7809.xml').to_s)))
        end
      end
    end

    it 'maps the data the same way as it does currently' do
      expect(result).to include "id" => ["bk264hq9320"],
                                "druid" => ["bk264hq9320"],
                                "title_245a_search" => ["Trustees Demo reel"],
                                "title_245_search" => ["Trustees Demo reel."],
                                "title_sort" => ["Trustees Demo reel"],
                                "title_245a_display" => ["Trustees Demo reel"],
                                "title_display" => ["Trustees Demo reel"],
                                "title_full_display" => ["Trustees Demo reel."],
                                "author_7xx_search" =>["Stanford University. News and Publications Service"],
                                "author_other_facet" =>["Stanford University. News and Publications Service"],
                                "author_sort" => ["􏿿 Trustees Demo reel"],
                                "author_corp_display" =>["Stanford University. News and Publications Service"],
                                "pub_search" =>["cau", "Stanford (Calif.)"],
                                "pub_year_isi" =>[2004],
                                "pub_date_sort" => ["2004"],
                                "imprint_display" => ["Stanford (Calif.), February 9, 2004"],
                                "pub_date" => ["2004"],
                                "pub_year_ss" => ["2004"],
                                "pub_year_tisim" =>[2004],
                                "creation_year_isi" =>[2004],
                                "format_main_ssim" =>["Video"],
                                "format" =>["Video"],
                                "language" =>["English"],
                                "physical" =>["1 MiniDV tape"],
                                "url_suppl" =>[
                                  "http://www.oac.cdlib.org/findaid/ark:/13030/c8dn43sv",
                                  "https://purl.stanford.edu/nj770kg7809"
                                ],
                                "url_fulltext" => ["https://purl.stanford.edu/bk264hq9320"],
                                "access_facet" => ["Online"],
                                "building_facet" => ["Stanford Digital Repository"],
                                "collection" =>["9665836"],
                                "collection_with_title" =>["9665836-|-Stanford University, News and Publication Service, audiovisual recordings, 1936-2011 (inclusive)"],
                                "all_search" => [" Trustees Demo reel Stanford University. News and Publications Service pro producer moving image cau Stanford (Calif.) 2004-02-09 eng English videocassette 1 MiniDV tape access reformatted digital video/mp4 image/jpeg NTSC Sound Color Reformatted by Stanford University Libraries in 2017. sc1125_s02_b11_04-0209-1 Stanford University. Libraries. Department of Special Collections and University Archives SC1125 https://purl.stanford.edu/bk264hq9320 Stanford University, News and Publication Service, Audiovisual Recordings (SC1125) http://www.oac.cdlib.org/findaid/ark:/13030/c8dn43sv English eng CSt human prepared Stanford University, News and Publication Service, audiovisual recordings, 1936-2011 (inclusive) https://purl.stanford.edu/nj770kg7809 The materials are open for research use and may be used freely for non-commercial purposes with an attribution. For commercial permission requests, please contact the Stanford University Archives (universityarchives@stanford.edu). "]

      expect(result).to include "modsxml"

      expect(result).not_to include "title_variant_search", "author_meeting_display", "author_person_display", "author_person_full_display", "author_1xx_search",
                                    "topic_search", "geographic_search", "subject_other_search", "subject_other_subvy_search", "subject_all_search",
                                    "topic_facet", "geographic_facet", "era_facet", "publication_year_isi", "genre_ssim", "summary_search", "toc_search", "file_id",
                                    "set", "set_with_title"
    end
  end
end
