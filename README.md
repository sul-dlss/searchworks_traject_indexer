# SearchworksTrajectIndexer
[![CI status](https://github.com/sul-dlss/searchworks_traject_indexer/actions/workflows/ruby.yml/badge.svg)](https://github.com/sul-dlss/searchworks_traject_indexer/actions/workflows/ruby.yml)
[![Current release](https://img.shields.io/github/v/release/sul-dlss/searchworks_traject_indexer)](https://github.com/sul-dlss/searchwork_traject_indexer/releases)
![tested on ruby 3.2](https://img.shields.io/badge/ruby-v3.2-red)

indexing MARC, MODS, and more for [SearchWorks](https://github.com/sul-dlss/SearchWorks).
<img src="preview.png" alt="solr index fields displayed overlaid on SearchWorks catalog preview for a book">

## local development
searchworks_traject_indexer is built on the [traject](https://github.com/traject/traject) transformation library, which requires ruby. we test the application using ruby 3.2; support for other versions is not guaranteed.

after cloning the repository, install dependencies:
```sh
bundle install
```
then, you can test out indexing against a local solr index:
```sh
SOLR_URL=http://localhost:8983/solr/core-name bundle exec traject -c lib/traject/config/folio_config.rb my_marc_file.marc
```
the above command will index the file `my_marc_file.marc` into the solr core `core-name` using the configuration for FOLIO (`folio_config.rb`). after the command completes, you can check the solr web interface to see what was indexed.

for assistance creating and managing a local solr instance for development, see [solr_wrapper](https://github.com/cbeer/solr_wrapper). for more on indexing, see "indexing data" below.

## testing
you can run the full test suite with:
```sh
bundle exec rake
```
note that some integration tests may hit a live server, for which you may need to be on the Stanford VPN.

## Monitor logs
```
ksu
journalctl -u traject-marc_bodoni_dev_indexer.1.service -e
```

## indexing data
indexing is a multi-step process:
1. an extractor process publishes data to be indexed to a [kafka](https://kafka.apache.org/) topic
2. Systemd runs the various traject services
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
the daemon processes are managed by systemd.

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
      start_command: '/usr/local/rvm/bin/rvm jruby-9.3.2.0 do bundle exec honeybadger exec traject -c ./lib/traject/config/marc_config.rb -s solr_writer.max_skipped=-1 -s log.level=debug -s log.file=log/traject_marc_bodoni_prod_indexer.log'
```

You can use `sudo systemctl list-dependencies traject.target` to view status information:
```
● ├─traject-earthworks_stage_indexer.1.service
● ├─traject-folio_dev_indexer.1.service
● ├─traject-folio_dev_indexer.2.service
● ├─traject-folio_dev_indexer.3.service
● ├─traject-folio_dev_indexer.4.service
● ├─traject-folio_dev_indexer.5.service
● ├─traject-folio_dev_indexer.6.service
● ├─traject-folio_dev_indexer.7.service
● ├─traject-folio_dev_indexer.8.service
● ├─traject-marc_bodoni_dev_indexer.1.service
● ├─traject-marc_morison_dev_indexer.1.service
● ├─traject-sw_dev_indexer.1.service
● ├─traject-sw_dev_indexer.2.service
● ├─traject-sw_preview_stage_indexer.1.service
● └─traject-sw_preview_stage_indexer.2.service
```

Then look at the logs of any service by doing:
```
ksu
journalctl -u traject-marc_bodoni_dev_indexer.1.service -e
```


### indexing the data into solr
traject configurations specific to each target environment are responsible for transforming the data into a format that can be indexed into solr. you can view the configuration files in `lib/traject/config/`, which often include traject commands like:
```ruby
to_field 'pub_country', extract_marc('008')
```
which extracts information from the 008 field of a MARC record and puts it into the `pub_country` field of the solr document.

each traject configuration specifies a reader class located in `lib/traject/readers/` that can read the data from the kafka topic and hand it off to be transformed into solr JSON.

other configuration values, like the URL of the solr instance, are usually set at the top of the configuration file using traject's `provide`. many can be set by environment variables

```yaml
processes:
  - name: my_indexer
    env:
      SOLR_URL: http://sul-solr.stanford.edu/solr/searchworks-prod # controls where traject indexes to
```
in local development, you can invoke traject on the command line and override these settings by passing environment variables:
```sh
bundle exec traject -c lib/traject/config/config_name.rb --debug-mode input_file
```
the `--debug-mode` flag will print out the solr document that traject generates, along with extra debugging information. You can read [more about the traject command line](https://github.com/traject/traject?tab=readme-ov-file#the-traject-command-line) in the traject documentation.

#### FOLIO data

when working with non-MARC data held locally (e.g. JSON exports from FOLIO), you can use the `FolioJsonReader` to pipe output into traject from stdin. Note that `FolioJsonReader` must handle newline-delimited JSON (not prettified).
```sh
cat record.json | bundle exec traject -c lib/traject/config/folio_config.rb -s reader_class_name=Traject::FolioJsonReader --stdin --debug-mode
```
note that this approach doesn't use the `FolioClient` to make API calls, so the burden is on the user to create a fully-formed `FolioRecord` prior to indexing.

another option is to use the `JsonWriter`, so you can see exactly what traject is indexing. an example that strips honeybadger output and uses the `jq` utility to inspect a particular field in the json:
```sh
cat record.json | bundle exec traject -c lib/traject/config/folio_config.rb -s reader_class_name=Traject::FolioJsonReader -w Traject::JsonWriter --stdin | tail -n +2 | jq '.pub_country'
```

#### SDR data

To test indexing a single SDR object at a time, you can `echo` its druid and use the `--stdin` flag:
```sh
echo 'abc123def4567' | bundle exec traject -c lib/traject/config/sdr_config.rb --stdin --debug-mode
```

For SDR object released to Earthworks, you can pass the appropriate configuration file:
```sh
echo 'druid' | bundle exec traject -c lib/traject/config/geo_aardvark_config.rb --debug-mode
```

It's also possible to index a group of druids, mimicking the process from SDR.
```sh
bundle exec traject -c lib/traject/config/sdr_config.rb --debug-mode druidslist.txt
```
You can create a `druidslist.txt` file containing a list of newline delimited druids.

### Data sources 
The indexing machines have scheduled cron tasks (see `./config/schedule.rb`) that retrieve this data from the FOLIO servers and process the data into a kafka topic. Messages in the topic are key-value pairs; the key is the catkey of the record, and the value is either blank (representing a delete) or containing one or more records for the catkey. The topics are regularly compacted by Kafka to remove duplicate data.

This traject config uses the special setting `SKIP_EMPTY_ITEM_DISPLAY`, which tells the indexer to skip or not skip empty item_display fields. anything greater than -1 will skip. tests are set to use `-1` unless otherwise configured.

## Environments

### SDR
The indexing machines also have processes for loading data from the `purl_fetcher_(stage/prod)` kafka topic.

#### Reporting events
Indexers for SDR content can report the status of indexing events to [dor-services-app](https://github.com/sul-dlss/dor-services-app) using the [dor-event-client](https://github.com/sul-dlss/dor-event-client) gem. When the feature is enabled and configured in `settings.yml` or via environment variables, the indexer will create events for each record that is indexed, skipped, deleted, etc. These events are visible in the Argo UI and can be used to troubleshoot items released from SDR that are not appearing in search indices.


### FOLIO
Our catalog data comes from queries to the FOLIO postgres database.
Course reserve information is retrieved from FOLIO and associated with items and holdings for retrieval in the indexing process.

Data is read directly from the postgres database underlying FOLIO using a custom SQL query stored in the `FolioPostgresReader`. To mimic this activity in local development, one can SSH tunnel to the FOLIO database and use the `#find_by_catkey` helper method:
```rb
# after SSH tunneling to the FOLIO database
bin/console
Traject::FolioPostgresReader.find_by_catkey('a123456, 'postgres.url' => 'postgres://[user]:[password]@localhost/okapi')
```
There is also a helper script for fetching single records at a time. You need to set the `DATABASE_URL` environment variable:
```sh
export DATABASE_URL=postgres://[user]:[password]@localhost/okapi
```
...and then run the script with a catkey as an argument, optionally redirecting the output to a file:
```sh
./script/download_folio_record.rb a123456 > record.json
```

#### Synching data
##### Libraries
If the name of a library in Folio has changed, you'll want to export the list of libraries with their labels and check it in here.  You can do this with the Rake command

```shell
OKAPI_URL="URL_HERE" bin/rake folio:update_types_cache
```

Then you'll want to reindex everything so as to avoid libaries who's labels have changed from showing both versions of the label in the `building_facet` in Searchworks.
