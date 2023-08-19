# frozen_string_literal: true

# config valid for current version and patch releases of Capistrano

set :application, 'searchworks_traject_indexer'
set :repo_url, 'https://github.com/sul-dlss/searchworks_traject_indexer.git'

# Default branch is :master so we need to update to main
if ENV['DEPLOY']
  set :branch, 'main'
else
  ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call
end

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, '/opt/app/indexer/searchworks_traject_indexer'

set :honeybadger_env, "#{fetch(:stage)}"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
append :linked_files, 'indexing.env'
append :linked_files, 'config/settings.local.yml'

# Default value for linked_dirs is []
append :linked_dirs, 'tmp', 'run', 'log', 'config/settings'

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
# set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure

set :whenever_roles, [:app]

namespace :deploy do
  desc "config for monitoring the deployment's traject workers"
  before :cleanup, :start_workers do
    on roles(:app) do
      sudo :systemctl, 'restart', 'traject.target', raise_on_non_zero_exit: false
    end
  end

  desc 'update and deploy new systemd scripts'
  task :update_systemd_scripts do
    on roles(:app) do
      within release_path do
        execute "script/export_procfiles_to_systemd_#{fetch(:procfile_env_suffix)}.sh"
        execute 'script/reload_systemd_indexers.sh'
      end
    end
  end
end
