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
append :linked_files, 'config/settings.local.yml'

# Default value for linked_dirs is []
append :linked_dirs, 'tmp', 'log', 'config/settings'

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
# set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure

set :whenever_roles, [:app]
set :ruby_version, 'ruby-3.3.1'

namespace :deploy do
  desc "config for monitoring the deployment's traject workers"

  namespace :systemd do
    task :generate do
      on roles(:app) do
        within release_path do
          execute "mkdir -p #{release_path}/service_templates"

          str = <<~SYSTEMD
            [Unit]
            Wants=#{fetch(:indexers).map { |service| "traject-#{service[:key]}.target" }.join(' ')}

            [Install]
            WantedBy=multi-user.target
          SYSTEMD
          upload! StringIO.new(str), 'service_templates/traject.target'

          fetch(:indexers).each do |service|
            str = <<~SYSTEMD
              [Unit]
              PartOf=traject.target
              StopWhenUnneeded=yes
              Wants=#{service[:count].times.map { |i| "traject-#{service[:key]}.#{i + 1}.service" }.join(' ')}
            SYSTEMD
            upload! StringIO.new(str), "service_templates/traject-#{service[:key]}.target"

            service[:count].times do |i|
              str = <<~SYSTEMD
                [Unit]
                PartOf=traject-#{service[:key]}.target
                StopWhenUnneeded=yes

                [Service]
                WorkingDirectory=#{current_path}
                Environment=PS=#{service[:key]}.#{i + 1}
                Environment=LANG=en_US.UTF-8
                ExecStart=/bin/bash -lc 'exec -a "traject-#{service[:key]}.#{i + 1}" /usr/local/rvm/bin/rvm #{fetch(:ruby_version)} do bundle exec traject -c #{service[:config]} #{fetch(:default_settings).merge(service[:settings]).map { |k, v| "-s #{k}=#{v}" }.join(' ')}'
                Restart=always
                RestartSec=14s
                StandardInput=null
                StandardOutput=syslog
                StandardError=syslog
                SyslogIdentifier=%n
                KillMode=mixed
                TimeoutStopSec=5
              SYSTEMD

              upload! StringIO.new(str), "service_templates/traject-#{service[:key]}.#{i + 1}.service"
            end
          end
        end
      end
    end

    task :reload do
      on roles(:app) do
        within release_path do
          execute 'systemctl --user stop traject.target'
          execute 'systemctl --user disable traject.target'

          execute 'mkdir -p /opt/app/indexer/.config/systemd/user'
          execute "cp #{release_path}/service_templates/* /opt/app/indexer/.config/systemd/user"

          execute 'systemctl --user enable traject.target'
          execute 'systemctl --user start traject.target'
        end
      end
    end
  end
end

before 'deploy:finished', 'deploy:systemd:generate'
before 'deploy:finished', 'deploy:systemd:reload'

set :default_settings, {
  'solr_writer.max_skipped' => -1,
  'log.level' => 'debug'
}
