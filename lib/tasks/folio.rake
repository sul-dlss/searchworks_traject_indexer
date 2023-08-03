# frozen_string_literal: true

namespace :folio do
  desc 'Harvest types from folio'
  task :update_types_cache do
    Folio::Types.instance.sync!
  end
end
