class TestMe
  class Snapshot

    class << self
      # !!! do not shift the definition of take_snapshot from line 7 !!!
      # the line number is used to verify a test in frames_test.cc
      def take_snapshot
        # puts "getting frames ...."
        begin
          ::RubyCalls::get_frames
        rescue => e
          puts "oops, getting frames didn't work"
          puts e
        end
      end

      def all_kinds
        begin
          Teddy.new.sing do
            # Teddy.newobj do
            take_snapshot
          end
        rescue => e
          puts "Ruby call did not work"
          puts e
        end
      end
    end
  end

  class Teddy

    attr_accessor :name

    def sing
      3.times do
        yoddle do
          html_wrap("title", "Hello") { |_html| yield }
        end
      end
    end

    private

    def yoddle
      a_proc = -> (x) { x * x;  yield }
      in_block(&a_proc)
    end

    def in_block(&block)
      begin
        yield 7
        # puts "block called!"
      rescue => e
        puts "no, this should never happen"
        puts e
      end
    end

    def html_wrap(tag, text)
      html = "<#{tag}>#{text}</#{tag}>"
      yield html
    end

  end
end


