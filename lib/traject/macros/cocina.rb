# frozen_string_literal: true

module Traject
  module Macros
    # Traject macros for working with data from Cocina models
    module Cocina
      # Call a method on the record and add result(s) to the accumulator
      def cocina_display(method_name, *args, **kwargs)
        lambda do |record, accumulator, _context|
          accumulator.concat Array(record.public_cocina.public_send(method_name, *args, **kwargs))
        end
      end

      # Map accumulator of files to their stacks download URLs
      def stacks_file_url
        lambda do |_record, accumulator, _context|
          accumulator.map!(&:download_url)
        end
      end

      # Generate a Searchworks URL if object is released to Searchworks
      def searchworks_url
        lambda do |record, accumulator, _context|
          accumulator << record.searchworks_url if record.public_meta_json? && record.released_to_searchworks?
        end
      end

      # Generate a IIIF manifest URL, but only if the object can actually be viewed
      # (i.e. it is a content type with images and a useful manifest)
      def iiif_manifest_url
        lambda do |record, accumulator, _context|
          accumulator << record.iiif_manifest_url if %w[image manuscript map book].include?(record.content_type)
        end
      end

      # Transform CocinaDisplay::Contributor objects into hashes for indexing
      def contributor_to_struct
        lambda do |_record, accumulator, _context|
          accumulator.map! do |contributor|
            {
              link: contributor.display_name(with_date: true),
              search: "\"#{contributor.display_name}\"",
              post_text: ("(#{contributor.display_role})" if contributor.role?)
            }.compact
          end
        end
      end

      # Generate structured metadata for tables of contents, similar to MARC 505/905
      # NOTE: currently not adding vernacular/unmatched vernacular; unclear if
      # this even exists in any SDR records as of 2026
      def toc_struct
        lambda do |record, accumulator, _context|
          record.public_cocina.table_of_contents_display_data.each do |tocs|
            accumulator << {
              label: tocs.label,
              fields: tocs.objects.map(&:values)
            }
          end
        end
      end

      # Generate structured metadata for abstract/summary, similar to MARC 520/920
      # NOTE: currently not adding vernacular/unmatched vernacular; unclear if
      # this even exists in any SDR records as of 2026, also not adding source
      def abstract_struct
        lambda do |record, accumulator, _context|
          record.public_cocina.abstract_display_data.each do |abstracts|
            accumulator << {
              label: abstracts.label,
              fields: abstracts.objects.flat_map do |abstract|
                abstract.values.map { |field| { field: [field] } }
              end
            }
          end
        end
      end

      # Based on the object type, generate the appropriate schema.org markup
      def schema_dot_org_struct
        lambda do |record, accumulator, context|
          schema_dot_org_dataset_struct.call(record, accumulator, context) if record.content_type == 'geo'
        end
      end

      # Generate schema.org markup for a dataset using a Cocina record
      def schema_dot_org_dataset_struct
        lambda do |record, accumulator, _context|
          schema_dot_org_json = {
            '@context': 'http://schema.org',
            '@type': 'Dataset',
            citation: record.public_cocina.preferred_citation,
            identifier: [record.public_cocina.purl_url],
            license: record.public_cocina.license,
            name: [record.public_cocina.display_title],
            description: record.public_cocina.abstracts,
            sameAs: "https://searchworks.stanford.edu/view/#{record.druid}",
            keywords: record.public_cocina.subject_all,
            distribution: [
              {
                '@type': 'DataDownload',
                encodingFormat: 'application/zip',
                contentUrl: "https://stacks.stanford.edu/file/druid:#{record.druid}/data.zip"
              }
            ]
          }.compact_blank

          # If released to Earthworks, add a link to Earthworks
          # TODO: if released to Dataworks, add a link to Dataworks
          schema_dot_org_json['includedInDataCatalog'] = {
            '@type': 'DataCatalog',
            name: 'https://earthworks.stanford.edu'
          } if record.released_to_earthworks?

          accumulator << schema_dot_org_json
        end
      end

      # Generate values for the student work facet in Searchworks.
      # It is expected that these values will go to a field analyzed with
      # solr.PathHierarchyTokenizerFactory, so a value like:
      #    "Thesis/Dissertation|Master's|Engineer"
      #  will be indexed as 3 values:
      #    "Thesis/Dissertation|Master's|Engineer"
      #    "Thesis/Dissertation|Master's"
      #    "Thesis/Dissertation"
      def stanford_work_facet
        lambda do |record, accumulator, _context|
          types = record.public_cocina.self_deposit_resource_types.flat_map(&:values)

          # Reports are the simple case
          if types.include? 'Report'
            accumulator << 'Other student work|Student report'

          # For an ETD, we need to look at the collection titles
          elsif types.include? 'Thesis'
            record.collections.each do |c|
              accumulator << case c.label
                             when /phd/i
                               'Thesis/Dissertation|Doctoral|Unspecified'
                             when /master/i
                               'Thesis/Dissertation|Master\'s|Unspecified'
                             when /honor/i
                               'Thesis/Dissertation|Bachelor\'s|Undergraduate honors thesis'
                             when /capstone/i, /undergraduate/i
                               'Thesis/Dissertation|Bachelor\'s|Unspecified'
                             else
                               'Thesis/Dissertation|Unspecified'
                             end
            end
          end
        end
      end

      # Get all files from cocina structural whose filename matches the pattern
      # Filters the accumulator if it is not empty; otherwise search all files
      def select_files(pattern)
        lambda do |record, accumulator, _context|
          accumulator.concat record.files if accumulator.empty?
          accumulator.select! { |file| file.filename.match?(pattern) }
        end
      end

      # Find the first file in cocina structural whose filename matches the pattern
      # Filters the accumulator if it is not empty; otherwise search all files
      def find_file(pattern)
        lambda do |record, accumulator, context|
          select_files(pattern).call(record, accumulator, context)
          accumulator.replace(accumulator.first(1))
        end
      end
    end
  end
end
