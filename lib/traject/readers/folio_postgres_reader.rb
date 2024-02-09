# frozen_string_literal: true

require 'time'

module Traject
  class FolioPostgresReader # rubocop:disable  Metrics/ClassLength
    include Enumerable
    attr_reader :settings, :cursor_type

    # @param [IO] _input_stream
    # @param [Traject::Indexer::Settings] settings
    # @option settings [String] 'postgres.url'
    # @option settings [String] 'postgres.sql_filters'
    # @option settings [String] 'postgres.addl_from'
    # @option settings [String] 'postgres.page_size'
    # @option settings [String] 'folio.updated_after'
    # @option settings [String] 'statement_timeout'
    # @option settings [String] 'cursor_type' ('docs' or 'ids'); use 'ids' to pre-filter the records before constructing
    #   the full JSON. As of December 2023, this seems to provide better query performance (avoiding some very large temp files)
    # @option settings [String] 'cursor_base_name' ('folio'); the name of the cursor to use
    def initialize(_input_stream, settings)
      @settings = Traject::Indexer::Settings.new settings
      @connection = @settings['postgres.client'] || PG.connect(@settings['postgres.url'])
      @page_size = @settings['postgres.page_size'] || 25
      @updated_after = @settings['folio.updated_after']
      @statement_timeout = @settings.fetch('statement_timeout', 'DEFAULT') # Timeout value in milliseconds

      @sql_filters = [@settings['postgres.sql_filters']].flatten.compact
      @addl_from = @settings['postgres.addl_from']
      @cursor_type = @settings.fetch('cursor_type', 'docs')
      @cursor_base_name = @settings.fetch('cursor_base_name', 'folio')
    end

    # Return a single record by catkey by temporarily applying a SQL filter
    def self.find_by_catkey(catkey, settings = {})
      new(nil, settings.merge!('postgres.sql_filters' => "lower(sul_mod_inventory_storage.f_unaccent(vi.jsonb ->> 'hrid'::text)) = '#{catkey.downcase}'")).first
    end

    # @return [String] the SQL query used to retrieve the records from FOLIO; useful for debugging if nothing else.
    def queries
      if @updated_after
        delta_query(@updated_after)
      else
        contents_sql_query(@sql_filters, addl_from: @addl_from)
      end
    end

    # @yield [FolioRecord] each record from FOLIO
    def each
      return to_enum(:each) unless block_given?

      @connection.transaction do
        setup_query!

        # execute our query
        loop do
          response = fetch_next(@page_size)
          break if response.nil?

          response.each do |row|
            data = JSON.parse(row['jsonb_build_object'])

            merge_separately_queried_data!(data)

            yield FolioRecord.new(data)
          end
        end

        # close the cursor; should happen automatically at the end of the transaction
        # but just in case we keep the reader around...
        @connection.exec("CLOSE #{cursor_name}")
      end
    end

    def sql_server_current_time
      Time.parse(@connection.exec('SELECT NOW()').getvalue(0, 0))
    end

    private

    def cursor_name
      "#{@cursor_base_name}_#{cursor_type}"
    end

    # As of December 2023, we found that pulling in this infrequently changed data separate from the main query resulted
    # in better query performance.
    def merge_separately_queried_data!(data)
      data['items'].each do |item|
        item['location'] = {
          'effectiveLocation' => locations[item['effectiveLocationId']],
          'permanentLocation' => locations[item['permanentLocationId']],
          'temporaryLocation' => locations[item['temporaryLocationId']]
        }.compact

        item['request']['pickupServicePoint'] = service_points[item['request']['pickupServicePointId']] if item['request']

        item['courses'] = course_reserves[item['id']] || []

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

    def course_reserves
      @course_reserves ||= begin
        response = @connection.exec <<-SQL
          SELECT
              jsonb_build_object(
              'itemId', cr.jsonb ->> 'itemId',
              'id', cc.id,
              'name', cc.jsonb ->> 'name',
              'locationId', cl.jsonb ->> 'locationId',
              'courseNumber', cc.jsonb ->> 'courseNumber',
              'instructorNames', (SELECT jsonb_agg(instructor ->> 'name') FROM jsonb_array_elements(cl.jsonb #> '{instructorObjects}') AS instructor)
              ) AS jsonb
            FROM sul_mod_courses.coursereserves_reserves cr
            LEFT JOIN sul_mod_courses.coursereserves_courselistings cl ON cl.id = cr.courselistingid
            LEFT JOIN sul_mod_courses.coursereserves_courses cc ON cc.courselistingid = cl.id
        SQL

        response.map { |row| JSON.parse(row['jsonb']) }.each_with_object({}) do |course, hash|
          hash[course['itemId']] ||= []
          hash[course['itemId']] << course
        end
      end
    end

    def setup_query!
      # These settings seem to hint postgres to a better query plan
      @connection.exec('SET join_collapse_limit = 64')
      @connection.exec('SET from_collapse_limit = 64')

      # Increasing work_mem may reduce temp file usage; the default is 4MB
      @connection.exec('SET work_mem = \'64MB\'')

      # From the docs: "Smaller values of this setting bias the planner towards
      #  using “fast start” plans for cursors, which will retrieve the first
      #  few rows quickly while perhaps taking a long time to fetch all rows"
      @connection.exec('SET cursor_tuple_fraction = 0.5')

      @connection.exec("SET statement_timeout = #{@statement_timeout}")

      # declare a cursor
      @connection.exec("DECLARE #{cursor_name} CURSOR FOR #{queries}")
    end

    def fetch_next(count)
      cursor_response = @connection.exec("FETCH FORWARD #{count} IN #{cursor_name}")
      return if cursor_response.entries.empty?

      if cursor_by_ids?
        query = contents_sql_query([cursor_response.map { |row| "vi.id = '#{@connection.escape_string(row['id'])}'" }.join(' OR ')])
        @connection.exec(query)
      else
        cursor_response
      end
    end

    def cursor_by_ids?
      cursor_type == 'ids'
    end

    def delta_query(date, additional_tables: %w[cr cl cc])
      table_map = {
        'vi' => 'vi',
        'cr' => 'cr_filter',
        'cl' => 'cl_filter',
        'cc' => 'cc_filter'
      }

      cr_filter = 'LEFT JOIN sul_mod_inventory_storage.holdings_record hr_filter ON hr_filter.instanceid = vi.id
                    LEFT JOIN sul_mod_inventory_storage.item item_filter ON item_filter.holdingsrecordid = hr_filter.id
                    LEFT JOIN sul_mod_courses.coursereserves_reserves cr_filter ON (cr_filter.jsonb ->> \'itemId\')::uuid = item_filter.id'
      filter_join = {
        'cr_filter' => cr_filter,
        'cl_filter' => "#{cr_filter} LEFT JOIN sul_mod_courses.coursereserves_courselistings cl_filter ON cl_filter.id = cr_filter.courselistingid",
        'cc_filter' => "#{cr_filter} LEFT JOIN sul_mod_courses.coursereserves_courselistings cl_filter ON cl_filter.id = cr_filter.courselistingid
                                      LEFT JOIN sul_mod_courses.coursereserves_courses cc_filter ON cc_filter.courselistingid = cl_filter.id"
      }

      method = cursor_by_ids? ? :ids_sql_query : :contents_sql_query

      conditions = (['vi'] + additional_tables.map { |x| table_map[x] }).map do |table|
        c = if table == 'vi'
              "#{table}.complete_updated_date > '#{date}'"
            else
              "sul_mod_inventory_storage.strtotimestamp((#{table}.jsonb -> 'metadata'::text) ->> 'updatedDate'::text) > '#{date}'"
            end
        send(method, [c] + @sql_filters, addl_from: [filter_join[table], @addl_from].compact.join("\n"))
      end
      "(#{conditions.join(') UNION (')})"
    end

    def ids_sql_query(conditions, addl_from: nil)
      <<-SQL
      SELECT
        vi.id
      FROM sul_mod_inventory_storage.instance vi
      #{addl_from}
      WHERE #{conditions.join(' AND ')}
      GROUP BY vi.id
      SQL
    end

    def contents_sql_query(conditions, addl_from: nil)
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
                    END
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
