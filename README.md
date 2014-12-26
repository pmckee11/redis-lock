# Redis::Lock

This gem implements robust pessimistic locking as described at http://redis.io/commands/set using the ruby redis client.

## Installation

Add this line to your application's Gemfile:

    gem 'pmckee11-redis-lock', require: 'redis-lock'

and then run bundler.

Or run

    $ gem install pmckee11-redis-lock
    
## Background

This implements a distributed lock with a timeout almost exactly as described in the redis documentation.
There are a few other redis lock implementations in ruby, but none of them seemed to be using the newer features in redis that can yield a performance improvement (e.g. the expanded SET parameters and Lua scripting). Using this gem requires a redis 2.6.12 or newer server, allowing it to leverage those newer features to make fewer round trips and provide better performance 

## Usage

Create an instance of `Redis::Lock` with the desired redis connection and parameters. `auto_release_time` is the lock TTL in seconds (defaults to 10) and `base_sleep` is the amount of time in milliseconds to sleep after the first failure to acquire a lock (defaults to 100ms). Successive failures to acquire a lock result in exponential back off to prevent wasted cycles:

    redis = Redis.new
    my_lock = Redis::Lock.new(redis, 
                              "my-lock-key", 
                              :auto_release_time => LOCK_TTL_IN_SECS, 
                              :base_sleep => SLEEP_IN_MS)
                           
Once you have a lock, you can manually lock and unlock or pass a block to lock only around your code:

    my_lock.lock
    # Do stuff
    my_lock.unlock

    my_lock.do |lock|
        # Do stuff
    end

You can also configure the maximum amount of time in seconds to block on acquiring a lock (defaults to 10):

    my_lock(5).do |lock|
        # Do stuff
    end

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
