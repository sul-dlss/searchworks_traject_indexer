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
    config: './lib/traject/config/geo_config.rb',
    settings: {
      'log.file' => 'log/traject_earthworks-prod-indexer.log',
      'kafka.topic' => 'purl_fetcher_prod',
      'kafka.consumer_group_id' => 'earthworks-prod-indexer',
      'solr.url' => 'http://sul-solr.stanford.edu/solr/earthworks-prod'
    }
  },
  {
    key: 'folio_prod_indexer',
    count: 8,
    config: './lib/traject/config/folio_config.rb',
    settings: {
      'log.file' => 'log/traject_folio_prod_indexer.log',
      'kafka.topic' => 'marc_folio_prod',
      'kafka.consumer_group_id' => 'traject_folio_prod',
      'reader_class_name' => 'Traject::KafkaFolioReader',
      'solr.url' => 'http://sul-solr.stanford.edu/solr/searchworks-folio-prod'
    }
  },
  {
    key: 'sdr_prod_indexer',
    count: 4,
    config: './lib/traject/config/sdr_config.rb',
    settings: {
      'log.file' => 'log/traject_sdr_folio_prod_indexer.log',
      'kafka.topic' => 'purl_fetcher_prod',
      'kafka.consumer_group_id' => 'traject_sdr_folio_prod',
      'solr.url' => 'http://sul-solr.stanford.edu/solr/searchworks-folio-prod'
    }
  },
  {
    key: 'folio_searchworks_prod_next_indexer',
    count: 4,
    config: './lib/traject/config/folio_config.rb',
    settings: {
      'log.file' => 'log/traject_searchworks_prod_next_indexer.log',
      'kafka.topic' => 'marc_folio_prod',
      'kafka.consumer_group_id' => 'traject_searchworks_next_prod',
      'reader_class_name' => 'Traject::KafkaFolioReader',
      'solr.url' => 'http://sul-solr.stanford.edu/solr/searchworks-prod-next'
    }
  },
  {
    key: 'sdr_searchworks_prod_next_indexer',
    count: 2,
    config: './lib/traject/config/sdr_config.rb',
    settings: {
      'log.file' => 'log/traject_sdr_searchworks_prod_next_indexer.log',
      'kafka.topic' => 'purl_fetcher_prod',
      'kafka.consumer_group_id' => 'traject_searchworks_next_prod',
      'solr.url' => 'http://sul-solr.stanford.edu/solr/searchworks-prod-next'
    }
  }
]
