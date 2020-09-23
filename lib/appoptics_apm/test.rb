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
          ENV['DATABASE_URL'] = "postgresql://postgres:#{ENV['TRAVIS_PSQL_PASS']}@127.0.0.1:5432/travis_ci_test"
        elsif ENV.key?('POSTGRES_USER')
          ENV['DATABASE_URL'] = "postgresql://#{ENV['POSTGRES_USER']}@#{ENV['PSQL_HOST']}:5432/travis_ci_test"
          # ENV['DATABASE_URL'] = "postgresql://postgres@#{ENV['PSQL_HOST']}:5432/travis_ci_test"
        else
          ENV['DATABASE_URL'] = 'postgresql://postgres@127.0.0.1:5432/travis_ci_test'
        end
      end

      ##
      # set_mysql_env
      #
      # Used to set the mysql specific DATABASE_URL env based
      # on various conditions
      def set_mysql_env
        if ENV.key?('TRAVIS_MYSQL_PASS')
          ENV['DATABASE_URL'] = "mysql://root:#{ENV['TRAVIS_MYSQL_PASS']}@127.0.0.1:3306/travis_ci_test"
        elsif ENV.key?('DOCKER_MYSQL_PASS')
          ENV['DATABASE_URL'] = "mysql://root:#{ENV['DOCKER_MYSQL_PASS']}@#{ENV['MYSQL_HOST']}:3306/travis_ci_test"
        else
          ENV['DATABASE_URL'] = 'mysql://root@127.0.0.1:3306/travis_ci_test'
        end
      end

      ##
      # set_mysql2_env
      #
      # Used to set the mysql specific DATABASE_URL env based
      # on various conditions
      def set_mysql2_env
        if ENV.key?('TRAVIS_MYSQL_PASS')
          ENV['DATABASE_URL'] = "mysql2://root:#{ENV['TRAVIS_MYSQL_PASS']}@127.0.0.1:3306/travis_ci_test"
        elsif ENV.key?('DOCKER_MYSQL_PASS')
          ENV['DATABASE_URL'] = "mysql2://root:#{ENV['DOCKER_MYSQL_PASS']}@#{ENV['MYSQL_HOST']}:3306/travis_ci_test"
        else
          ENV['DATABASE_URL'] = 'mysql2://root@127.0.0.1:3306/travis_ci_test'
        end
      end
    end
  end
end
