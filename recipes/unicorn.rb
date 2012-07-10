namespace :unicorn do
  desc <<-DESC
  Restart unicorn
  DESC
  task :upgrade do
    sudo "/etc/init.d/unicorn upgrade"
  end

  desc "stop unicorn"
  task :stop do
    sudo "/etc/init.d/unicorn stop"
  end

  desc "start unicorn"
  task :start do
    sudo "/etc/init.d/unicorn start"
  end

end
after 'deploy:restart', 'unicorn:upgrade'
