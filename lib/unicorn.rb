module Moonshine::Manifest::Unicorn
  
  def self.included(manifest)
    default_port=8080
    manifest.configure :unicorn => {
      :port => default_port,
      :rails_env => "production",
      :workers => 1,
      :preload_app => true,
      :timeout => 60,
      :socket => "127.0.0.1:#{default_port}",
      :socket_backlog => 1024
    }
  end
  
  def unicorn_config
    file "#{configuration[:deploy_to]}/shared/config/",
      :ensure => :directory,
      :owner => configuration[:user],
      :group => configuration[:group] || configuration[:user],
      :mode => '775'
    file "#{configuration[:deploy_to]}/shared/config/unicorn.rb",
      :ensure => :present,
      :content => template(File.join(File.dirname(__FILE__), '..','templates', 'unicorn.config.rb.erb')),
      # :notify => service("apache2"),
      :alias => "unicorn_config"
  end
  
  def unicorn_stack
     recipe :apache_server
     recipe :unicorn_site
     recipe :unicorn_config
     case database_environment[:adapter]
     when 'mysql', 'mysql2'
       recipe :mysql_server, :mysql_gem, :mysql_database, :mysql_user, :mysql_fixup_debian_start
     when 'postgresql'
       recipe :postgresql_server, :postgresql_gem, :postgresql_user, :postgresql_database
     when 'sqlite', 'sqlite3'
       recipe :sqlite3
     end
     recipe :rails_rake_environment, :rails_gems, :rails_directories, :rails_bootstrap, :rails_migrations, :rails_logrotate
     recipe :ntp, :time_zone, :postfix, :cron_packages, :motd, :security_updates, :apt_sources
  end
  
  # Creates and enables a vhost configuration named after your application.
  # Also ensures that the <tt>000-default</tt> vhost is disabled.
  def unicorn_site
  a2enmod "proxy"
  a2enmod "proxy_http"
  a2enmod "proxy_balancer"
    
  file "/etc/apache2/sites-available/#{configuration[:application]}",
    :ensure => :present,
    :content => template(File.join(File.dirname(__FILE__), '..','templates', 'unicorn.vhost.erb')),
    :notify => service("apache2"),
    :alias => "unicorn_vhost",
    :require => [exec("a2enmod proxy"), exec("a2enmod proxy_balancer")]

  a2dissite '000-default', :require => file("unicorn_vhost")
  a2ensite configuration[:application], :require => file("unicorn_vhost")
  end
  
  private
  
  def a2enmod(mod, options = {})
    exec("a2enmod #{mod}", {
        :command => "/usr/sbin/a2enmod #{mod}",
        :unless => "ls /etc/apache2/mods-enabled/#{mod}.load",
        :require => package("apache2-mpm-worker"),
        :notify => service("apache2")
      }.merge(options)
    )
  end
  
  # Symlinks a site from <tt>/etc/apache2/sites-enabled/site</tt> to
  #<tt>/etc/apache2/sites-available/site</tt>. Creates
  #<tt>exec("a2ensite #{site}")</tt>.
  def a2ensite(site, options = {})
    exec("a2ensite #{site}", {
        :command => "/usr/sbin/a2ensite #{site}",
        :unless => "ls /etc/apache2/sites-enabled/#{site}",
        :require => package("apache2-mpm-worker"),
        :notify => service("apache2")
      }.merge(options)
    )
  end

  # Removes a symlink from <tt>/etc/apache2/sites-enabled/site</tt> to
  #<tt>/etc/apache2/sites-available/site</tt>. Creates
  #<tt>exec("a2dissite #{site}")</tt>.
  def a2dissite(site, options = {})
    exec("a2dissite #{site}", {
        :command => "/usr/sbin/a2dissite #{site}",
        :onlyif => "ls /etc/apache2/sites-enabled/#{site}",
        :require => package("apache2-mpm-worker"),
        :notify => service("apache2")
      }.merge(options)
    )
  end
  
end