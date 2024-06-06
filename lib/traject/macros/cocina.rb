# frozen_string_literal: true

module Traject
  module Macros
    module Cocina
      def druid
        lambda do |record, accumulator, _context|
          accumulator << record.druid
        end
      end

      def modified
        lambda do |record, accumulator, _context|
          accumulator << record.modified
        end
      end

      def created
        lambda do |record, accumulator, _context|
          accumulator << record.created
        end
      end

      def purl_url
        lambda do |record, accumulator, _context|
          accumulator << "#{settings['purl.url']}/#{record.druid}"
        end
      end

      def embed_url(params = {})
        lambda do |record, accumulator, context|
          return if record.content_type == 'collection'

          params[:url] = purl_url.call(record, [], context)
          accumulator << "#{settings['purl.url']}/embed.json?#{params.to_query}"
        end
      end

      def stacks_object_url
        lambda do |record, accumulator, _context|
          accumulator << "#{settings['stacks.url']}/object/druid:#{record.druid}"
        end
      end

      def stacks_file_url
        lambda do |record, accumulator, _context|
          accumulator.map! do |file|
            "#{settings['stacks.url']}/file/druid:#{record.druid}/#{file.filename}"
          end
        end
      end

      def iiif_manifest_url(version: 3)
        lambda do |record, accumulator, _context|
          return unless %w[image map book].include? record.content_type

          accumulator << if version == 3
                           "#{settings['purl.url']}/#{record.druid}/iiif3/manifest"
                         else
                           "#{settings['purl.url']}/#{record.druid}/iiif/manifest"
                         end
        end
      end

      def cocina_descriptive(*fields)
        lambda do |record, accumulator, _context|
          accumulator.concat(fields.reduce([record.cocina_description]) do |nodes, field|
            nodes.flat_map { |node| node.public_send(field) }.compact
          end)
        end
      end

      def cocina_structural(*fields)
        lambda do |record, accumulator, _context|
          accumulator.concat(fields.reduce([record.cocina_structural]) do |nodes, field|
            nodes.flat_map { |node| node.public_send(field) }.compact
          end)
        end
      end

      def cocina_access(*fields)
        lambda do |record, accumulator, _context|
          accumulator.concat(fields.reduce([record.cocina_access]) do |nodes, field|
            nodes.flat_map { |node| node.public_send(field) }.compact
          end)
        end
      end

      def cocina_titles(type: :main)
        lambda do |record, accumulator, _context|
          accumulator.concat record.cocina_titles(type:)
        end
      end

      def select_type(type)
        lambda do |_record, accumulator, _context|
          accumulator.map! { |node| node if node.type == type }.compact!
        end
      end

      def select_role(role)
        lambda do |_record, accumulator, _context|
          accumulator.map! { |node| node if node.role.find { |r| r.value == role } }.compact!
        end
      end

      def extract_dates
        lambda do |_record, accumulator, _context|
          accumulator.map!(&:date).flatten!.compact! if accumulator.any?
        end
      end

      def extract_values
        lambda do |_record, accumulator, _context|
          accumulator.map!(&:value).compact!
        end
      end

      def parse_dates
        lambda do |_record, accumulator, _context|
          accumulator.map! do |dt|
            Time.parse(dt)
          rescue ArgumentError
            nil
          end.compact!
        end
      end

      def extract_structured_values(flatten: false)
        lambda do |_record, accumulator, _context|
          accumulator.map! { |node| node.structuredValue.map(&:value) }
          accumulator.flatten! if flatten && accumulator.any?
          accumulator.compact!
        end
      end

      def extract_names
        lambda do |_record, accumulator, _context|
          accumulator.map! { |node| node.name.map(&:value) }.flatten!.compact! unless accumulator.empty?
        end
      end

      def select_files(pattern)
        lambda do |record, accumulator, _context|
          accumulator.concat record.files if accumulator.empty?
          accumulator.select! { |file| file.filename.match?(pattern) }
        end
      end

      def find_file(pattern)
        lambda do |record, accumulator, context|
          select_files(pattern).call(record, accumulator, context)
          accumulator.replace(accumulator.first(1))
        end
      end

      def keep_if(&block)
        lambda do |record, accumulator, context|
          accumulator.select! { |value| block.call(record, value, context) }
        end
      end
    end
  end
end
