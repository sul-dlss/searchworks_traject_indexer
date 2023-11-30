# frozen_string_literal: true

require 'time'

module Traject
  class FolioPostgresReader # rubocop:disable  Metrics/ClassLength
    include Enumerable
    attr_reader :settings, :last_response_date

    def initialize(_input_stream, settings)
      @settings = Traject::Indexer::Settings.new settings
      @connection = @settings['postgres.client'] || PG.connect(@settings['postgres.url'])
      @page_size = @settings['postgres.page_size'] || 100
      @updated_after = @settings['folio.updated_after']
      @statement_timeout = @settings.fetch('statement_timeout', 'DEFAULT') # Timeout value in milliseconds

      @sql_filters = [@settings['postgres.sql_filters']].flatten.compact
      @addl_from = @settings['postgres.addl_from']
    end

    # Return a single record by catkey by temporarily applying a SQL filter
    def self.find_by_catkey(catkey, settings = {})
      new(nil, settings.merge!('postgres.sql_filters' => "lower(sul_mod_inventory_storage.f_unaccent(vi.jsonb ->> 'hrid'::text)) = '#{catkey.downcase}'")).first
    end

    def queries
      if @updated_after
        cr_filter = 'LEFT JOIN sul_mod_inventory_storage.holdings_record hr_filter ON hr_filter.instanceid = vi.id
                     LEFT JOIN sul_mod_inventory_storage.item item_filter ON item_filter.holdingsrecordid = hr_filter.id
                     LEFT JOIN sul_mod_courses.coursereserves_reserves cr_filter ON (cr_filter.jsonb ->> \'itemId\')::uuid = item_filter.id'
        filter_join = {
          'hr_filter' => 'LEFT JOIN sul_mod_inventory_storage.holdings_record hr_filter ON hr_filter.instanceid = vi.id',
          'item_filter' => 'LEFT JOIN sul_mod_inventory_storage.holdings_record hr_filter ON hr_filter.instanceid = vi.id LEFT JOIN sul_mod_inventory_storage.item item_filter ON item_filter.holdingsrecordid = hr_filter.id',
          'cr_filter' => cr_filter,
          'cl_filter' => "#{cr_filter} LEFT JOIN sul_mod_courses.coursereserves_courselistings cl_filter ON cl_filter.id = cr_filter.courselistingid",
          'cc_filter' => "#{cr_filter} LEFT JOIN sul_mod_courses.coursereserves_courselistings cl_filter ON cl_filter.id = cr_filter.courselistingid
                                       LEFT JOIN sul_mod_courses.coursereserves_courses cc_filter ON cc_filter.courselistingid = cl_filter.id",
          'rs_filter' => 'LEFT JOIN sul_mod_source_record_storage.records_lb rs_filter ON rs_filter.external_id = vi.id'
        }

        conditions = %w[vi hr_filter item_filter cr_filter cl_filter cc_filter].map do |table|
          c = "sul_mod_inventory_storage.strtotimestamp((#{table}.jsonb -> 'metadata'::text) ->> 'updatedDate'::text) > '#{@updated_after}'"
          sql_query([c] + @sql_filters, addl_from: [filter_join[table], @addl_from].compact.join("\n"))
        end + [sql_query(["rs_filter.updated_date > '#{@updated_after}'"] + @sql_filters, addl_from: filter_join['rs_filter'])]

        conditions.join(') UNION (')
      else
        sql_query(@sql_filters, addl_from: @addl_from)
      end
    end

    # This gets the UUID of the "Database" statistical code. This is the only statistical code we care about.
    def statical_code_database
      @statical_code_database ||= begin
        response = @connection.exec("SELECT id FROM sul_mod_inventory_storage.statistical_code WHERE lower(sul_mod_inventory_storage.f_unaccent(jsonb ->> 'name'::text)) = 'database';")
        response.map { |row| row['id'] }.first
      end
    end

    def locations
      @locations ||= begin
        response = @connection.exec <<-SQL
          SELECT loc.id AS id,
                jsonb_build_object(
                  'id', loc.id,
                  'name', COALESCE(loc.jsonb ->> 'discoveryDisplayName', loc.jsonb ->> 'name'),
                  'isActive', COALESCE((loc.jsonb ->> 'isActive')::bool, false),
                  'code', loc.jsonb ->> 'code',
                  'details', loc.jsonb -> 'details',
                  'campus', jsonb_build_object('id', locCamp.id, 'name', COALESCE(locCamp.jsonb ->> 'discoveryDisplayName', locCamp.jsonb ->> 'name'), 'code', locCamp.jsonb ->> 'code'),
                  'library',jsonb_build_object('id', locLib.id, 'name', COALESCE(locLib.jsonb ->> 'discoveryDisplayName', locLib.jsonb ->> 'name'), 'code', locLib.jsonb ->> 'code'),
                  'institution', jsonb_build_object('id', locInst.id, 'name', COALESCE(locInst.jsonb ->> 'discoveryDisplayName', locInst.jsonb ->> 'name'), 'code', locInst.jsonb ->> 'code')
                ) AS jsonb
          FROM sul_mod_inventory_storage.location loc
            LEFT JOIN sul_mod_inventory_storage.locinstitution locInst
                  ON loc.institutionid = locInst.id
            LEFT JOIN sul_mod_inventory_storage.loccampus locCamp
                  ON loc.campusid = locCamp.id
            LEFT JOIN sul_mod_inventory_storage.loclibrary locLib
                  ON loc.libraryid = locLib.id
        SQL

        response.map { |row| JSON.parse(row['jsonb']) }.index_by { |loc| loc['id'] }
      end
    end

    def service_points
      @service_points ||= begin
        response = @connection.exec <<-SQL
          SELECT service_point.id AS id,
                jsonb_build_object(
                  'id', service_point.id,
                  'code', service_point.jsonb ->> 'code',
                  'name', service_point.jsonb ->> 'name',
                  'pickupLocation', COALESCE((service_point.jsonb ->> 'pickupLocation')::bool, false),
                  'discoveryDisplayName', service_point.jsonb ->> 'discoveryDisplayName'
                ) AS jsonb
          FROM sul_mod_inventory_storage.service_point service_point
        SQL

        response.map { |row| JSON.parse(row['jsonb']) }.index_by { |service_point| service_point['id'] }
      end
    end

    def each
      return to_enum(:each) unless block_given?

      @connection.transaction do
        # check postgres's clock time
        @last_response_date = last_response_date

        # These settings seem to hint postgres to a better query plan
        @connection.exec('SET join_collapse_limit = 64')
        @connection.exec('SET from_collapse_limit = 64')
        @connection.exec("SET statement_timeout = #{@statement_timeout}")

        # declare a cursor
        @connection.exec("DECLARE folio CURSOR FOR (#{queries})")

        # execute our query
        loop do
          response = @connection.exec("FETCH FORWARD #{@page_size} IN folio")
          break if response.entries.empty?

          response.each do |row|
            data = JSON.parse(row['jsonb_build_object'])

            data['items'].each do |item|
              item['location'] = {
                'effectiveLocation' => locations[item['effectiveLocationId']],
                'permanentLocation' => locations[item['permanentLocationId']],
                'temporaryLocation' => locations[item['temporaryLocationId']]
              }.compact

              item['request']['pickupServicePoint'] = service_points[item['request']['pickupServicePointId']] if item['request']

              item['courses'].each do |course|
                course['locationCode'] = locations.dig(course['locationId'], 'code')
              end
            end

            data['holdings'].each do |holding|
              holding['location'] = {
                'effectiveLocation' => locations[holding['effectiveLocationId']],
                'permanentLocation' => locations[holding['permanentLocationId']],
                'temporaryLocation' => locations[holding['temporaryLocationId']]
              }.compact

              holding['boundWith']['holding']['location'] = {
                'effectiveLocation' => locations[holding['boundWith']['holding']['effectiveLocationId']]
              } if holding.dig('boundWith', 'holding', 'effectiveLocationId')
            end

            yield FolioRecord.new(data)
          end
        end

        # close the cursor; should happen automatically at the end of the transaction
        # but just in case we keep the reader around...
        @connection.exec('CLOSE folio')
      end
    end

    def last_response_date
      Time.parse(@connection.exec('SELECT NOW()').getvalue(0, 0))
    end

    def sql_query(conditions, addl_from: nil)
      <<-SQL
      SELECT
        vi.id,
          jsonb_build_object(
            'instance',
              vi.jsonb || jsonb_build_object(
                'suppressFromDiscovery', COALESCE((vi.jsonb ->> 'discoverySuppress')::bool, false),
                'electronicAccess', COALESCE(sul_mod_inventory_storage.getElectronicAccessName(COALESCE(vi.jsonb #> '{electronicAccess}', '[]'::jsonb)), '[]'::jsonb),
                'statisticalCodes', CASE WHEN '#{statical_code_database}' = ANY(ARRAY(SELECT jsonb_array_elements_text(vi.jsonb->'statisticalCodeIds'))) THEN
                                        jsonb_build_array(
                                          jsonb_build_object(
                                              'id', '#{statical_code_database}',
                                              'name', 'Database'
                                          )
                                        )
                                    ELSE
                                       '[]'::jsonb
                                    END,
                'administrativeNotes', '[]'::jsonb,
                'notes', COALESCE((SELECT jsonb_agg(e) FROM jsonb_array_elements(vi.jsonb -> 'notes') AS e WHERE NOT COALESCE((e ->> 'staffOnly')::bool, false)), '[]'::jsonb)

              ),
            'source_record', COALESCE(jsonb_agg(DISTINCT mr."content"), '[]'::jsonb),
            'items',
              COALESCE(
                jsonb_agg(
                  DISTINCT item.jsonb || jsonb_build_object(
                    'suppressFromDiscovery',
                    CASE WHEN item.id IS NOT NULL THEN
                      COALESCE((vi.jsonb ->> 'discoverySuppress')::bool, false) OR
                      COALESCE((hr.jsonb ->> 'discoverySuppress')::bool, false) OR
                      COALESCE((item.jsonb ->> 'discoverySuppress')::bool, false)
                    ELSE NULL END::bool,
                    'callNumberType', cnt.jsonb - 'metadata',
                    'itemDamagedStatus', itemDmgStat.jsonb ->> 'name',
                    'materialType', mt.jsonb ->> 'name',
                    'permanentLoanType', plt.jsonb ->> 'name',
                    'temporaryLoanType', tlt.jsonb ->> 'name',
                    'status', item.jsonb #>> '{status, name}',
                    'callNumber', item.jsonb -> 'effectiveCallNumberComponents' ||
                                  jsonb_build_object('typeName', cnt.jsonb ->> 'name'),
                    'electronicAccess', COALESCE(sul_mod_inventory_storage.getElectronicAccessName(COALESCE(item.jsonb #> '{electronicAccess}', '[]'::jsonb)), '[]'::jsonb),
                    'administrativeNotes', '[]'::jsonb,
                    'circulationNotes', COALESCE((SELECT jsonb_agg(e) FROM jsonb_array_elements(item.jsonb -> 'circulationNotes') AS e WHERE NOT COALESCE((e ->> 'staffOnly')::bool, false)), '[]'::jsonb),
                    'notes', COALESCE((SELECT jsonb_agg(e || jsonb_build_object('itemNoteTypeName', ( SELECT jsonb ->> 'name' FROM sul_mod_inventory_storage.item_note_type WHERE id = nullif(e ->> 'itemNoteTypeId','')::uuid ))) FROM jsonb_array_elements(item.jsonb -> 'notes') AS e WHERE NOT COALESCE((e ->> 'staffOnly')::bool, false)), '[]'::jsonb),
                    'request', CASE WHEN request.id IS NOT NULL THEN
                      jsonb_build_object(
                        'id', request.id,
                        'status', request.jsonb ->> 'status',
                        'pickupServicePointId', request.jsonb ->> 'pickupServicePointId'
                      )
                    END,
                    'courses', COALESCE(
                      (SELECT
                        jsonb_agg(
                          jsonb_build_object(
                            'id', cc.id,
                            'name', cc.jsonb ->> 'name',
                            'locationId', cl.jsonb ->> 'locationId',
                            'courseNumber', cc.jsonb ->> 'courseNumber',
                            'instructorNames', (SELECT jsonb_agg(instructor ->> 'name') FROM jsonb_array_elements(cl.jsonb #> '{instructorObjects}') AS instructor)
                          )
                        )
                      FROM sul_mod_courses.coursereserves_reserves cr
                        LEFT JOIN sul_mod_courses.coursereserves_courselistings cl ON cl.id = cr.courselistingid
                        LEFT JOIN sul_mod_courses.coursereserves_courses cc ON cc.courselistingid = cl.id
                      WHERE (cr.jsonb ->> 'itemId')::uuid = item.id),
                      '[]'::jsonb
                    )
                  )
                ) FILTER (WHERE item.id IS NOT NULL),
                '[]'::jsonb),
            'holdings',
              COALESCE(
                jsonb_agg(
                  DISTINCT
                    hr.jsonb ||
                      jsonb_build_object(
                        'suppressFromDiscovery',
                        CASE WHEN hr.id IS NOT NULL THEN
                          COALESCE((vi.jsonb ->> 'discoverySuppress')::bool, false) OR
                          COALESCE((hr.jsonb ->> 'discoverySuppress')::bool, false)
                        ELSE NULL END::bool,
                        'administrativeNotes', '[]'::jsonb,
                        'holdingsStatements', COALESCE((SELECT jsonb_agg(e) FROM jsonb_array_elements(hr.jsonb -> 'holdingsStatements') AS e WHERE NOT COALESCE((e ->> 'staffOnly')::bool, false)), '[]'::jsonb),
                        'holdingsType', ht.jsonb - 'metadata',
                        'callNumberType', hrcnt.jsonb - 'metadata',
                        'electronicAccess', COALESCE(sul_mod_inventory_storage.getElectronicAccessName(COALESCE(hr.jsonb #> '{electronicAccess}', '[]'::jsonb)), '[]'::jsonb),
                        'notes', COALESCE((SELECT jsonb_agg(e || jsonb_build_object('holdingsNoteTypeName', ( SELECT jsonb ->> 'name' FROM sul_mod_inventory_storage.holdings_note_type WHERE id = nullif(e ->> 'holdingsNoteTypeId','')::uuid ))) FROM jsonb_array_elements(hr.jsonb -> 'notes') AS e WHERE NOT COALESCE((e ->> 'staffOnly')::bool, false)), '[]'::jsonb),
                        'illPolicy', ilp.jsonb - 'metadata',
                        'boundWith',
                          CASE WHEN parentItem.id IS NOT NULL THEN
                            jsonb_build_object(
                              'instance', jsonb_build_object(
                                'id', parentInstance.id,
                                'hrid', parentInstance.jsonb ->> 'hrid',
                                'title', parentInstance.jsonb ->> 'title'
                              ),
                              'holding', jsonb_build_object('effectiveLocationId', parentHolding.jsonb ->> 'effectiveLocationId'),
                              'item', jsonb_build_object(
                                'id', parentItem.id,
                                'hrid', parentItem.jsonb ->> 'hrid',
                                'barcode', parentItem.jsonb ->> 'barcode',
                                'status', parentItem.jsonb #>> '{status, name}'
                              )
                            )
                          ELSE NULL END::jsonb
                  )
                ) FILTER (WHERE hr.id IS NOT NULL), '[]'::jsonb
              ),
            'pieces',
              COALESCE(
                jsonb_agg(
                  DISTINCT pieces.jsonb
                ),
              '[]'::jsonb),
            'holdingSummaries',
              COALESCE(
                jsonb_agg(
                  DISTINCT jsonb_build_object(
                    'poLineId', po_line.id,
                    'poLineNumber', po_line.jsonb ->> 'poLineNumber',
                    'polReceiptStatus', po_line.jsonb ->> 'receiptStatus',
                    'orderType', purchase_order.jsonb ->> 'orderType',
                    'orderStatus', purchase_order.jsonb ->> 'workflowStatus',
                    'orderSentDate', purchase_order.jsonb ->> 'dateOrdered',
                    'orderCloseReason', purchase_order.jsonb #> '{closeReason}'
                  )),
              '[]'::jsonb)
            )
      FROM sul_mod_inventory_storage.instance vi
      LEFT JOIN sul_mod_inventory_storage.holdings_record hr
          ON hr.instanceid = vi.id
      LEFT JOIN sul_mod_inventory_storage.item item
          ON item.holdingsrecordid = hr.id
      -- Item's Material type relation
      LEFT JOIN sul_mod_inventory_storage.material_type mt
          ON item.materialtypeid = mt.id
      -- Item's Call number type relation
      LEFT JOIN sul_mod_inventory_storage.call_number_type cnt
          ON (item.jsonb #>> '{effectiveCallNumberComponents, typeId}')::uuid = cnt.id
      -- Item's Damaged status relation
      LEFT JOIN sul_mod_inventory_storage.item_damaged_status itemDmgStat
          ON (item.jsonb ->> 'itemDamagedStatusId')::uuid = itemDmgStat.id
      -- Item's Permanent loan type relation
      LEFT JOIN sul_mod_inventory_storage.loan_type plt
          ON item.permanentloantypeid = plt.id
      -- Item's Temporary loan type relation
      LEFT JOIN sul_mod_inventory_storage.loan_type tlt
          ON item.temporaryloantypeid = tlt.id
      -- Holdings type relation
      LEFT JOIN sul_mod_inventory_storage.holdings_type ht
          ON ht.id = hr.holdingstypeid
      -- Holdings Call number type relation
      LEFT JOIN sul_mod_inventory_storage.call_number_type hrcnt
          ON hr.callnumbertypeid = hrcnt.id
      -- Holdings Ill policy relation
      LEFT JOIN sul_mod_inventory_storage.ill_policy ilp
          ON hr.illpolicyid = ilp.id
      LEFT JOIN sul_mod_source_record_storage.records_lb rs
          ON rs.external_id = vi.id AND rs.state = 'ACTUAL'
      LEFT JOIN sul_mod_source_record_storage.marc_records_lb mr
          ON mr.id = rs.id
      -- Holding Summaries (purchase order) relation
      LEFT JOIN sul_mod_orders_storage.po_line po_line
          ON (po_line.jsonb ->> 'instanceId')::uuid = vi.id
      LEFT JOIN sul_mod_orders_storage.purchase_order purchase_order
          ON purchase_order.id = po_line.purchaseOrderId
      LEFT JOIN sul_mod_orders_storage.pieces pieces
          ON pieces.polineid = po_line.id
      -- Bound with parts relation
      LEFT JOIN sul_mod_inventory_storage.bound_with_part bw
          ON bw.holdingsrecordid = hr.id
      LEFT JOIN sul_mod_inventory_storage.item parentItem
          ON bw.itemid = parentItem.id
      LEFT JOIN sul_mod_inventory_storage.holdings_record parentHolding
          ON parentItem.holdingsRecordId = parentHolding.id
      LEFT JOIN sul_mod_inventory_storage.instance parentInstance
          ON parentHolding.instanceid = parentInstance.id
      -- Requests relation
      LEFT JOIN sul_mod_circulation_storage.request request
          ON lower(sul_mod_circulation_storage.f_unaccent(request.jsonb ->> 'itemId'::text)) = lower(sul_mod_circulation_storage.f_unaccent(item.id::text))
          AND lower(request.jsonb ->> 'status'::text) = lower('Open - Awaiting pickup')
      #{addl_from}
      WHERE #{conditions.join(' AND ')}
      GROUP BY vi.id
      SQL
    end
  end
end
