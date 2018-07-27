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
