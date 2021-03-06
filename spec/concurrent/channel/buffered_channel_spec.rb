require 'spec_helper'

module Concurrent

  describe BufferedChannel do

    let(:size) { 2 }
    let!(:channel) { BufferedChannel.new(size) }
    let(:probe) { Channel::Probe.new }

    context 'without timeout' do

      describe '#push' do
        it 'adds elements to buffer' do
          channel.buffer_queue_size.should be 0

          channel.push('a')
          channel.push('a')

          channel.buffer_queue_size.should be 2
        end

        it 'should block when buffer is full' do
          channel.push 1
          channel.push 2

          t = Thread.new { channel.push 3 }
          sleep(0.05)
          t.status.should eq 'sleep'
        end

        it 'restarts thread when buffer is no more full' do
          channel.push 'hi'
          channel.push 'foo'

          result = nil

          Thread.new { channel.push 'bar'; result = 42 }

          sleep(0.1)

          channel.pop

          sleep(0.1)

          result.should eq 42
        end

        it 'should assign value to a probe if probe set is not empty' do
          channel.select(probe)
          Thread.new { sleep(0.1); channel.push 3 }
          probe.value.should eq 3
        end
      end

      describe '#pop' do
        it 'should block if buffer is empty' do
          t = Thread.new { channel.pop }
          sleep(0.05)
          t.status.should eq 'sleep'
        end

        it 'returns value if buffer is not empty' do
          channel.push 1
          result = channel.pop

          result.should eq 1
        end

        it 'removes the first value from the buffer' do
          channel.push 'a'
          channel.push 'b'

          channel.pop.should eq 'a'
          channel.buffer_queue_size.should eq 1
        end
      end

    end

    describe 'select' do

      it 'does not block' do
        t = Thread.new { channel.select(probe) }

        sleep(0.05)

        t.status.should eq false
      end

      it 'gets notified by writer thread' do
        channel.select(probe)

        Thread.new { channel.push 82 }

        probe.value.should eq 82
      end

    end

    context 'already set probes' do
      context 'empty buffer' do
        it 'discards already set probes' do
          probe.set('set value')

          channel.select(probe)

          channel.push 27

          channel.buffer_queue_size.should eq 1
          channel.probe_set_size.should eq 0
        end
      end

      context 'empty probe set' do
        it 'discards set probe' do
          probe.set('set value')

          channel.push 82

          channel.select(probe)

          channel.buffer_queue_size.should eq 1

          channel.pop.should eq 82

        end
      end
    end

    describe 'probe set' do

      it 'has size zero after creation' do
        channel.probe_set_size.should eq 0
      end

      it 'increases size after a select' do
        channel.select(probe)
        channel.probe_set_size.should eq 1
      end

      it 'decreases size after a removal' do
        channel.select(probe)
        channel.remove_probe(probe)
        channel.probe_set_size.should eq 0
      end

    end

  end
end
