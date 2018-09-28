[![Build Status](https://travis-ci.org/sul-dlss/searchworks_traject_indexer.svg?branch=master)](https://travis-ci.org/sul-dlss/searchworks_traject_indexer) [![Coverage Status](https://coveralls.io/repos/github/sul-dlss/searchworks_traject_indexer/badge.svg?branch=master)](https://coveralls.io/github/sul-dlss/searchworks_traject_indexer?branch=master)

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


# Indexing Strategies

## Sirsi

This strategy uses a data source consisting of MARC binary data and course reserves content to build an index for SearchWorks. MARC files can be individual records, but are most likely large dumps of records (~500,000 each) from library systems. Course reserves files are pipe `|` separated values (PSV) files which are read in during the indexing process and used to enhance MARC records during the transform process.

An example of a traject command used for indexing:

```sh
$ SOLR_URL=http://www.example.com/solr/collection-name NUM_THREADS=4 RESERVES_FILE=/path/reserves-data.current -c lib/traject/config/sirsi_config.rb /path/uni_00000000_00499999.marc
```

## Sirsi Deletes

Library systems can also provide a "deletes" file of records that should be deleted from the index. This deletes file is just a text file where each line is a ckey identifier of an item to be deleted. Deletes can be run like so:

```sh
$ SOLR_URL=http://www.example.com/solr/collection-name -c lib/traject/config/delete_config.rb /path/ckeys_delete.del
```
