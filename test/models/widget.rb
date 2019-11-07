# Somehow the Padrino::Reloader v14 is detecting and loading
# this file when it shouldn't.  Block it from loading for
# Padrino for now.

# this is a stupid solution for not having any assets
`mkdir -p app/assets/config && echo '{}' > app/assets/config/manifest.js`
require 'active_record'
unless defined?(Padrino)
  class Widget < ActiveRecord::Base
    def do_work(*args)
      Widget.first
    end

    def do_error(*args)
      raise "FakeTestError"
    end
  end

  if Rails.version >= '5.1'
    class CreateWidgets < ActiveRecord::Migration[5.1]
      def change
        create_table :widgets do |t|
          t.string :name
          t.text :description
          t.timestamps null: false
        end
      end
    end
  else
    class CreateWidgets < ActiveRecord::Migration
      def change
        create_table :widgets do |t|
          t.string :name
          t.text :description
          t.timestamps null: false
        end
      end
    end
  end
end
