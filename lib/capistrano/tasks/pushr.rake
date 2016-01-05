namespace :load do
  task :defaults do
    set :pushr_default_hooks, -> { true }

    set :pushr_pid, -> { File.join shared_path, 'tmp', 'pids', 'pushr.pid' }
  end
end

namespace :deploy do
  before :starting, :check_pushr_hooks do
    invoke 'pushr:add_default_hooks' if fetch(:pushr_default_hooks)
  end

  after :publishing, :restart_pushr do
    invoke 'pushr:restart' if fetch(:pushr_default_hooks)
  end
end

namespace :pushr do
  desc 'Add default Pushr hooks.'
  task :add_default_hooks do
    after 'deploy:starting', 'pushr:quiet'
    after 'deploy:updated', 'pushr:stop'
    after 'deploy:reverted', 'pushr:stop'
    after 'deploy:published', 'pushr:start'
  end

  desc 'Quiet Pushr daemon (stop processing new stuff).'
  task :quiet do
    on roles(fetch(:pushr_roles, :all)) do
      stop_pushr 'USR1'
    end
  end

  desc 'Stop Pushr daemon.'
  task :stop do
    on roles(fetch(:pushr_roles, :all)) do
      stop_pushr 'TERM'
    end
  end

  desc 'Start Pushr daemon.'
  task :start do
    on roles(fetch(:pushr_roles, :all)) do
      start_pushr
    end
  end

  desc 'Restart Pushr daemon.'
  task :restart do
    invoke 'pushr:stop'
    invoke 'pushr:start'
  end

  desc 'Pushr version.'
  task :version do
    on roles(fetch(:pushr_roles, :all)) do
      print_version
    end
  end

  desc 'Pushr status.'
  task :status do
    on roles(fetch(:pushr_roles, :all)) do
      status_message = pushr_pid_process_exists? ? "running with pid #{pushr_pid}" : 'not running'
      puts "Pushr is #{status_message}!"
    end
  end

  ###

  def pushr_pid
    capture pushr_pid_command
  end

  def pushr_pid_command
    "cat #{fetch(:pushr_pid)}"
  end

  def pushr_pid_file_exists?
    test(*("[ -f #{fetch(:pushr_pid)} ]").split(' '))
  end

  def pushr_pid_process_exists?
    pushr_pid_file_exists? && test(*("kill -0 `#{pushr_pid_command}`").split(' '))
  end

  def stop_pushr(signal)
    return unless test("[ -d #{release_path} ]") && pushr_pid_process_exists?

    within release_path do
      puts 'Stopping Pushr...'
      execute "kill -#{signal} `#{pushr_pid_command}`"
      puts 'done!'
    end
  end

  def start_pushr
    within release_path do
      puts 'Starting Pushr...'
      execute 'bundle', 'exec', 'pushr', '--pid-file', fetch(:pushr_pid)
      puts 'done!'
    end
  end

  def print_version
    within release_path do
      puts capture('bundle', 'exec', 'pushr', '--version')
    end
  end
end
