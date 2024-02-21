#!/usr/bin/env ruby
# frozen_string_literal: true

postgres_url = ENV.fetch('DATABASE_URL', nil)
raise 'DATABASE_URL must be set' unless postgres_url
raise 'Usage: script/download_folio_record.rb <catkey>' unless ARGV[0]

require_relative '../config/boot'
record = Traject::FolioPostgresReader.find_by_catkey(ARGV[0], 'postgres.url' => postgres_url)
raise "No record found for catkey #{ARGV[0]}" unless record

puts record.to_json
