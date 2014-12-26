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
There are a few other redis lock implementations in ruby, but none of them seemed to be using the newer features in redis that can yield a performance improvement (e.g. the expanded SET parameters and Lua scripting). Using this gem requires a redis 2.6.12 server, allowing it to leverage those newer features to make fewer round trips and provide better performance 

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request