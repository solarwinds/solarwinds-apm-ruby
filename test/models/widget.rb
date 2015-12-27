class Widget < ActiveRecord::Base
  def do_work(*args)
    Widget.first
  end

  def do_error(*args)
    raise "FakeTestError"
  end
end

class CreateWidgets < ActiveRecord::Migration
  def change
    create_table :widgets do |t|
      t.string :name
      t.text :description
      t.timestamps
    end
  end
end
