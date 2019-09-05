[![Build Status](https://travis-ci.org/sul-dlss/searchworks_traject_indexer.svg?branch=master)](https://travis-ci.org/sul-dlss/searchworks_traject_indexer) [![Code Climate Test Coverage](https://codeclimate.com/github/sul-dlss/searchworks_traject_indexer/badges/coverage.svg)](https://codeclimate.com/github/sul-dlss/searchworks_traject_indexer/coverage)

# SearchworksTrajectIndexer

## Installation

```sh
$ bundle install
```


## Running test suite

```sh
$ bundle exec rake
```

## Running Traject indexer

Can be run using MRI or jruby

```sh
SOLR_VERSION=6.6.5 NUM_THREADS=1 SOLR_URL=http://127.0.0.1:8983/solr/blacklight-core bundle exec traject -c lib/traject/config/sirsi_config.rb uni_00000000_00499999.marc
```


## Custom settings

This codebase sets up custom settings that are used internally beyond what traject provides.

Setting | Description | Default
------- | ----------- | -------
`skip_empty_item_display` | Can be provided via an env variable `SKIP_EMPTY_ITEM_DISPLAY` which tells the sirsi traject code to skip or not skip empty item_display fields. Anything greater than -1 will skip. Test are set to use `-1` unless otherwise configured | `0`

# Configuration

The indexing processes are managed by a common [eye configuration](./traject.eye). It reads information from the `config/settings.yml` (using the `config` gem) to set up the indexing daemons. The `config/settings.yml` file is configured as a capistrano shared file, allowing each deployment environment to have separate configuration. The configuration for a specific indexing daemon looks something like:

```yaml
processes:
  - name: marc_bodoni_prod_indexer
    env:
      NUM_THREADS: 24
      JRUBY_OPTS: "-J-Xmx8192m"
      KAFKA_TOPIC: marc_bodoni
      SOLR_URL: http://sul-solr.stanford.edu/solr/searchworks-prod
      KAFKA_CONSUMER_GROUP_ID: traject_marc_bodoni_prod
    config:
      start_command: '/usr/local/rvm/bin/rvm jruby-9.2.7.0 do bundle exec honeybadger exec traject -c ./lib/traject/config/sirsi_config.rb -s solr_writer.max_skipped=-1 -s log.level=debug -s log.file=log/traject_marc_bodoni_prod_indexer.log'
```

As of September 2019, the `config/settings.yml` are not managed in sul-dlss/shared_configs (for better or worse).


# Indexing Strategies

## Sirsi

MARC binary data is dumped into files (each containing ~500k records) on the Symphony servers. These dumps happen hourly (containing every changed MARC record during that calendar day), nightly (containing every record changed the previous day), and monthly (containing every exportable MARC record in Symphony). Hourly and nightly dumps also include a `del` file, containing a catkey-per-line of records that have been deleted or retracted.

Additional data comes from a course reserves data dump, also on the Symphony servers. Course reserves files are pipe `|` separated values (PSV) files which are read in during the indexing process and used to enhance MARC records during the transform process.

The indexing machines have scheduled cron tasks (see `./config/schedule.rb`) that retrieve this data from the Symphony servers and process the data into a kafka topic. Messages in the topic are key-value pairs; the key is the catkey of the record, and the value is either blank (representing a delete) or containing one or more binary MARC records for the catkey. The topics are regularly compacted by Kafka to remove duplicate data.

There are daemon processes managed by eye (see `./traject.eye` locally, and `./config/settings.yml` on the deployed servers) that continously consume the kafka topics and run the traject indexing configuration on the data.

Traject can also index one or more MARC record directly. An example of a traject command used for indexing:

```sh
$ SOLR_URL=http://www.example.com/solr/collection-name NUM_THREADS=4 bundle exec traject -c lib/traject/config/sirsi_config.rb /path/uni_00000000_00499999.marc
```

## SDR

The indexing machines also have schedule cron tasks (again, see `./config/schedule.rb`) for loading data from purl-fetcher into a kafka topic. This task records a state file (in `./tmp`) that contains the timestamp of the most recent entry from purl-fetcher that was processed. Every minute, the cron task runs, retrieves the purl-fetcher changes since that most recent timestamp, and adds the message to a kafka topic.

A daemon process managed by eye continuously consumes the kafka topic to run the traject indexing configuration on the data.
