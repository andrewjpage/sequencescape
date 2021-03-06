require "test_helper"

class WorkflowsController
  attr_accessor :batch, :tags, :workflow, :stage
end

class AssignTagsTaskTest < TaskTestBase
  context AssignTagsTask do
    setup do
      # TODO: none of this code tests failure conditions as that causes crashes
      # Basically 'flash' is pulled from 'session[:flash]' which is not configured properly on @workflow
      # @workflow needs 'workflow' and 'stage' set
      # @workflow does not like redirect_to (think this might be shoulda)
      @workflow  = WorkflowsController.new

      @br        = Factory :batch_request
      @task      = Factory :assign_tags_task
      @tag_group = Factory :tag_group
      @tag       = Factory :tag, :tag_group => @tag_group

    end

    expected_partial('assign_tags_batches')

    context "check tags group" do
      should "valid" do
        assert_not_equal [], @tag_group.tags
        assert_equal @tag, @tag_group.tags.find(@tag.id)
      end
    end

    context "#render_task" do
      setup do
        @workflow.batch = @br.batch
        params = { :tag_group => @tag_group.id }
        @task.render_task(@workflow, params)
      end

      should "render a specific template" do
        assert_equal @tag_group.tags, @workflow.tags
      end
    end

    context "#do_task" do
      setup do
        @pipeline       = Factory :pipeline, :request_type_id => 1
        @batch          = Factory :batch, :pipeline => @pipeline
        # TODO: Move this into factory. Create library and sample_tube factory
        @sample_tube    = Factory :asset, :sti_type => "SampleTube"
        @library        = Factory :asset, :sti_type => "LibraryTube"
        @sample_tube.children << @library

        @mx_request     = Factory :request, :request_type_id => 1, :submission_id => 1, :asset => @sample_tube, :target_asset => @library
        @cf_request     = Factory :request, :request_type_id => 2, :submission_id => 1, :asset => nil
        @batch.requests << [@mx_request, @cf_request]
        @workflow.batch = @batch

        params = { :tag_group => @tag_group.id.to_s,
                   :mx_library_name => "MX library",
                   :tag => { @mx_request.id.to_s => @tag.id.to_s } }
        @task.do_task(@workflow, params)
      end

      should "have requests in batch" do
        assert_equal 2, @workflow.batch.request_count
      end

      should_change("MultiplexedLibraryTube.count", :by => 1) { MultiplexedLibraryTube.count }
      should_change("AssetLink.count", :by => 5) { AssetLink.count }
      should_change("TagInstance.count", :by => 1) { TagInstance.count }

      should "should update library" do
        assert_equal 1, @sample_tube.children.size

        # Related to sample tube and tag instance
        assert_equal 2, @library.parents.size
        parents = @library.parents.map { |x| x.id}
        assert parents.include?(@sample_tube.id)
        assert parents.include?(TagInstance.last.id)

        assert_equal 1, MultiplexedLibraryTube.last.parents.size
        assert_equal LibraryTube.find(@library.id),  MultiplexedLibraryTube.last.parent

      end

    end
  end
end
