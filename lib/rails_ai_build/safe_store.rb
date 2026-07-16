# frozen_string_literal: true

require "monitor"

module RailsAiBuild
  # Mutex + size-bounded Hash for in-process multi-threaded safety.
  class SafeStore
    def initialize(max_size: 10_000)
      @max_size = max_size
      @data = {}
      @mutex = Monitor.new
    end

    def synchronize(&)
      @mutex.synchronize(&)
    end

    def [](key)
      synchronize { @data[key] }
    end

    def []=(key, value)
      synchronize do
        @data[key] = value
        evict! if @data.size > @max_size
        value
      end
    end

    def delete(key)
      synchronize { @data.delete(key) }
    end

    def key?(key)
      synchronize { @data.key?(key) }
    end

    def size
      synchronize { @data.size }
    end

    def clear!
      synchronize { @data.clear }
    end

    def fetch(key, &block)
      synchronize { @data.fetch(key, &block) }
    end

    def each(&block)
      synchronize { @data.each(&block) }
    end

    def keys
      synchronize { @data.keys }
    end

    def to_h
      synchronize { @data.dup }
    end

    private

    def evict!
      # Drop oldest insertion order entries (Ruby Hash preserves order)
      overflow = @data.size - @max_size
      return if overflow <= 0

      overflow.times { @data.shift }
    end
  end
end
