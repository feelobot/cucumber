module Cucumber
  module Ast
    class ScenarioOutline
      include FeatureElement
      
      attr_writer :background
      attr_writer :feature

      # The +example_sections+ argument must be an Array where each element is another array representing
      # an Examples section. This array has 3 elements:
      #
      # * Examples keyword
      # * Examples section name
      # * Raw matrix
      def initialize(comment, tags, line, keyword, name, steps, example_sections)
        @comment, @tags, @line, @keyword, @name, @steps = comment, tags, line, keyword, name, steps
        attach_steps(steps)

        @examples_array = example_sections.map do |example_section|
          examples_line       = example_section[0]
          examples_keyword    = example_section[1]
          examples_name       = example_section[2]
          examples_matrix     = example_section[3]

          examples_table = OutlineTable.new(examples_matrix, self)
          Examples.new(examples_line, examples_keyword, examples_name, examples_table)
        end
      end

      def at_lines?(lines)
        super || @examples_array.detect { |examples| examples.at_lines?(lines) }
      end

      def accept(visitor)
        visitor.visit_comment(@comment)
        visitor.visit_tags(@tags)
        visitor.visit_scenario_name(@keyword, @name, file_line(@line), source_indent(text_length))
        visitor.visit_steps(steps)

        @examples_array.each do |examples|
          visitor.visit_examples(examples)
        end
      end

      def each_example_row(&proc)
        @examples_array.each do |examples|
          examples.each_example_row(&proc)
        end
      end

      # TODO: Move to Steps and remove @steps here
      def execute_row(cells, visitor, &proc)
        exception = nil

        previous_status = @background.status
        argument_hash = cells.to_hash
        cell_index = 0
        @steps.each do |step|
          executed_step, previous_status, matched_args = 
            step.execute_with_arguments(argument_hash, @background.world, previous_status, visitor, cells[0].line)
          # There might be steps that don't have any arguments
          # If there are no matched args, we'll still iterate once
          matched_args = [nil] if matched_args.empty?

          matched_args.each do
            cell = cells[cell_index]
            if cell
              proc.call(cell, previous_status)
              cell_index += 1
            end
          end
          exception ||= executed_step.exception
        end
        visitor.scenario_executed(self)
        exception
      end

      def pending? ; false ; end

      def to_sexp
        sexp = [:scenario_outline, @keyword, @name]
        comment = @comment.to_sexp
        sexp += [comment] if comment
        tags = @tags.to_sexp
        sexp += tags if tags.any?
        steps = @steps.map{|step| step.to_sexp}
        sexp += steps if steps.any?
        sexp += @examples_array.map{|e| e.to_sexp}
        sexp
      end

      private
      
      def steps
        @step_collection ||= StepCollection.new(@steps)
      end
    end
  end
end
