# config valid for current version and patch releases of Capistrano

set :application, "searchworks_traject_indexer"
set :repo_url, 'https://github.com/sul-dlss/searchworks_traject_indexer.git'

# Default branch is :master
ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, "/opt/app/indexer/searchworks_traject_indexer"

set :rvm_ruby_version, 'ruby-2.5.3'

set :honeybadger_env, "#{fetch(:stage)}"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
append :linked_files, "config/settings.yml"

# Default value for linked_dirs is []
append :linked_dirs, "tmp", "run", "log"

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
# set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure

set :whenever_roles, [:app]

task :jruby_bundle_install do
  on fetch(:bundle_servers) do
    within release_path do
      with fetch(:bundle_env_variables) do
        options = []
        options << "--gemfile #{fetch(:bundle_gemfile)}" if fetch(:bundle_gemfile)
        options << "--path #{fetch(:bundle_path)}" if fetch(:bundle_path)
        options << "--binstubs #{fetch(:bundle_binstubs)}" if fetch(:bundle_binstubs)
        options << "--jobs #{fetch(:bundle_jobs)}" if fetch(:bundle_jobs)
        options << "--without #{fetch(:bundle_without)}" if fetch(:bundle_without)
        options << "#{fetch(:bundle_flags)}" if fetch(:bundle_flags)
        execute "#{fetch(:rvm_path)}/bin/rvm", 'jruby-9.2.4.0', 'do', :bundle, :install, *options
      end
    end
  end
end

namespace :deploy do
  desc "stop/start eye, config for monitoring the deployment's traject workers"
  before :cleanup, :load_eye_config do
    on roles(:app) do
      within release_path do
        # :delayed_job_workers is set by the env specific cap configs.  it won't
        # yet be set when this task is defined (though it will be by the time it's
        # executed).
        # quit first to make sure the new config is loaded
        execute :bundle, :exec, :eye, :quit

        # avoid spaces in the command name, see http://capistranorb.com/documentation/getting-started/tasks/
        execute :bundle, :exec, :'eye', :load, :'traject.eye'
      end
    end
  end
end

before 'bundler:install', 'jruby_bundle_install'
