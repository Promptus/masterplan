module Masterplan

  # Include this module into whatever code generates Masterplan::Documents - you get
  # methods that make it easier to generate Masterplan::Rule objects.
  module DefineRules

    # This turns the supplied +example_value+ (any object) into an object that carries rules about itself with it.
    # The rules will be applied when a template is compared with assert_masterplan or Masterplan.compare. Rules are:
    # (default): This always applies - the value must be of the same class as the +example_value+
    # 'allow_nil': This allows the value to be nil (breaking the first rule)
    # 'compare_each': Normally, when an example contains an Array, only the first entry in the Array is used as a rule against
    #                 all values. When using this rule, each value element must match the corresponding rule element, allowing you
    #                 to set up different rules for each Array element.
    # 'included_in': Pass an array of values - the value must be one of these
    # 'matches': Pass a regexp - the value must match it, and be a String
    # 'literal': Values must be the same as the rule (using good 'ol == )
    #
    # There is one special rule that only works on hash keys:
    # 'optional' : This makes the hash key optional, i.e. no error will occur if the key (and its value) are missing.
    def rule(example_value, options = {})
      Rule.new(example_value, options)
    end

    # Shorthand for rule("bla", :compare_each => true)
    def iterating_rule(example_value, options = {})
      if example_value
        Rule.new(example_value, :compare_each => true) 
      end
    end

  end

end
