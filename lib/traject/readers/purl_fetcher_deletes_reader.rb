class Traject::PurlFetcherDeletesReader < Traject::PurlFetcherReader
  def each
    return to_enum(:each) unless block_given?

    deletes(first_modified: first_modified).each do |change|
      yield PublicXmlRecord.new(change['druid'].sub('druid:', ''))
    end

    changes(first_modified: first_modified, target: target).each do |change|
      next unless change['false_targets'] && change['false_targets'].include?(target)

      yield PublicXmlRecord.new(change['druid'].sub('druid:', ''))
    end
  end
end
