#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require_relative '../config/boot'

postgres_url = ENV.fetch('DATABASE_URL', nil)
raise 'DATABASE_URL must be set' unless postgres_url
raise 'Usage: script/download_folio_record.rb <catkey>' unless ARGV[0]

record = Traject::FolioPostgresReader.find_by_catkey(ARGV[0], 'postgres.url' => postgres_url)
puts JSON.pretty_generate(record.as_json)
