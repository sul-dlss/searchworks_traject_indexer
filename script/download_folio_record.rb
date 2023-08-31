#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'pg'
require 'traject'
require 'active_support/core_ext/enumerable'
require_relative '../lib/folio_record'
require_relative '../lib/traject/readers/folio_postgres_reader'

postgres_url = ENV.fetch('DATABASE_URL', nil)
raise 'DATABASE_URL must be set' unless postgres_url
raise 'Usage: script/download_folio_record.rb <catkey>' unless ARGV[0]

record = Traject::FolioPostgresReader.find_by_catkey(ARGV[0], 'postgres.url' => postgres_url)
raise "No record found for catkey #{ARGV[0]}" unless record

puts JSON.pretty_generate(record.as_json)
