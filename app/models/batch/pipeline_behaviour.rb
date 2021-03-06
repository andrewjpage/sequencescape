module Batch::PipelineBehaviour
  def self.included(base)
    base.class_eval do
      # The associations with the pipeline
      belongs_to :pipeline
      attr_protected :pipeline_id
      delegate :workflow, :item_limit, :multiplexed?, :to => :pipeline
      delegate :tasks, :to => :workflow

      # The validations that the pipeline & batch are correct
      validates_presence_of :pipeline

      validates_each(:requests, :allow_blank => true) do |batch, attr, requests|
        pipeline = batch.pipeline
        unless pipeline.nil?
          batch.errors.add(attr, 'too many requests specified') if not pipeline.max_size.nil? and requests.size > pipeline.max_size

          # DISABLED AS THERE IS CODE THAT DOESN'T OBEY THIS RULE IN CHERRYPICKING
          #batch.errors.add(attr, 'has incorrect type')          if requests.map(&:request_type_id).uniq != [ pipeline.request_type_id ]
        end
      end
    end
  end

  def externally_released?
    workflow.source_is_internal? && self.released?
  end

  def internally_released?
    workflow.source_is_external? && self.released?
  end
  
  def show_actions?
    return true if pipeline.is_a?(PulldownMultiplexLibraryPreparationPipeline) || pipeline.is_a?(CherrypickForPulldownPipeline)
    !released?
  end

  def has_item_limit?
    self.item_limit.present?
  end
  alias_method(:has_limit?, :has_item_limit?)

  def events_for_completed_tasks
    self.lab_events.select{ |le| le.description == "Complete" }
  end

  def tasks_for_completed_task_events(events)
    completed_tasks = []
    events.each do |event|
      task_id = event.descriptors.detect{ |d| d.name == "task_id" }
      if task_id
        begin
          task = Task.find(task_id.value)
        rescue ActiveRecord::RecordNotFound
          return []
        end
        unless task.nil?
          completed_tasks << task
        end
      end
    end
    completed_tasks
  end

  def last_completed_task
    unless self.events_for_completed_tasks.empty?
      completed_tasks = self.tasks_for_completed_task_events(self.events_for_completed_tasks)
      tasks = self.pipeline.workflow.tasks
      tasks.sort!{ |a, b| b.sorted <=> a.sorted }
      tasks.each do |task|
        if completed_tasks.include?(task)
          return task
        end
      end
      return nil
    end
  end

  def task_for_event(event)
    tasks.detect { |task| task.name == event.description }
  end

end
