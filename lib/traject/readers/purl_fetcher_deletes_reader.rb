class Traject::PurlFetcherDeletesReader < Traject::PurlFetcherReader
  # Enumerate objects that should be deleted.
  def each
    return to_enum(:each) unless block_given?

    deletes(first_modified: first_modified).each do |change|
      yield PublicXmlRecord.new(change['druid'].sub('druid:', ''))
    end

    changes(first_modified: first_modified, target: target).each do |change|
      record = PublicXmlRecord.new(change['druid'].sub('druid:', ''))

      yield record if should_be_deleted?(change, record)
    end
  end

  private

  def should_be_deleted?(change, record)
    # Remove records that have the target explicitly set to false
    return true if target && change['false_targets'] && change['false_targets'].map(&:upcase).include?(target.upcase)
    # Remove changed records that now have a catkey
    return true if settings['skip_if_catkey'] == 'true' && record.catkey
    # Remove withdrawn records that are missing public xml
    return true if !record.public_xml?

    false
  end
end
