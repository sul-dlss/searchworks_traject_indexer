# SearchworksTrajectIndexer
[![CI status](https://github.com/sul-dlss/searchworks_traject_indexer/actions/workflows/ruby.yml/badge.svg)](https://github.com/sul-dlss/searchworks_traject_indexer/actions/workflows/ruby.yml)
[![Current release](https://img.shields.io/github/v/release/sul-dlss/searchworks_traject_indexer)](https://github.com/sul-dlss/searchwork_traject_indexer/releases)
![tested on ruby 3.1](https://img.shields.io/badge/ruby-v3.1-red)
![tested on jruby 9.3](https://img.shields.io/badge/jruby-v9.3-red)

<p align="center">indexing MARC, MODS, and more for <a href="https://github.com/sul-dlss/SearchWorks">SearchWorks</a>.</p>
<img src="preview.png" align="center" alt="solr index fields displayed overlaid on SearchWorks catalog preview for a book">

## local development
searchworks_traject_indexer is built on the [traject](https://github.com/traject/traject) transformation library, which requires ruby. we test the application using ruby 3.1 and jruby v9.3; support for other versions is not guaranteed.

after cloning the repository, install dependencies:
```sh
bundle install
```
then, you can test out indexing against a local solr index:
```sh
SOLR_URL=http://localhost:8983/solr/core-name bundle exec traject -c lib/traject/config/sirsi_config.rb my_marc_file.marc
```
the above command will index the file `my_marc_file.marc` into the solr core `core-name` using the configuration for Symphony (`sirsi_config.rb`). after the command completes, you can check the solr web interface to see what was indexed.

for assistance creating and managing a local solr instance for development, see [solr_wrapper](https://github.com/cbeer/solr_wrapper). for more on indexing, see "indexing data" below.
## testing
you can run the full test suite with:
```sh
bundle exec rake
```
note that some integration tests may hit a live server, for which you may need to be on the Stanford VPN.
## indexing data
indexing is a multi-step process:
1. an extractor process publishes data to be indexed to a [kafka](https://kafka.apache.org/) topic
2. a daemon run by [eye](https://github.com/kostya/eye) consumes data from the kafka topic and invokes traject
3. traject uses a given configuration to index the data into a solr collection
### publishing data to kafka
extractor processes are written as ruby scripts in `script/` and usually invoked by shell scripts located in the same directory. they make use of traject extractor classes stored in `lib/traject/extractors/`, which use the ruby kafka client to publish data to a kafka topic using the pattern:
```ruby
producer.produce(record, key: id, topic: topic)
``` 
the key is usually a unique identifier like a catkey or DRUID, and the topic groups all data that should be consumed by a single traject indexer.

the shell scripts that invoke extractors are run on a schedule as `cron` jobs, defined by `config/schedule.rb`. you can override this schedule if necessary when debugging by using the `crontab` utility in an `ssh` session.

when debugging extractor processes, it can be helpful to manage the messages in kafka queues directly. in an `ssh` session on the kafka machine, you can find utilities for managing kafka queues in `/opt/kafka/bin/`.

you can, for example, list all configured consumer groups and topics:
```sh
/opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --all-groups --all-topics
```
another useful operation is resetting the messages published in a particular topic:
```sh
/opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group traject_folio_dev --topic marc_folio_test --reset-offsets --to-earliest
```
some tools offer the option to "plan" execution by default, and actually execute using the `--execute` flag. for more, try passing `--help`.
### consuming data from kafka
the daemon processes are managed by a common [eye configuration](./traject.eye). it reads information from the `config/settings.yml` (using the `config` gem) to set up the indexing daemons.

the `config/settings.yml` file is configured as a capistrano shared file, allowing each deployment environment to have separate configuration. note that most settings are not checked into GitHub and are not available in `shared_configs`.

you can override settings in local development by creating your own `config/settings.local.yml`. on production servers, the configuration for a specific indexing daemon looks something like:

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
      start_command: '/usr/local/rvm/bin/rvm jruby-9.3.2.0 do bundle exec honeybadger exec traject -c ./lib/traject/config/sirsi_config.rb -s solr_writer.max_skipped=-1 -s log.level=debug -s log.file=log/traject_marc_bodoni_prod_indexer.log'
```
daemon processes run continuously. you can use `eye info` in an ssh session to view status information:
```sh
$ eye info

traject
  workers
    earthworks-stage-indexer_0 .... up  (12:07, 0%, 73Mb, <1218016>)
    folio_dev_indexer_0 ........... up  (14:34, 6%, 137Mb, <1386323>)
    marc_bodoni_dev_indexer_0 ..... up  (12:07, 0%, 2731Mb, <1223573>)
    marc_morison_dev_indexer_0 .... up  (12:07, 0%, 1253Mb, <1223963>)
    sw_dev_indexer_0 .............. up  (12:07, 0%, 75Mb, <1224054>)
    sw_dev_indexer_1 .............. up  (12:07, 0%, 73Mb, <1224303>)
    sw_preview_stage_indexer_0 .... up  (12:07, 0%, 73Mb, <1224638>)
    sw_preview_stage_indexer_1 .... up  (12:07, 0%, 73Mb, <1224861>)
```
you can stop and start daemons with e.g. `eye stop sw_dev_indexer`. note that it may take some time for all the processes to start and stop. for more information on eye, use `eye help` or see the [eye wiki](https://github.com/kostya/eye/wiki).

### indexing the data into solr
traject configurations specific to each target environment are responsible for transforming the data into a format that can be indexed into solr. you can view the configuration files in `lib/traject/config/`, which often include traject commands like:
```ruby
to_field 'pub_country', extract_marc('008')
```
which extracts information from the 008 field of a MARC record and puts it into the `pub_country` field of the solr document.

each traject configuration specifies a reader class located in `lib/traject/readers/` that can read the data from the kafka topic and hand it off to be transformed into solr JSON.

other configuration values, like the URL of the solr instance, are usually set at the top of the configuration file using traject's `provide`. many can be set by environment variables; some of these in turn are set by the eye configuration:
```yaml
processes:
  - name: my_indexer
    env:
      SOLR_URL: http://sul-solr.stanford.edu/solr/searchworks-prod # controls where traject indexes to
```
in local development, you can invoke traject on the command line and override these settings by passing environment variables:
```sh
SOLR_URL=http://localhost:8983/solr/core-name bundle exec traject -c lib/traject/config/sirsi_config.rb my_marc_file.marc
```
## environments
### Symphony ILS (Sirsi)
MARC binary data is dumped into files (each containing ~500k records) on the Symphony servers. These dumps happen hourly (containing every changed MARC record during that calendar day), nightly (containing every record changed the previous day), and monthly (containing every exportable MARC record in Symphony). Hourly and nightly dumps also include a `del` file, containing a catkey-per-line of records that have been deleted or retracted.

Additional data comes from a course reserves data dump, also on the Symphony servers. Course reserves files are pipe `|` separated values (PSV) files which are read in during the indexing process and used to enhance MARC records during the transform process.

The indexing machines have scheduled cron tasks (see `./config/schedule.rb`) that retrieve this data from the Symphony servers and process the data into a kafka topic. Messages in the topic are key-value pairs; the key is the catkey of the record, and the value is either blank (representing a delete) or containing one or more binary MARC records for the catkey. The topics are regularly compacted by Kafka to remove duplicate data.

the sirsi traject config uses the special setting `SKIP_EMPTY_ITEM_DISPLAY`, which tells the indexer to skip or not skip empty item_display fields. anything greater than -1 will skip. tests are set to use `-1` unless otherwise configured.
### SDR
The indexing machines also have scheduled cron tasks for loading data from purl-fetcher into a kafka topic. This task records a state file (in `./tmp`) that contains the timestamp of the most recent entry from purl-fetcher that was processed. Every minute, the cron task runs, retrieves the purl-fetcher changes since that most recent timestamp, and adds the message to a kafka topic.
