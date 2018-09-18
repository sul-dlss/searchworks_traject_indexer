class Traject::PurlFetcherDeletesReader < Traject::PurlFetcherReader
  # Enumerate objects that should be deleted.
  def each
    return to_enum(:each) unless block_given?

    deletes(first_modified: first_modified).each do |change|
      yield PublicXmlRecord.new(change['druid'].sub('druid:', ''))
    end

    changes(first_modified: first_modified, target: target).each do |change|
      record = PublicXmlRecord.new(change['druid'].sub('druid:', ''))

      next unless target.nil? || (change['false_targets'] && change['false_targets'].include?(target)) || (settings['skip_if_catkey'] == 'true' && record.catkey)

      yield record
    end
  end
end
