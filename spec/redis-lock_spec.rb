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
      @redis.get("lock:#{key}").should_not be_nil
    end

    context "when a block is provided" do
      it "locks before yielding and releases after" do
        lock.lock do |l|
          l.should == lock
          @redis.get("lock:#{key}").should_not be_nil
        end
        @redis.get("lock:#{key}").should be_nil
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
          (Time.now - time).should be_within(0.1).of(2.0)
          e.should be_a(Redis::Lock::AcquireLockTimeOut)
        end
      end
    end

    context "when initialized with auto_release_time" do
      it "sets the redis key with an appropriate expiration" do
        other_lock = Redis::Lock.new(@redis, key, :auto_release_time => 7)
        @redis.should_receive(:set).with("lock:#{key}", an_instance_of(String), :nx => true, :ex => 7).and_return(true)
        other_lock.lock
      end
    end

    context "when initialized with base_sleep" do
      it "retries with exponential back off starting at base_sleep millis" do
        other_lock = Redis::Lock.new(@redis, key, :base_sleep => 25)
        other_lock.should_receive(:sleep).with(0.025).ordered
        other_lock.should_receive(:sleep).with(0.05).ordered
        other_lock.should_receive(:sleep).with(0.1).ordered
        other_lock.should_receive(:sleep).with(0.2).ordered
        other_lock.should_receive(:sleep) do |sleep_time|
          sleep_time.should == 0.4
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
      @redis.get("lock:#{key}").should be_nil
    end

    it "should not delete a lock held by another instance" do
      other_lock = Redis::Lock.new(@redis, key, :auto_release_time => 1)
      other_lock.lock
      sleep(1.1)
      lock.lock
      other_lock.unlock
      @redis.get("lock:#{key}").should_not be_nil
    end

    context "when the instance has not been locked" do
      it "is a no op" do
        @redis.should_not_receive(:eval)
        lock.unlock
      end
    end

    context "when the instance lock has expired based on the lock time" do
      it "is a no op" do
        other_lock = Redis::Lock.new(@redis, key, :auto_release_time => 1)
        other_lock.lock
        sleep(1)
        @redis.should_not_receive(:eval)
        other_lock.unlock
      end

      context "but force_remote is true" do
        it "makes a redis call" do
          other_lock = Redis::Lock.new(@redis, key, :auto_release_time => 1)
          other_lock.lock
          sleep(1)
          @redis.should_receive(:eval).with(Redis::Lock::UNLOCK_LUA_SCRIPT, ["lock:#{key}"], instance_of(Array)).once
          other_lock.unlock(true)
        end
      end
    end
  end

  context "#locked?" do
    it "correctly determines if the instance holds the lock" do
      lock.locked?.should be_false
      lock.lock
      lock.locked?.should be_true
      lock.unlock
      lock.locked?.should be_false
    end

    context "when the instance has not been locked" do
      it "is a no op" do
        @redis.should_not_receive(:eval)
        lock.unlock
      end
    end

    context "when the instance lock has expired based on the lock time" do
      it "is a no op" do
        other_lock = Redis::Lock.new(@redis, key, :auto_release_time => 1)
        other_lock.lock
        sleep(1)
        @redis.should_not_receive(:get)
        other_lock.locked?.should be_false
      end

      context "but force_remote is true" do
        it "makes a redis call" do
          other_lock = Redis::Lock.new(@redis, key, :auto_release_time => 1)
          other_lock.lock
          sleep(1)
          @redis.should_receive(:get).once.and_return(nil)
          other_lock.locked?(true).should be_false
        end
      end
    end
  end
  
end