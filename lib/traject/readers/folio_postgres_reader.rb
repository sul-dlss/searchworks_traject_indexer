# frozen_string_literal: true

require 'time'

module Traject
  class FolioPostgresReader # rubocop:disable  Metrics/ClassLength
    include Enumerable
    attr_reader :settings, :last_response_date

    def initialize(_input_stream, settings)
      @settings = Traject::Indexer::Settings.new settings
      @connection = PG.connect(@settings['postgres.url'])
      @page_size = @settings['postgres.page_size'] || 100
      @updated_after = @settings['folio.updated_after']
      @sql_filters = @settings['postgres.sql_filters'] || 'TRUE'
    end

    # Return a single record by catkey by temporarily applying a SQL filter
    def self.find_by_catkey(catkey, settings = {})
      new(nil, settings.merge!('postgres.sql_filters' => "lower(sul_mod_inventory_storage.f_unaccent(vi.jsonb ->> 'hrid'::text)) = '#{catkey}'")).first
    end

    def each
      return to_enum(:each) unless block_given?

      @connection.transaction do
        # check postgres's clock time
        @last_response_date = last_response_date

        # set search path to avoid namespacing problems with folio functions
        @connection.exec('SET search_path = "sul_mod_inventory_storage"')

        # declare a cursor
        queries = if @updated_after
                    conditions = %w[vi hr item cr cl cc].map { |table| "sul_mod_inventory_storage.strtotimestamp((#{table}.jsonb -> 'metadata'::text) ->> 'updatedDate'::text) > '#{@updated_after}'" }.map { |q| [q, @sql_filters].compact }
                    conditions.map { |c| sql_query(c) }.join(') UNION (')
                  else
                    sql_query([@sql_filters])
                  end

        @connection.exec("DECLARE folio CURSOR FOR (#{queries})")

        # execute our query
        loop do
          response = @connection.exec("FETCH FORWARD #{@page_size} IN folio")
          break if response.entries.empty?

          response.each do |row|
            yield FolioRecord.new(JSON.parse(row['jsonb_build_object']))
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

    def sql_query(conditions)
      <<-SQL
      WITH viewLocations(locId, locJsonb, locCampJsonb, locLibJsonb, locInstJsonb) AS (
        SELECT loc.id AS locId,
               jsonb_build_object('id', loc.id, 'name', COALESCE(loc.jsonb ->> 'discoveryDisplayName', loc.jsonb ->> 'name'), 'isActive', COALESCE((loc.jsonb ->> 'isActive')::bool, false), 'code', loc.jsonb ->> 'code', 'details', loc.jsonb -> 'details') AS locJsonb,
               jsonb_build_object('id', locCamp.id, 'name', COALESCE(locCamp.jsonb ->> 'discoveryDisplayName', locCamp.jsonb ->> 'name'), 'code', locCamp.jsonb ->> 'code') AS locCampJsonb,
               jsonb_build_object('id', locLib.id, 'name', COALESCE(locLib.jsonb ->> 'discoveryDisplayName', locLib.jsonb ->> 'name'), 'code', locLib.jsonb ->> 'code') AS locLibJsonb,
               jsonb_build_object('id', locInst.id, 'name', COALESCE(locInst.jsonb ->> 'discoveryDisplayName', locInst.jsonb ->> 'name'), 'code', locInst.jsonb ->> 'code') AS locInstJsonb
        FROM sul_mod_inventory_storage.location loc
           LEFT JOIN sul_mod_inventory_storage.locinstitution locInst
                ON (loc.jsonb ->> 'institutionId')::uuid = locInst.id
           LEFT JOIN sul_mod_inventory_storage.loccampus locCamp
                ON (loc.jsonb ->> 'campusId')::uuid = locCamp.id
           LEFT JOIN sul_mod_inventory_storage.loclibrary locLib
                ON (loc.jsonb ->> 'libraryId')::uuid = locLib.id
        )
      SELECT
        vi.id,
          jsonb_build_object(
            'instance',
              vi.jsonb || jsonb_build_object(
                'suppressFromDiscovery', COALESCE((vi.jsonb ->> 'discoverySuppress')::bool, false)
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
                    'notes', COALESCE(sul_mod_inventory_storage.getItemNoteTypeName(item.jsonb -> 'notes'), '[]'::jsonb),
                    'location',
                      jsonb_build_object('permanentLocation',
                                          itemPermLoc.locJsonb || jsonb_build_object(
                                                    'campus', itemPermLoc.locCampJsonb,
                                                    'library', itemPermLoc.locLibJsonb,
                                                    'institution', itemPermLoc.locInstJsonb),
                                        'temporaryLocation',
                                          itemTempLoc.locJsonb || jsonb_build_object(
                                                    'campus', itemTempLoc.locCampJsonb,
                                                    'library', itemTempLoc.locLibJsonb,
                                                    'institution', itemTempLoc.locInstJsonb),
                                        'effectiveLocation',
                                          itemEffLoc.locJsonb || jsonb_build_object(
                                                    'campus', itemEffLoc.locCampJsonb,
                                                    'library', itemEffLoc.locLibJsonb,
                                                    'institution', itemEffLoc.locInstJsonb)
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
                        'holdingsType', ht.jsonb - 'metadata',
                        'callNumberType', hrcnt.jsonb - 'metadata',
                        'electronicAccess', COALESCE(sul_mod_inventory_storage.getElectronicAccessName(COALESCE(hr.jsonb #> '{electronicAccess}', '[]'::jsonb)), '[]'::jsonb),
                        'notes', COALESCE(sul_mod_inventory_storage.getHoldingNoteTypeName(hr.jsonb -> 'notes'), '[]'::jsonb),
                        'illPolicy', ilp.jsonb - 'metadata',
                        'location', jsonb_build_object('permanentLocation',
                                                          holdPermLoc.locJsonb || jsonb_build_object(
                                                                    'campus', holdPermLoc.locCampJsonb,
                                                                    'library', holdPermLoc.locLibJsonb,
                                                                    'institution', holdPermLoc.locInstJsonb),
                                                        'temporaryLocation',
                                                          holdTempLoc.locJsonb || jsonb_build_object(
                                                                    'campus', holdTempLoc.locCampJsonb,
                                                                    'library', holdTempLoc.locLibJsonb,
                                                                    'institution', holdTempLoc.locInstJsonb),
                                                        'effectiveLocation',
                                                          holdEffLoc.locJsonb || jsonb_build_object(
                                                                    'campus', holdEffLoc.locCampJsonb,
                                                                    'library', holdEffLoc.locLibJsonb,
                                                                    'institution', holdEffLoc.locInstJsonb)
                                                      )
                        )
                )
              ),
            'boundWithParents',
              COALESCE(
              jsonb_agg(
                jsonb_build_object(
                'parentInstanceHrid', parentInstance.jsonb ->> 'hrid',
                'parentInstanceTitle', parentInstance.jsonb ->> 'title',
                'parentItemId', parentItem.id,
                'parentItemBarcode', parentItem.jsonb ->> 'barcode',
                'parentItemLocation', jsonb_build_object('permanentLocation',
                                                          parentItemPermLoc.locJsonb || jsonb_build_object(
                                                                    'campus', parentItemPermLoc.locCampJsonb,
                                                                    'library', parentItemPermLoc.locLibJsonb,
                                                                    'institution', parentItemPermLoc.locInstJsonb),
                                                        'temporaryLocation',
                                                          parentItemTempLoc.locJsonb || jsonb_build_object(
                                                                    'campus', parentItemTempLoc.locCampJsonb,
                                                                    'library', parentItemTempLoc.locLibJsonb,
                                                                    'institution', parentItemTempLoc.locInstJsonb),
                                                        'effectiveLocation',
                                                          parentItemEffLoc.locJsonb || jsonb_build_object(
                                                                    'campus', parentItemEffLoc.locCampJsonb,
                                                                    'library', parentItemEffLoc.locLibJsonb,
                                                                    'institution', parentItemEffLoc.locInstJsonb)
              ),
                'childHoldingCallNumber', hr.jsonb ->> 'callNumber',
                'childHoldingId', hr.id
                )
              ) FILTER (WHERE parentItem.id IS NOT NULL),
              '[]'::jsonb),
            'pieces',
              COALESCE(
                jsonb_agg(
                  DISTINCT pieces.jsonb
                ),
              '[]'::jsonb),
            'courses',
              COALESCE(
                jsonb_agg(
                  DISTINCT jsonb_build_object(
                    'id', cc.id,
                    'name', cc.jsonb ->> 'name',
                    'courseNumber', cc.jsonb ->> 'courseNumber',
                    'courseListingId', cc.jsonb ->> 'courseListingId',
                    'instructorObjects', cl.jsonb #> '{instructorObjects}'
                  )
                ) FILTER (WHERE cc.id IS NOT NULL),
              '[]'::jsonb)
            )
      FROM sul_mod_inventory_storage.instance vi
      LEFT JOIN sul_mod_inventory_storage.holdings_record hr
         ON hr.instanceid = vi.id
      LEFT JOIN sul_mod_inventory_storage.item item
         ON item.holdingsrecordid = hr.id
      -- Course information related to items on reserve
      LEFT JOIN sul_mod_courses.coursereserves_reserves cr
        ON (cr.jsonb ->> 'itemId')::uuid = item.id
      LEFT JOIN sul_mod_courses.coursereserves_courselistings cl
        ON cl.id = cr.courselistingid
      LEFT JOIN sul_mod_courses.coursereserves_courses cc
        ON cc.courselistingid = cl.id
      -- Item's Effective location relation
      LEFT JOIN viewLocations itemEffLoc
            ON (item.jsonb ->> 'effectiveLocationId')::uuid = itemEffLoc.locId
      -- Item's Permanent location relation
      LEFT JOIN viewLocations itemPermLoc
            ON (item.jsonb ->> 'permanentLocationId')::uuid = itemPermLoc.locId
      -- Item's Temporary location relation
      LEFT JOIN viewLocations itemTempLoc
            ON (item.jsonb ->> 'temporaryLocationId')::uuid = itemTempLoc.locId
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
            ON (item.jsonb ->> 'permanentLoanTypeId')::uuid = plt.id
      -- Item's Temporary loan type relation
      LEFT JOIN sul_mod_inventory_storage.loan_type tlt
            ON (item.jsonb ->> 'temporaryLoanTypeId')::uuid = tlt.id
      -- Holdings type relation
      LEFT JOIN sul_mod_inventory_storage.holdings_type ht
         ON ht.id = hr.holdingstypeid
      LEFT JOIN viewLocations holdPermLoc
         ON (hr.jsonb ->> 'permanentLocationId')::uuid = holdPermLoc.locId
      -- Holdings Temporary location relation
      LEFT JOIN viewLocations holdTempLoc
         ON (hr.jsonb ->> 'temporaryLocationId')::uuid = holdTempLoc.locId
      -- Holdings Effective location relation
      LEFT JOIN viewLocations holdEffLoc
         ON (hr.jsonb ->> 'effectiveLocationId')::uuid = holdEffLoc.locId
      -- Holdings Call number type relation
      LEFT JOIN sul_mod_inventory_storage.call_number_type hrcnt
         ON (hr.jsonb ->> 'callNumberTypeId')::uuid = hrcnt.id
      -- Holdings Ill policy relation
      LEFT JOIN sul_mod_inventory_storage.ill_policy ilp
            ON hr.illpolicyid = ilp.id
      LEFT JOIN sul_mod_source_record_storage.records_lb rs
        ON rs.external_id = vi.id
      LEFT JOIN sul_mod_source_record_storage.marc_records_lb mr
        ON mr.id = rs.id
      -- Pieces relation
      LEFT JOIN sul_mod_orders_storage.titles titles
        ON (titles.jsonb ->> 'instanceId')::uuid  = vi.id
      LEFT JOIN sul_mod_orders_storage.pieces pieces
        ON pieces.titleid = titles.id
      -- Bound with parts relation
      LEFT JOIN sul_mod_inventory_storage.bound_with_part bw
        ON bw.holdingsrecordid = hr.id
      LEFT JOIN sul_mod_inventory_storage.item parentItem
        ON bw.itemid = parentItem.id
      LEFT JOIN sul_mod_inventory_storage.holdings_record parentHolding
        ON parentItem.holdingsRecordId = parentHolding.id
      LEFT JOIN sul_mod_inventory_storage.instance parentInstance
        ON parentHolding.instanceid = parentInstance.id
      -- BW Parent Item's Effective location relation
      LEFT JOIN viewLocations parentItemEffLoc
        ON (parentItem.jsonb ->> 'effectiveLocationId')::uuid = parentItemEffLoc.locId
      -- BW Parent Item's Permanent location relation
      LEFT JOIN viewLocations parentItemPermLoc
        ON (parentItem.jsonb ->> 'permanentLocationId')::uuid = parentItemPermLoc.locId
      -- BW Parent Item's Temporary location relation
      LEFT JOIN viewLocations parentItemTempLoc
        ON (parentItem.jsonb ->> 'temporaryLocationId')::uuid = parentItemTempLoc.locId
      WHERE #{conditions.join(' AND ')}
      GROUP BY vi.id
      SQL
    end
  end
end
