require 'spec_helper'

describe Redis::Lock do
  let(:key) {"key"}
  let(:lock) {Redis::Lock.new(@redis, key)}

  before(:all) do
    @redis = Redis.new
  end

  before(:each) do
    @redis.flushdb
  end

  after(:each) do
    @redis.flushdb
  end

  after(:all) do
    @redis.quit
  end

  context "#lock" do
    it "should set an appropriate key in redis" do
      lock.lock
      expect(@redis.get("lock:#{key}")).not_to be_nil
    end

    context "when redis is a connection pool" do
      let(:fake_pool) {ConnectionPool.new(Redis.new)}
      let(:pool_lock) {Redis::Lock.new(fake_pool, key)}

      it "should set an appropriate key in redis" do
        pool_lock.lock
        expect(fake_pool.with {|r| r.get("lock:#{key}")}).not_to be_nil
      end
    end

    context "when a block is provided" do
      it "locks before yielding and releases after" do
        expect(lock).to receive(:test_message)
        lock.lock do |l|
          expect(l).to eq(lock)
          l.test_message
          expect(@redis.get("lock:#{key}")).not_to be_nil
        end
        expect(@redis.get("lock:#{key}")).to be_nil
      end
    end

    context "when acquire_timeout is provided" do
      it "times out after the given timeout with an appropriate error" do
        other_lock = Redis::Lock.new(@redis, key)
        time = Time.now
        lock.lock
        begin
          other_lock.lock(2)
          fail()
        rescue => e
          expect(Time.now - time).to be_within(0.1).of(2.0)
          expect(e).to be_a(Redis::Lock::AcquireLockTimeOut)
        end
      end
    end

    context "when initialized with auto_release_time" do
      it "sets the redis key with an appropriate expiration" do
        other_lock = Redis::Lock.new(@redis, key, :auto_release_time => 7)
        expect(@redis).to receive(:set).with("lock:#{key}", an_instance_of(String), :nx => true, :ex => 7).and_return(true)
        other_lock.lock
      end
    end

    context "when initialized with base_sleep" do
      it "retries with exponential back off starting at base_sleep millis" do
        other_lock = Redis::Lock.new(@redis, key, :base_sleep => 25)
        expect(other_lock).to receive(:sleep).with(0.025).ordered
        expect(other_lock).to receive(:sleep).with(0.05).ordered
        expect(other_lock).to receive(:sleep).with(0.1).ordered
        expect(other_lock).to receive(:sleep).with(0.2).ordered
        expect(other_lock).to receive(:sleep) do |sleep_time|
          expect(sleep_time).to eq(0.4)
          lock.unlock
        end.ordered
        lock.lock
        other_lock.lock
      end
    end
  end

  context "#unlock" do
    it "should delete an appropriate key from redis" do
      lock.lock
      lock.unlock
      expect(@redis.get("lock:#{key}")).to be_nil
    end

    it "should not delete a lock held by another instance" do
      other_lock = Redis::Lock.new(@redis, key, :auto_release_time => 1)
      other_lock.lock
      sleep(1.1)
      lock.lock
      other_lock.unlock(true)
      expect(@redis.get("lock:#{key}")).not_to be_nil
    end

    context "when the instance has not been locked" do
      it "is a no op" do
        expect(@redis).not_to receive(:eval)
        lock.unlock
      end
    end

    context "when the instance lock has expired based on the lock time" do
      it "is a no op" do
        other_lock = Redis::Lock.new(@redis, key, :auto_release_time => 1)
        other_lock.lock
        sleep(1)
        expect(@redis).not_to receive(:eval)
        other_lock.unlock
      end

      context "but force_remote is true" do
        it "makes a redis call" do
          other_lock = Redis::Lock.new(@redis, key, :auto_release_time => 1)
          other_lock.lock
          sleep(1)
          expect(@redis).to receive(:eval).with(Redis::Lock::UNLOCK_LUA_SCRIPT, ["lock:#{key}"], instance_of(Array)).once
          other_lock.unlock(true)
        end
      end
    end
  end

  context "#locked?" do
    context "when the lock is held" do
      before :each do
        lock.lock
      end

      after :each do
        lock.unlock
      end

      it "returns true" do
        expect(lock.locked?).to be_truthy
      end
    end

    context "when the lock is not held" do
      it "returns false" do
        expect(lock.locked?).to be_falsey
      end
    end
  end

  context "#locked_by_me?" do
    it "correctly determines if the instance holds the lock" do
      expect(lock.locked_by_me?).to be_falsey
      lock.lock
      expect(lock.locked_by_me?).to be_truthy
      lock.unlock
      expect(lock.locked_by_me?).to be_falsey
    end

    context "when the instance has not been locked" do
      it "is a no op" do
        expect(@redis).not_to receive(:get)
        lock.locked_by_me?
      end
    end

    context "when the instance lock has expired based on the lock time" do
      it "is a no op" do
        other_lock = Redis::Lock.new(@redis, key, :auto_release_time => 1)
        other_lock.lock
        sleep(1)
        expect(@redis).not_to receive(:get)
        expect(other_lock.locked_by_me?).to be_falsey
      end

      context "but force_remote is true" do
        it "makes a redis call" do
          other_lock = Redis::Lock.new(@redis, key, :auto_release_time => 1)
          other_lock.lock
          sleep(1)
          expect(@redis).to receive(:get).once.and_return(nil)
          expect(other_lock.locked_by_me?(true)).to be_falsey
        end
      end
    end
  end
  
end
