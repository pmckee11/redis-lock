# frozen_string_literal: true

require "redis"
require "securerandom"
require "connection_pool"

class Redis
  class Lock

    attr_reader :redis
    attr_reader :key

    class AcquireLockTimeOut < StandardError
    end

    UNLOCK_LUA_SCRIPT = "if redis.call('get',KEYS[1])==ARGV[1] then redis.call('del',KEYS[1]) end"

    # @param redis is a Redis connection pool
    # @param key String for a unique name of the lock to acquire
    # @param options[:auto_release_time] Int for the max number of seconds a lock can be held before it is auto released
    # @param options[:base_sleep] Int for the number of millis to sleep after the first time a lock is not acquired
    #                             (successive reattempts will be made with exponential back off)
    def initialize(redis, key, options = {})
      @redis               = redis
      @key                 = "lock:#{key}"
      @auto_release_time   = options[:auto_release_time] || 30
      @base_sleep_in_secs  = (options[:base_sleep] || 100) / 1000.0
      # Unique token set as the redis value of @key when locked by this instance
      @instance_name       = SecureRandom.hex
      # If lock was called and unlock has not yet been called, this is set to the time the lock was acquired
      @time_locked         = nil
    end

    # Acquire the lock. If a block is provided, the lock is acquired before yielding to the block and released once the
    # block is returned.
    # @param acquire_timeout Int for max number of seconds to spend acquiring the lock before raising an error
    def lock(acquire_timeout = 10, &block)
      if !attempt_lock(acquire_timeout)
        raise AcquireLockTimeOut.new
      end
      if block
        begin
          yield(self)
        ensure
          unlock()
        end
      end
    end

    # Releases the lock if it is held by this instance. By default, this method relies on the expiration time of the key
    # as a performance optimization when possible. If this is undesirable for some reason, set force_remote to true.
    # @param force_remote Boolean for whether to explicitly delete on the redis server instead of relying on expiration
    def unlock(force_remote = false)
      # unlock is a no-op if we never called lock
      if @time_locked
        if Time.now < @time_locked + @auto_release_time || force_remote
          @redis.with {|r| r.eval(UNLOCK_LUA_SCRIPT, [@key], [@instance_name])}
        end
        @time_locked = nil
      end
    end

    # @return Boolean that is true if the lock is currently held by any process
    def locked?
      return !@redis.with {|r| r.get(@key).nil?}
    end

    # Determines whether or not the lock is held by this instance. By default, this method relies on the expiration time
    # of the key  as a performance optimization when possible. If this is undesirable for some reason, set force_remote
    # to true.
    # @param force_remote Boolean for whether to verify with a call to the redis server instead of using the lock time
    # @return Boolean that is true if this lock instance currently holds the lock
    def locked_by_me?(force_remote = false)
      if @time_locked
        if force_remote
          return @redis.with {|r| r.get(@key)} == @instance_name
        end
        if Time.now < @time_locked + @auto_release_time
          return true
        end
      end
      return false
    end

    private

    # @param acquire_timeout Int for the number of seconds to spend attempting to acquire the lock
    # @return true if locked, false otherwise
    def attempt_lock(acquire_timeout)
      locked = false
      sleep_time = @base_sleep_in_secs
      when_to_timeout = Time.now + acquire_timeout
      while !locked
        locked = @redis.with {|r| r.set(@key, @instance_name, :nx => true, :ex => @auto_release_time) }
        if !locked
          if Time.now > when_to_timeout
            return false
          end
          sleep(sleep_time)
          # exponentially back off, but ensure that we take all of our wait time without going over
          sleep_time = [sleep_time * 2, when_to_timeout - Time.now].min
        end
      end
      @time_locked = Time.now
      return true
    end
  end
end
