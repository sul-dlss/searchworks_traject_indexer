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
