# frozen_string_literal: true

server 'sw-indexing-prod-a.stanford.edu', user: 'indexer', roles: %w[app prod]

Capistrano::OneTimeKey.generate_one_time_key!

set :indexers, [
  {
    key: 'sdr_preview_indexer',
    count: 2,
    config: './lib/traject/config/sdr_config.rb',
    settings: {
      'log.file' => 'log/traject_sdr_preview_indexer.log',
      'kafka.topic' => 'purl_fetcher_prod',
      'kafka.consumer_group_id' => 'traject_sdr_preview_prod',
      'purl_fetcher.target' => 'SearchWorksPreview',
      'purl_fetcher.skip_catkey' => false,
      'solr.url' => 'http://sul-solr.stanford.edu/solr/sw-preview-prod'
    }
  },
  {
    key: 'earthworks_prod_indexer',
    count: 1,
    config: './lib/traject/config/geo_aardvark_config.rb',
    settings: {
      'log.file' => 'log/traject_earthworks-prod-indexer.log',
      'kafka.topic' => 'purl_fetcher_prod',
      'kafka.consumer_group_id' => 'earthworks-prod-indexer',
      'solr.url' => 'http://sul-solr.stanford.edu/solr/earthworks-aardvark-prod'
    }
  },
  { # Solr 8 searchworks index (replaced by folio_prod_indexer_2025 in December 2025),
    # and retained for maybe a couple months for comparison purposes
    key: 'folio_prod_indexer',
    count: 2,
    config: './lib/traject/config/folio_config.rb',
    settings: {
      'log.file' => 'log/traject_folio_prod_indexer.log',
      'kafka.topic' => 'marc_folio_prod',
      'kafka.consumer_group_id' => 'traject_folio_prod',
      'reader_class_name' => 'Traject::KafkaFolioReader',
      'solr.url' => 'http://sul-solr.stanford.edu/solr/searchworks-prod-previous'
    }
  },
  { # Solr 8 searchworks index (replaced by sdr_prod_indexer_2025 in December 2025)
    key: 'sdr_prod_indexer',
    count: 1,
    config: './lib/traject/config/sdr_config.rb',
    settings: {
      'log.file' => 'log/traject_sdr_folio_prod_indexer.log',
      'kafka.topic' => 'purl_fetcher_prod',
      'kafka.consumer_group_id' => 'traject_sdr_folio_prod',
      'solr.url' => 'http://sul-solr.stanford.edu/solr/searchworks-prod-previous'
    }
  },
  {
    key: 'folio_prod_indexer_2025',
    count: 8,
    config: './lib/traject/config/folio_config.rb',
    settings: {
      'log.file' => 'log/traject_folio_prod_2025_indexer.log',
      'kafka.topic' => 'marc_folio_prod',
      'kafka.consumer_group_id' => 'traject_folio_prod_2025',
      'reader_class_name' => 'Traject::KafkaFolioReader',
      'solr.url' => 'http://sul-solr.stanford.edu/solr/searchworks-prod-2025'
    }
  },
  {
    key: 'sdr_prod_indexer_2025',
    count: 4,
    config: './lib/traject/config/sdr_config.rb',
    settings: {
      'log.file' => 'log/traject_sdr_prod_indexer_2025.log',
      'kafka.topic' => 'purl_fetcher_prod',
      'kafka.consumer_group_id' => 'sdr_prod_indexer_2025',
      'solr.url' => 'http://sul-solr.stanford.edu/solr/searchworks-prod-2025'
    }
  }
]
