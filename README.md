# SearchworksTrajectIndexer

[![CI status](https://github.com/sul-dlss/searchworks_traject_indexer/actions/workflows/ruby.yml/badge.svg)](https://github.com/sul-dlss/searchworks_traject_indexer/actions/workflows/ruby.yml)

Metadata indexing for [Searchworks](https://github.com/sul-dlss/SearchWorks) and [Earthworks](https://github.com/sul-dlss/earthworks), built using [traject](https://github.com/traject/traject).

## Developing

For the currently supported Ruby version, see the `.github/workflows/ruby.yml` file.

After cloning the repository, install dependencies:

```sh
bundle install
```

To invoke an indexer in development, you can use the `traject` command line tool:

```sh
bundle exec traject --help
```

You will either need to have a local [Solr](https://solr.apache.org/) instance running as the indexer target or use the `--debug-mode` flag to print output to the console instead. A simple way to run a local Solr instance is to use [solr_wrapper](https://github.com/cbeer/solr_wrapper).

The configuration file for each indexer is located in `lib/traject/config/` and passed to traject via the `--conf` argument. These files generally preselect a reader class that can process incoming data and include a series of traject macros for processing the data into Solr-ready JSON.

For local indexing techniques appropriate to each data source and platform target, see the [indexing locally](#indexing-locally) section.

## Testing

You can run the full test suite with:

```sh
bundle exec rake
```

## Architecture

Indexing is a multi-step process:

1. A message with an item identifier is published to a [Kafka](https://kafka.apache.org/) topic
2. A daemon process reads the message from the topic and processes it using a traject configuration
3. Traject transforms the data into a Solr-ready JSON document and sends it to a Solr instance

### Publishing messages

#### SDR content

For objects in SDR, this process is handled by [purl-fetcher](https://github.com/sul-dlss/purl-fetcher), which publishes a message to Kafka including the item's druid when an item is published (e.g. via [Argo](https://github.com/sul-dlss/argo)).

The unique key of the message will be the object's druid. The druid is used to fetch the item's metadata from [Purl](https://github.com/sul-dlss/purl) at index time and transform it into a Solr document.

#### FOLIO records

For records in FOLIO, this process is handled by a [ruby script](script/process_folio_postgres_to_kafka.rb) that queries FOLIO's underlying postgres database for changed records and publishes messages to Kafka with JSON metadata records at regular intervals. The script is called from shell scripts in `script/` that are run on a schedule by `cron` jobs managed using the `whenever` gem.

The unique key of the message will be the item's catkey. The message will also include the item's metadata in JSON format, which is generated using [a complex SQL query](lib/traject/readers/folio_postgres_reader.rb) that joins multiple tables in FOLIO's database. This JSON is then further transformed into a Solr document.

### Consuming messages

On the indexing machines, daemon processes are managed by [systemd](https://systemd.io/). Each daemon process is configured via variables set in `config/deploy/[ENVIRONMENT].yml`, which will be read during a capistrano deploy and used to generate a systemd service file (as part of `config/deploy.rb`).

Once a service is registered with systemd during a deploy, it can be started, stopped, and monitored using the `systemctl` and `journalctl` commands. Many processes are also parallelized using the `count` variable, which can be set in the deploy configuration.

### Indexing data

Traject configurations are located in `lib/traject/config/` and are responsible for transforming the data into a format that can be indexed into Solr. Each configuration specifies a reader class located in `lib/traject/readers/` that can read incoming data and hand it off to be transformed into Solr JSON.

The configuration file uses several special methods or "macros" provided by traject. At the top of the file, the `provide` macro is used to set defaults for common variables used by the indexer, like the URL of the Solr instance. Many of these can be overridden by environment variables.

The bulk of the file is usually taken up by a series of `to_field` macros, which specify how to transform the incoming data into Solr fields. These methods transform the incoming data into a Solr-ready JSON document, one field at a time.

## Indexing locally

Local indexing can be done using the `traject` command line tool. These commands assume you have a solr instance running locally, for example, at `http://localhost:8983/solr/blacklight-core`. You can set the `SOLR_URL` environment variable or pass the `--solr` flag to traject to point at your core.

Alternatively, you can use the `--debug-mode` flag to print output to the console using the built-in `DebugWriter`. It can occasionally be useful to use the `Traject::JsonWriter` to see the literal JSON output instead. You can do this by passing `--writer Traject::JsonWriter`.

### FOLIO

Data is read directly from the postgres database underlying FOLIO using a custom SQL query stored in the `FolioPostgresReader`. Course reserve information is retrieved from FOLIO and associated with items and holdings for retrieval in the indexing process.

In order to get some content to index locally, you will need to establish a connection to the database via a machine with authorization to do so, and then construct and download a JSON file.

You can establish an SSH tunnel to the FOLIO database using the following command:

```sh
ssh -L 5432:[folio-database-hostname].stanford.edu:9999 indexer@[indexer-hostname]
```

Then, on your local machine, you can use a helper script for fetching single records at a time. You need to set the `DATABASE_URL` environment variable:

```sh
export DATABASE_URL=postgres://[user]:[password]@localhost/okapi
```

...and then run the script with a catkey as an argument, optionally redirecting the output to a file:

```sh
./script/download_folio_record.rb a123456 > records.json
```

Once you have exported records, you can use the `FolioJsonReader` to pipe them into traject from stdin. Note that `FolioJsonReader` must handle newline-delimited JSON (not prettified). Each line is expected to be a single JSON record.

```sh
cat records.json | bundle exec traject --conf lib/traject/config/folio_config.rb -s reader_class_name=Traject::FolioJsonReader --stdin
```

### SDR

Data coming from SDR has two different processing pipelines: if the data is released to Searchworks, it will be processed by the `sdr_config` traject configuration, and if it is released to Earthworks, it will be processed by the `geo_aardvark_config` traject configuration.

To test indexing a single SDR object at a time, you can `echo` its druid and use the `--stdin` flag:

```sh
echo 'abc123def4567' | bundle exec traject --conf lib/traject/config/sdr_config.rb --stdin
```

For SDR object released to Earthworks, you can pass the appropriate configuration file:

```sh
echo 'abc123def4567' | bundle exec traject --conf lib/traject/config/geo_aardvark_config.rb --stdin
```

It's also possible to index a group of druids, mimicking the process from SDR.

```sh
bundle exec traject --conf lib/traject/config/sdr_config.rb druidslist.txt
```

You can create a `druidslist.txt` file containing a list of newline delimited druids.

## Troubleshooting

### Indexer processes

The indexer processes are managed by systemd. You can use `systemctl --user list-dependencies traject.target` to view the full list of processes:

```
traject.target
● ├─traject-earthworks_prod_indexer.target
● │ └─traject-earthworks_prod_indexer.1.service
● ├─traject-folio_prod_indexer.target
● │ ├─traject-folio_prod_indexer.1.service
● │ ├─traject-folio_prod_indexer.2.service
● │ ├─traject-folio_prod_indexer.3.service
● │ ├─traject-folio_prod_indexer.4.service
● │ ├─traject-folio_prod_indexer.5.service
● │ ├─traject-folio_prod_indexer.6.service
● │ ├─traject-folio_prod_indexer.7.service
● │ └─traject-folio_prod_indexer.8.service
```

To get the status of a particular process, use e.g. `systemctl --user status traject-sdr_prod_indexer.target`:

```
● traject-sdr_prod_indexer.target
     Loaded: loaded (/opt/app/indexer/.config/systemd/user/traject-sdr_prod_indexer.target; static; vendor preset: enabled)
     Active: active since Mon 2024-09-09 08:08:58 PDT; 5h 14min ago
```

You can use commands like `start`, `stop`, `restart`, and `status` to manage the process. For more options, see `man systemctl`.

### Logs

Each indexer process writes to a log file in `/opt/app/indexer/searchworks_traject_indexer/current/log` that can be viewed directly. Extractor processes that publish data to kafka also write logs here.

If systemd is unable to start a process or a processes exits with an error status, you can view the logs to see what went wrong using `journalctl`. **You need to become root with `ksu` first in order to use `journalctl`**.

To get all of today's logs for all of the processes belonging to the `indexer` user (id 503), with latest first:

```
journalctl _UID=503 --since today --reverse
```

For more options, see `man journalctl`.

### SDR events

Indexers for SDR content can report the status of indexing events to [dor-services-app](https://github.com/sul-dlss/dor-services-app) using the [dor-event-client](https://github.com/sul-dlss/dor-event-client) gem. When the feature is enabled and configured in `settings.yml` or via environment variables, the indexer will create events for each record that is indexed, skipped, deleted, etc.

These events are visible in the Argo UI and can be used to troubleshoot items released from SDR that are not appearing in search indices. Open the "events" accordion on the item's page to view the events, e.g. `indexing_success`:

```json
{
  "host": "sw-indexing-stage-a.stanford.edu",
  "target": "SearchWorksPreview",
  "invoked_by": "indexer"
}
```

### Kafka

When debugging, it can be helpful to manage the messages in Kafka queues directly. In an `ssh` session on the Kafka machine (see shared_configs or puppet to find the url), you can find utilities for managing Kafka queues in `/opt/kafka/bin/`.

You can, for example, list all configured consumer groups and topics:

```sh
/opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --all-groups --all-topics
```

Another useful operation is resetting the messages published in a particular topic, which will "rewind" and "replay" each message, effectively reindexing all data: 

```sh
/opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group traject_folio_dev --topic marc_folio_test --reset-offsets --to-earliest
```

Note that you must first stop the associated indexer process in order to reset the offsets; after the reset is complete you can restart the indexer in order to start receiving messages from the beginning.

Some operations (including resetting offests) will "plan" execution by default, and only actually execute using the `--execute` flag. for more, try passing `--help`.

### Data sync

If the name of a library in FOLIO has changed, you'll want to export the list of libraries with their labels and check it in here. You can do this with the Rake command:

```sh
OKAPI_URL="URL_HERE" bin/rake folio:update_types_cache
```

Then you'll want to reindex everything so as to avoid libraries whose labels have changed from showing both versions of the label in the `building_facet` in Searchworks.
