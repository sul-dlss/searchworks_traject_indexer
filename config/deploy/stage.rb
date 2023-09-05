# frozen_string_literal: true

server 'sw-indexing-stage-a.stanford.edu', user: 'indexer', roles: %w[app stage]

Capistrano::OneTimeKey.generate_one_time_key!

set :indexers, [
  {
    key: 'sdr_preview_stage_indexer',
    count: 2,
    config: './lib/traject/config/sdr_config.rb',
    settings: {
      'log.file' => 'log/traject_sdr_preview_stage_indexer.log',
      'kafka.topic' => 'purl_fetcher_stage',
      'kafka.consumer_group_id' => 'traject_sdr_preview_stage',
      'purl.url' => 'https://sul-purl-test.stanford.edu',
      'purl_fetcher.target' => 'SearchWorksPreview',
      'purl_fetcher.skip_catkey' => false,
      'solr.url' => 'http://sul-solr.stanford.edu/solr/sw-preview-stage'
    }
  },
  {
    key: 'earthworks_stage_indexer',
    count: 1,
    config: './lib/traject/config/geo_config.rb',
    settings: {
      'log.file' => 'log/traject_earthworks-stage-indexer.log',
      'kafka.topic' => 'purl_fetcher_stage',
      'kafka.consumer_group_id' => 'earthworks-stage-indexer',
      'solr.url' => 'http://sul-solr.stanford.edu/solr/earthworks-stage',
      'purl.url' => 'https://sul-purl-stage.stanford.edu',
      'stacks.url' => 'https://sul-stacks-stage.stanford.edu',
      'geoserver.pub_url' => 'https://earthworks-geoserver-stage-b.stanford.edu/geoserver',
      'geoserver.stan_url' => 'https://earthworks-geoserver-stage-a.stanford.edu/geoserver'
    }
  },
  {
    key: 'folio_dev_indexer',
    count: 8,
    config: './lib/traject/config/folio_config.rb',
    settings: {
      'log.file' => 'log/traject_folio_dev_indexer.log',
      'kafka.topic' => 'folio_test',
      'kafka.consumer_group_id' => 'traject_folio_dev',
      'reader_class_name' => 'Traject::KafkaFolioReader',
      'solr.url' => 'http://sul-solr.stanford.edu/solr/searchworks-folio-dev'
    }
  },
  {
    key: 'sw_gryphonsearch_indexer',
    count: 8,
    config: './lib/traject/config/folio_config.rb',
    settings: {
      'log.file' => 'log/traject_sw_gryphonsearch_indexer.log',
      'kafka.topic' => 'marc_folio_prod',
      'kafka.consumer_group_id' => 'traject_sw_gryphonsearch_indexer',
      'reader_class_name' => 'Traject::KafkaFolioReader',
      'kafka.hosts' => 'sul-kafka-prod-a.stanford.edu:9092',
      'solr.url' => 'http://sul-solr.stanford.edu/solr/searchworks-gryphon-search'
    }
  },
  {
    key: 'sw_gryphonsearch_sdr_indexer',
    count: 4,
    config: './lib/traject/config/sdr_config.rb',
    settings: {
      'log.file' => 'log/traject_sw_gryphonsearch_sdr_indexer.log',
      'kafka.topic' => 'purl_fetcher_prod',
      'kafka.consumer_group_id' => 'traject_sw_gryphonsearch_indexer',
      'kafka.hosts' => 'sul-kafka-prod-a.stanford.edu:9092',
      'solr.url' => 'http://sul-solr.stanford.edu/solr/searchworks-gryphon-search'
    }
  }
]
