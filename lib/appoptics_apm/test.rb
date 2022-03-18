# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module AppOpticsAPM
  module Test
    class << self
      ##
      # load_extras
      #
      # This method simply loads all the extras needed to run
      # tests such as models, jobs etc...
      #
      def load_extras
        # If we're using the libraries gemfile (with sidekiq and resque)
        if AppOpticsAPM::Test.gemfile?(:libraries)
          # Load all of the test workers
          pattern = File.join(File.dirname(__FILE__), '../../test/jobs/**/', '*.rb')
          Dir.glob(pattern) do |f|
            AppOpticsAPM.logger.debug "[appoptics_apm/test] Loading test job file: #{File.basename(f)}"
            require f
          end
        end
      end

      ##
      # gemfile?
      #
      # Method used to determine under which gemfile we're running.
      # Pass <tt>name</tt> as the gemfile name only (without the
      # .gemfile extension)
      #
      # returns true or fase depending on result
      #
      def gemfile?(name)
        File.basename(ENV['BUNDLE_GEMFILE']) == (name.to_s + '.gemfile')
      end

      ##
      # gemfile
      #
      # Used to determine under which gemfile we are running.  This
      # method will return the name of the active gemfile
      #
      def gemfile
        File.basename(ENV['BUNDLE_GEMFILE']).split('.').first
      end

      ##
      # set_postgresql_env
      #
      # Used to set the postgresql specific DATABASE_URL env based
      # on various conditions
      def set_postgresql_env
        if ENV.key?('TRAVIS_PSQL_PASS')
          ENV['DATABASE_URL'] = "postgresql://postgres:#{ENV['TRAVIS_PSQL_PASS']}@127.0.0.1:5432/test_db"
        elsif ENV.key?('POSTGRES_USER')
          port = ENV.key?('POSTGRES_PORT') ? ENV['POSTGRES_PORT'] : 5432
          ENV['DATABASE_URL'] = "postgresql://#{ENV['POSTGRES_PASSWORD']}:#{ENV['POSTGRES_USER']}@#{ENV['POSTGRES_HOST']}:#{port}/test_db"
        else
          ENV['DATABASE_URL'] = 'postgresql://postgres@127.0.0.1:5432/test_db'
        end
      end

      ##
      # To configure Rails to enable or disable prepared statements
      # we need to do it using the database.yml file
      # there is no method exposed (afaik) to set prepared_statements
      # interactively
      def set_postgresql_rails_config
        # need to use string keys otherwise the output is not readable by Rails 5
        config = {
          'adapter'  => "postgresql",
          'username' =>  ENV.key?('POSTGRES_USER') ? ENV['POSTGRES_USER'] : "postgres",
          'password' =>  ENV.key?('POSTGRES_PASSWORD') ? ENV['POSTGRES_PASSWORD'] : "postgres",
          'database' =>  "test_db",
          'host'     =>  ENV.key?('POSTGRES_HOST') ? ENV['POSTGRES_HOST'] : '127.0.0.1',
          'port'     =>  ENV.key?('POSTGRES_PORT') ? ENV['POSTGRES_PORT'] : 5432,
          'statement_limit' =>  5
        }

        if ENV.key?('TEST_PREPARED_STATEMENT')
          config['prepared_statements'] = ENV['TEST_PREPARED_STATEMENT'] == 'true' ? true : false
        else
          config['prepared_statements'] = false
        end

        env_config = {
          'default' => config,
          'development' => config,
          'test' => config
        }

        FileUtils.mkdir_p('config')
        File.open("config/database.yml","w") do |file|
          file.write env_config.to_yaml
        end
        config
      end
      ##
      # set_mysql_env
      #
      # Used to set the mysql specific DATABASE_URL env based
      # on various conditions
      def set_mysql_env
        if ENV.key?('TRAVIS_MYSQL_PASS')
          ENV['DATABASE_URL'] = "mysql://root:#{ENV['TRAVIS_MYSQL_PASS']}@127.0.0.1:3306/test_db"
        elsif ENV.key?('DOCKER_MYSQL_PASS')
          port = ENV.key?('MYSQL_PORT') ? ENV['MYSQL_PORT'] : 3306
          ENV['DATABASE_URL'] = "mysql://root:#{ENV['DOCKER_MYSQL_PASS']}@#{ENV['MYSQL_HOST']}:#{port}/test_db"
        else
          ENV['DATABASE_URL'] = 'mysql://root@127.0.0.1:3306/test_db'
        end
      end

      ##
      # set_mysql2_env
      #
      # Used to set the mysql specific DATABASE_URL env based
      # on various conditions
      def set_mysql2_env
        if ENV.key?('TRAVIS_MYSQL_PASS')
          ENV['DATABASE_URL'] = "mysql2://root:#{ENV['TRAVIS_MYSQL_PASS']}@127.0.0.1:3306/test_db"
        elsif ENV.key?('DOCKER_MYSQL_PASS')
          ENV['DATABASE_URL'] = "mysql2://root:#{ENV['DOCKER_MYSQL_PASS']}@#{ENV['MYSQL_HOST']}:3306/test_db"
        else
          ENV['DATABASE_URL'] = 'mysql2://root@127.0.0.1:3306/test_db'
        end
      end

      ##
      # To configure Rails to enable or disable prepared statements
      # we need to do it using the database.yml file
      # there is no method exposed (afaik) to set prepared_statements
      # interactively
      def set_mysql2_rails_config
        config = {
          'adapter' => "mysql2",
          'username' => "root",
          'database' => "test_db",
          'port' => 3306
        }

        config[:password] = ENV['DOCKER_MYSQL_PASS'] if ENV.key?('DOCKER_MYSQL_PASS')
        config[:host] = ENV.key?('MYSQL_HOST') ? ENV['MYSQL_HOST'] : '127.0.0.1'

        if ENV.key?('TEST_PREPARED_STATEMENT')
          config['prepared_statements'] = ENV['TEST_PREPARED_STATEMENT'] == 'true' ? true : false
        else
          config['prepared_statements'] = false
        end

        env_config = {
          'default' => config,
          'test' => config
        }

        FileUtils.mkdir_p('config')
        File.open("config/database.yml","w") do |file|
          file.write env_config.to_yaml
        end
        config
      end
    end
  end
end
