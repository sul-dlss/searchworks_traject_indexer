## HT Overlap report (received out of band)
# CREATE TABLE `overlap` (
#   `oclc` varchar(255) DEFAULT NULL,
#   `local_id` INT UNSIGNED NOT NULL,
#   `item_type` varchar(16) DEFAULT NULL,
#   `access` varchar(16) DEFAULT NULL,
#   `rights` varchar(16) DEFAULT NULL,
#   KEY `idx_local_id`  (`local_id`),
#   KEY `idx_oclc_num` (`oclc`)
# ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

# LOAD DATA INFILE '/data/ht/overlap_20200316_stanford.tsv' INTO table hathifiles.overlap FIELDS ESCAPED BY '\b';

## HT HAthifiles dump (from https://www.hathitrust.org/hathifiles)
# CREATE TABLE `hathifiles` (
#  `htid` varchar(64) NOT NULL DEFAULT '',
#  `access` varchar(16) DEFAULT NULL,
#  `rights` varchar(16) DEFAULT NULL,
#  `ht_bib_key` varchar(16) DEFAULT NULL,
#  `description` text,
#  `source` varchar(16) DEFAULT NULL,
#  `source_bib_num` varchar(1023) DEFAULT NULL,
#  `oclc_num` varchar(255) DEFAULT NULL,
#  `isbn` varchar(2047) DEFAULT NULL,
#  `issn` varchar(2047) DEFAULT NULL,
#  `lccn` varchar(2047) DEFAULT NULL,
#  `title` text,
#  `imprint` text,
#  `rights_reason_code` varchar(32) DEFAULT NULL,
#  `rights_timestamp` datetime DEFAULT NULL,
#  `us_gov_doc_flag` varchar(8) DEFAULT NULL,
#  `rights_date_used` varchar(32) DEFAULT NULL,
#  `pub_place` text,
#  `lang` varchar(8) DEFAULT NULL,
#  `bib_fmt` varchar(16) DEFAULT NULL,
#  `collection_code` varchar(16) DEFAULT NULL,
#  `content_provider_code` varchar(32) DEFAULT NULL,
#  `responsible_entity_code` varchar(32) DEFAULT NULL,
#  `digitization_agent_code` varchar(32) DEFAULT NULL,
#  `access_profile_code` varchar(32) DEFAULT NULL,
#  `author` text,
#  PRIMARY KEY (`htid`),
#  KEY `idx_oclc_num` (`oclc_num`),
#  KEY `idx_lccn` (`lccn`(255)),
#  KEY `idx_source` (`source`,`source_bib_num`(255)),
#  KEY `idx_ht_bib_key` (`ht_bib_key`,`htid`)
#) ENGINE=InnoDB DEFAULT CHARSET=utf8; 
# CREATE TABLE  `stdnums` (
#   `htid` varchar(64) NOT NULL,
#   `type` varchar(16) NOT NULL,
#   `value` varchar(1023) NOT NULL,
#   KEY `idx_htid` (`htid`),
#   KEY `idx_type_value` (`type`, `value`, `htid`)
# )
# LOAD DATA INFILE '/data/ht/hathi_full_20200501.txt' INTO table hathifiles.hathifiles FIELDS ESCAPED BY '\b';

db = Sequel.connect(ENV[:hathitrust_lookup_db])


# Transform hathifiles oclc_num column into stdnums table (for ease of joining with the overlap report)
class HT < Sequel::Model(db[:hathifiles].where(Sequel.lit('oclc_num != ""')).select(:htid, :oclc_num)); end

i = 0
HT.each do |row|
  i += 1
  puts i if (i % 1000) == 0
  oclc = row.oclc_num.split(",").map(&:strip).reject(&:empty?)
  db.transaction do
    db.from('stdnums').where(htid: row[:htid]).delete
    db[:stdnums].multi_insert(
      oclc.map do |num|
        { htid: row[:htid], type: 'oclc', value: num }
      end
    )
  end
end
