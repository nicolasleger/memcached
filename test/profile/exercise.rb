
require "#{File.dirname(__FILE__)}/../setup"

$LOAD_PATH << "#{File.dirname(__FILE__)}/../../lib/"
require 'memcached'
require 'rubygems'

GC.copy_on_write_friendly = true if GC.respond_to?("copy_on_write_friendly=")

class Worker
  def initialize(method_name = 'mixed', iterations = 10000, ignore_memory = false)
    @method = method_name
    @i = iterations.to_i
    @ignore_memory = ignore_memory

    puts "*** Running #{@method.inspect} test for #{@i} loops. ***"

    @key1 = "key1-"*8
    @key2 = "key2-"*8

    @value = []
    @marshalled = Marshal.dump(@value)

    @opts = [
      ["#{UNIX_SOCKET_NAME}0", "#{UNIX_SOCKET_NAME}1"],
      {
        :buffer_requests => false,
        :no_block => false,
        :namespace => "namespace"
      }
    ]
    @cache = Memcached::Rails.new(*@opts)

    @cache.set @key1, @value
  end

  def work
    case @method
      when "set"
        @i.times do
          @cache.set @key1, @value
        end
      when "get"
        @i.times do
          @cache.get @key1
        end
      when "delete"
        @i.times do
          @cache.set @key1, @value
          @cache.delete @key1
        end
      when "delete-miss"
        @i.times do
          @cache.delete @key1
        end
      when "get-miss"
        @i.times do
          @cache.get @key2
        end
      when "get-increasing"
        one_k = "x"*1024
        @i.times do |i|
          @cache.set @key1, one_k*(i+1), 0, false
          @cache.get @key1, false
        end
      when "get-miss-increasing"
        @i.times do |i|
          @cache.delete @key2
          @cache.get @key2
        end
      when "add"
        @i.times do
          @cache.delete @key1
          @cache.add @key1, @value
        end
      when "add-present"
        @cache.set @key1, @value
        @i.times do
          @cache.add @key1, @value
        end
      when "mixed"
        @i.times do
          @cache.set @key1, @value
          @cache.get @key1
        end
      when "stats"
        @i.times do
          @cache.stats
        end
      when "multiget"
        @i.times do
          @cache.get([@key1, @key2])
        end
      when "clone"
        @i.times do
          cache = @cache.clone
        end
      when "reset"
        @i.times do
          @cache.reset
        end
      when "servers"
        @i.times do
          @cache.servers
        end
      when "server_by_key"
        @i.times do
          @cache.server_by_key(@key1)
        end
      else
        raise "No such method"
    end

    unless @ignore_memory
      puts "*** Garbage collect. ***"
      10.times do
        GC.start
        sleep 0.1
      end

      sts, server_sts, clients = 0, 0, 0
      ObjectSpace.each_object(Memcached) { clients += 1 }
      ObjectSpace.each_object(Rlibmemcached::MemcachedSt) { sts += 1 }
      ObjectSpace.each_object(Rlibmemcached::MemcachedServerSt) { server_sts += 1 }
      puts "*** Structs: #{sts} ***"
      puts "*** Server structs: #{server_sts} ***"
      puts "*** Clients: #{clients} ***"

      begin;
        require 'memory'
        Process.memory.each { |key, value| puts "#{key}: #{value/1024.0}M" }
      rescue LoadError
      end
    end
  end
end
