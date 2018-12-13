require 'config'

Config.load_and_set_settings(Config.setting_files(File.expand_path('config', File.join(File.dirname(__FILE__))), ENV['TRAJECT_ENV']))

Eye.config do
  logger File.expand_path('log/eye.log', File.join(File.dirname(__FILE__)))
end

Eye.application 'traject' do
  working_dir File.expand_path(File.join(File.dirname(__FILE__)))
  stop_on_delete true

  group 'workers' do
    # workers can take a while to restart, especially when they've consumed a lot of memory
    start_timeout 90.seconds
    start_grace 10.seconds
    stop_timeout 90.seconds
    stop_grace 10.seconds
    restart_timeout 90.seconds
    restart_grace 10.seconds

    Settings.processes.each do |config|
      (config.num_processes || 1).times do |i|
        process "#{config.name}_#{i}" do
          config.env.each do |k, v|
            env k => v
          end
          stop_command 'kill -9 {PID}'

          pid_file "run/#{config.name}_#{i}.pid"
          daemonize true
          use_leaf_child true
          stdall "log/#{config.name}.log"

          config.config.each do |k, v|
            public_send(k, v)
          end
        end
      end
    end
  end
end
