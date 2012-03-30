require 'active_support'
require 'active_support/version'
if ActiveSupport::VERSION::STRING >= "3.0.0"
  require 'active_support/core_ext'
end
require 'test/unit/assertions'
require 'masterplan'
require 'masterplan/rule'
require 'masterplan/document'
require 'masterplan/define_rules'
require 'unit_test_extensions'
module Masterplan

  class FailedError < Test::Unit::AssertionFailedError
    attr_accessor :printed
  end

  class << self

    def compare(options = {:scheme => {}, :to => {}, :format => :full})
      scheme = options[:scheme]
      testee = options[:to]
      format = options[:format] || :full
      raise ArgumentError, ":to needs to be a hash !" unless testee.is_a?(Hash)
      raise ArgumentError, ":scheme needs to be a Masterplan::Document !" unless scheme.is_a?(Document)
      raise ArgumentError, ":format needs to be one of [:full, :mini] !" unless [:full, :mini].include?(format)
      compare_hash(scheme, testee, format)
      true
    end

    private

    def compare_value(template, value, path)
      if template.is_a?(Rule)
        template.masterplan_compare(value, path)
      else
        Rule.check_class_equality!(template, value, path)
      end
    end

    def compare_hash_keys(template, testee, trail)
      mandatory_keys = []
      optional_keys = []
      template.keys.each do |key|
        if key.is_a?(Masterplan::Rule) && key.options["optional"]
          optional_keys << key.example_value.to_s
        else
          mandatory_keys << key.to_s
        end
      end
      failed = false
      testee.stringify_keys!
      if((mandatory_keys - testee.keys).size > 0) # missing keys
        failed = true
      else
        extra_keys = (testee.keys - mandatory_keys)
        if extra_keys.size > 0 && extra_keys.sort != optional_keys.sort
          failed = true
        end
      end
      if failed
        raise FailedError, "keys don't match in #{format_path(trail)}:\nexpected:\t#{mandatory_keys.sort.join(',')}\nreceived:\t#{testee.keys.sort.join(',')}"
      end
    end

    def compare_hash(template, testee, format, trail = ["root"])
      compare_hash_keys(template, testee, trail)
      template.each do |t_key_or_rule, t_value|
        key_is_optional = t_key_or_rule.is_a?(Masterplan::Rule) && t_key_or_rule.options["optional"]
        t_key = if key_is_optional
          t_key_or_rule.example_value
        else
          t_key_or_rule
        end
        current_path = trail + [t_key]
        value = testee[t_key]
        compare_value(t_value, value, format_path(current_path)) unless key_is_optional and value.nil?
        if value && t_value.is_a?(Array)
          # all array elements need to be of the same type as the first value in the template
          elements_template = t_value.first
          value.each_with_index do |elements_value, index|
            array_path = current_path + [index]
            compare_value(elements_template, elements_value, format_path(array_path))
            if elements_value.is_a?(Hash)
              compare_hash(elements_template, elements_value, format, array_path)
            end
          end
        end
        if value.is_a?(Array) && t_value.is_a?(Rule) && t_value.options['compare_each']
          value.each_with_index do |elements_value, index| 
            elements_template = t_value.example_value[index]
            array_path = current_path + [index]
            compare_value(elements_template, elements_value, format_path(array_path))
            if elements_value.is_a?(Hash)
              compare_hash(elements_template, elements_value, format, array_path)
            end
          end
        end
        if value.is_a?(Hash)
          if t_value.is_a?(Masterplan::Rule)
            compare_value(t_value, value, current_path)
            compare_hash(t_value.example_value, value, format, current_path)
          else
            compare_hash(t_value, value, format, current_path)
          end
        end
      end

    rescue Masterplan::FailedError => e
      raise e if e.printed

      error = Masterplan::FailedError.new
      error.printed = true

      if format == :mini
        raise error, e.message, caller
      else
        expected = PP.pp(template, '')
        outcome = PP.pp(testee, '')

        raise error, "#{e.message}\n\nExpected:\n#{expected}\n\nbut was:\n#{outcome}", caller
      end
    end

    def format_path(trail)
      "'" + trail.join("'=>'") + "'"
    end
  end
end
