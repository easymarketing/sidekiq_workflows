require_relative '../test_helper'
require 'active_support/time'

describe SidekiqWorkflows::Node do
  class FooWorker
    include Sidekiq::Worker
  end

  class BazWorker
    include Sidekiq::Worker
  end

  class BadWorker
    include Sidekiq::Worker
  end

  let(:workflow_uuid) { SecureRandom.uuid }
  let(:on_partial_complete) { 'dong' }

  it 'adds a child and references parent' do
    root = SidekiqWorkflows::RootNode.new(workflow_uuid: workflow_uuid, on_partial_complete: on_partial_complete)
    a = root.add_group([worker: FooWorker])
    b = a.add_group([worker: BazWorker])
    c = b.add_group([worker: BadWorker])

    expect(c.parent).must_equal b
    expect(c.children.length).must_equal 0

    expect(b.parent).must_equal a
    expect(b.children).must_equal [c]

    expect(a.parent).must_equal root
    expect(a.children).must_equal [b]

    expect(root.children).must_equal [a]

    expect(root.all_nodes.count).must_equal 4
    expect(root.all_nodes.map(&:workflow_uuid)).must_equal([workflow_uuid] * 4)
    expect(root.all_nodes.map(&:on_partial_complete)).must_equal([on_partial_complete] * 4)
  end

  describe 'build' do
    it 'should build a tree' do
      workflow = SidekiqWorkflows.build do
        perform(FooWorker, 'foo').then do
          perform(BazWorker, 'baz')
        end

        perform(BadWorker, 'bad').then do
          perform(FooWorker, 'badfoo').then do
            perform(BazWorker, 'bazfoo', delay: 30.seconds)
          end
        end
      end

      expect(workflow.children.length).must_equal 2
      expect(workflow.children[0].workers[0][:worker]).must_equal FooWorker
      expect(workflow.children[1].workers[0][:worker]).must_equal BadWorker
      expect(workflow.children[0].children[0].workers[0][:worker]).must_equal BazWorker
      expect(workflow.children[1].children[0].workers[0][:worker]).must_equal FooWorker
      expect(workflow.children[1].children[0].workers[0][:payload]).must_equal ['badfoo']
      expect(workflow.children[1].children[0].children[0].workers[0][:delay]).must_equal 30
      expect(workflow.children[1].children[0].children[0].workers[0][:worker]).must_equal BazWorker
      expect(workflow.children[1].children[0].children[0].workers[0][:payload]).must_equal ['bazfoo']
    end

    it 'should build a tree with skipping workers' do
      workflow = SidekiqWorkflows.build(except: [FooWorker]) do
        perform(FooWorker, 'foo').then do
          perform(BazWorker, 'baz')
        end

        perform(BadWorker, 'bad').then do
          perform(FooWorker, 'badfoo').then do
            perform(BazWorker, 'bazfoo')
          end
        end
      end

      expect(workflow.children.length).must_equal 2
      expect(workflow.children[0].workers[0][:worker]).must_equal BazWorker
      expect(workflow.children[1].workers[0][:worker]).must_equal BadWorker

      expect(workflow.children[0].children).must_be_empty
      expect(workflow.children[1].children[0].workers[0][:worker]).must_equal BazWorker
      expect(workflow.children[1].children[0].workers[0][:payload]).must_equal ['bazfoo']
    end

    it 'should build a tree with a group' do
      workflow = SidekiqWorkflows.build do
        perform(FooWorker, 'foo').then do
          perform(BazWorker, 'baz')
        end

        perform(BadWorker, 'bad').then do
          perform(FooWorker, 'badfoo').then do
            perform([
              {worker: BazWorker, payload: ['bazfoo'], delay: 30.seconds},
              {worker: BazWorker, payload: ['baztwo'] }
            ])
          end
        end
      end

      expect(workflow.children.length).must_equal 2
      expect(workflow.children[0].workers[0][:worker]).must_equal FooWorker
      expect(workflow.children[1].workers[0][:worker]).must_equal BadWorker

      expect(workflow.children[0].children[0].workers[0][:worker]).must_equal BazWorker
      expect(workflow.children[1].children[0].workers[0][:worker]).must_equal FooWorker
      expect(workflow.children[1].children[0].workers[0][:payload]).must_equal ['badfoo']
      expect(workflow.children[1].children[0].children[0].workers[0][:worker]).must_equal BazWorker
      expect(workflow.children[1].children[0].children[0].workers[0][:payload]).must_equal ['bazfoo']
      expect(workflow.children[1].children[0].children[0].workers[0][:delay]).must_equal(30)
      expect(workflow.children[1].children[0].children[0].workers[1][:worker]).must_equal BazWorker
      expect(workflow.children[1].children[0].children[0].workers[1][:payload]).must_equal ['baztwo']
      expect(workflow.children[1].children[0].children[0].workers[1][:delay]).must_be_nil
    end
  end

  describe '(de-)serialization' do
    it 'can be serialized and deserialized' do
      original = SidekiqWorkflows.build(workflow_uuid: workflow_uuid, on_partial_complete: on_partial_complete) do
        perform(FooWorker, 'foo').then do
          perform(BazWorker, 'baz')
        end

        perform(BadWorker, 'bad').then do
          perform([
            {worker: BazWorker, payload: ['bazfoo'], delay: 30.seconds},
            {worker: BazWorker, payload: ['baztwo']}
          ]).then do
            perform(BazWorker, 'bazfoo')
          end
        end
      end
      serialized = original.serialize
      workflow = SidekiqWorkflows.deserialize(serialized)

      expect(workflow.children.length).must_equal 2
      expect(workflow.children[0].workers[0][:worker]).must_equal FooWorker
      expect(workflow.children[1].workers[0][:worker]).must_equal BadWorker

      expect(workflow.children[0].children[0].workers[0][:worker]).must_equal BazWorker
      expect(workflow.children[0].children[0].workers[0][:delay]).must_be_nil
      expect(workflow.children[1].children[0].workers[0][:worker]).must_equal BazWorker
      expect(workflow.children[1].children[0].workers[1][:worker]).must_equal BazWorker
      expect(workflow.children[1].children[0].children[0].workers[0][:worker]).must_equal BazWorker
      expect(workflow.children[1].children[0].children[0].workers[0][:payload]).must_equal ['bazfoo']

      expect(workflow.all_nodes.map(&:workflow_uuid)).must_equal([workflow_uuid] * 6)
      expect(workflow.all_nodes.map(&:on_partial_complete)).must_equal([on_partial_complete] * 6)
    end
  end

  describe 'Worker' do
    it 'should perform async the given worker' do
      workflow = SidekiqWorkflows.build do
        perform(FooWorker, 'foo', 'bar')
      end

      FooWorker.expects(:perform_async).with('foo', 'bar')

      Sidekiq::Testing.inline! do
        SidekiqWorkflows::Worker.perform_workflow(workflow)
      end
    end

    it 'should perform async the given workers' do
      workflow = SidekiqWorkflows.build do
        perform([{worker: FooWorker, payload: ['foo', 'bar']}, {worker: BazWorker, payload: ['bar', 'foo']}])
      end

      FooWorker.expects(:perform_async).with('foo', 'bar')
      BazWorker.expects(:perform_async).with('bar', 'foo')

      Sidekiq::Testing.inline! do
        SidekiqWorkflows::Worker.perform_workflow(workflow)
      end
    end
  end
end
