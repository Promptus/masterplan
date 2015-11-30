require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

include Masterplan::DefineRules

describe "Masterplan" do
  before(:each) do
    @scheme = Masterplan::Document.new({
      "ship" => {
        :parts => [
          {
            "name" => "Mast",
            "length" => rule(12.3, :allow_nil => true),
            "material" => rule("wood", :included_in => ['wood', 'steel', 'human']),
            "scream" => rule("AAAAAAH", :matches => /[A-Z]/),
          },
          {
            "name" => "Rudder",
            "length" => nil,
            "material" => "steel",
            "scream" => "HAAAAAARGH"
          }
        ],
        rule(:flags, :optional => true) => {
          "image" => "jolly roger",
          "count" => 1
        }
      }
    })
  end

  def test_value_and_expect(testee, *error_and_descripton)
    lambda do
      Masterplan.compare(
        :scheme => @scheme,
        :to => testee
      )
    end.should raise_error(*error_and_descripton)
  end
  
  describe "Testing with #compare" do

    it "returns true for a valid document, treating symbols and strings alike" do
      Masterplan.compare(
        :scheme => @scheme,
        :to => {
          :ship => {
            :parts => [
              :name => "Thingy",
              :length => 1.0,
              :material => "human",
              :scream => "UUUUUUUUH"
            ]
          }
        }
      ).should be_true
    end

    it "complains if a key is missing" do
      test_value_and_expect(
        { :tank => {} },
        Masterplan::FailedError, /expected:	ship*\n*received:	tank/
      )
    end

    it "complains if not given a Masterplan::Document" do
      lambda do
        Masterplan.compare(
          :scheme => {},
          :to => {}
        )
      end.should raise_error(ArgumentError, /scheme needs to be a Masterplan::Document/)
    end

    it "complains if not given a proper format key" do
      lambda do
        Masterplan.compare(
          :scheme => Masterplan::Document.new({}),
          :to => {},
          :format => :medium
        )
      end.should raise_error(ArgumentError, ":format needs to be one of [:full, :mini] !")
    end

    it "complains if there are extra keys (unless they are optional)" do
      test_value_and_expect(
        { :ship => {}, :boat => {} },
        Masterplan::FailedError, /expected:	ship*\n*received:	boat,ship/
      )
    end
    
    it "complains if a value is of the wrong class" do
      test_value_and_expect(
        { :ship => [] },
        Masterplan::FailedError, /value at 'root'=>'ship' \(Array\) is not a Hash/
      )
    end

    it "complains if a value is nil" do
      test_value_and_expect(
        { :ship => {:parts => [{:name => nil, :length => 1.0, :material => "wood", :scream => "BLEEEEERGH"}]} },
        Masterplan::FailedError, /value at 'root'=>'ship'=>'parts'=>'0'=>'name' \(NilClass\) is not a String/
      )
    end

    context "ignoring elements" do
      before(:each) do
        @scheme = Masterplan::Document.new({
          "name" => "bla",
          "crew_members" => rule({}, :ignore => true)
        })
      end

      it "ignores any keys and values in the ignored hash" do
        Masterplan.compare(
          :scheme => @scheme,
          :to => {"name" => "bla", "crew_members" => {"bla" => "blub"}}
        ).should be_true

        Masterplan.compare(
          :scheme => @scheme,
          :to => {"name" => "bla", "crew_members" => {}}
        ).should be_true
      end

    end

    context "optional keys" do

      it "complains if a value is nil when in an optional but given value" do
        test_value_and_expect(
          {
            :ship => {
              :parts => [
                :name => "Thingy",
                :length => 1.0,
                :material => "human",
                :scream => "UUUUUUUUH"
              ],
              :flags => {
                "image" => nil,
                "count" => 1
              }
            }
          },
          Masterplan::FailedError, /value at 'root'=>'ship'=>'flags'=>'image' \(NilClass\) is not a String/
        )
      end

      it "complains if keys don't match up when in an optional but given value" do
        test_value_and_expect(
          {
            :ship => {
              :parts => [
                :name => "Thingy",
                :length => 1.0,
                :material => "human",
                :scream => "UUUUUUUUH"
              ],
              "flags" => {
                "count" => 1
              }
            }
          },
          Masterplan::FailedError, /expected:	count,image*\n*received:	count/
        )
      end
      
      context "with subsets of mandatory and optional keys" do
        before(:each) do
          @multi_scheme = Masterplan::Document.new({
            :mandatory_1 => "aaa",
            :mandatory_2 => "aaa",
            rule(:optional_1, :optional => true)  => "aaa",
            rule(:optional_2, :optional => true)  => "aaa",
          })
        end

        it "doesn't complain when all keys are given" do
          Masterplan.compare(
            :scheme => @multi_scheme,
            :to => {
              :mandatory_1 => "aaa",
              :mandatory_2 => "aaa",
              :optional_1  => "aaa",
              :optional_2  => "aaa",
            }
          ).should be_true
        end

        it "doesn't complain when only mandatory keys are given" do
          Masterplan.compare(
            :scheme => @multi_scheme,
            :to => {
              :mandatory_1 => "aaa",
              :mandatory_2 => "aaa",
            }
          ).should be_true
        end

        it "doesn't complain when only some optional keys are given" do
          Masterplan.compare(
            :scheme => @multi_scheme,
            :to => {
              :mandatory_1 => "aaa",
              :mandatory_2 => "aaa",
              :optional_2  => "aaa"
            }
          ).should be_true
        end

        it "complains when one mandatory key is missing" do
          lambda do
            Masterplan.compare(
              :scheme => @multi_scheme,
              :to => {:optional_1 => "aa", :optional_2 => "aaa", :mandatory_2 => "aaa"}
            )
          end.should raise_error(Masterplan::FailedError, /expected:	mandatory_1,mandatory_2*\n*received:	mandatory_2,optional_1,optional_2/)
        end

        it "complains when all mandatory keys are missing" do
          lambda do
            Masterplan.compare(
              :scheme => @multi_scheme,
              :to => {:optional_1 => "aa", :optional_2 => "aaa"}
            )
          end.should raise_error(Masterplan::FailedError, /expected:	mandatory_1,mandatory_2*\n*received:/)
        end

        it "complains when everything is missing" do
          lambda do
            Masterplan.compare(
              :scheme => @multi_scheme,
              :to => {}
            )
          end.should raise_error(Masterplan::FailedError, /expected:	mandatory_1,mandatory_2*\n*received:/)
        end
      end
    end

    it "does not complain if a value is nil and the rule allows nil" do
      Masterplan.compare(
          :scheme => @scheme,
          :to => { :ship => {:parts => [{:name => "haha", :length => nil, :material => "wood", :scream => "UUUUAUAUAUAH"}]} }
     ).should == true
    end

    it "complains if a value does not match the regexp rule" do
      test_value_and_expect(
        { :ship => {:parts => [{:name => "thing", :length => 1.0, :material => "wood", :scream => "omai !"}]} },
        Masterplan::FailedError, /value at 'root'=>'ship'=>'parts'=>'0'=>'scream' "omai !" \(String\) does not match \/\[A-Z\]\//
      )
    end

    it "complains if a value is not included in the rule list" do
      test_value_and_expect(
        { :ship => {:parts => [{:name => "thing", :length => 1.0, :material => "socks", :scream => "GRAGRAGR"}]} },
        Masterplan::FailedError, /value at 'root'=>'ship'=>'parts'=>'0'=>'material' "socks" \(String\) is not one of \["wood", "steel", "human"\]/
      )
    end
    
    it "complains if literal option is used and value is not equal to example" do
      # All ships must be named Black Pearl
      @scheme = Masterplan::Document.new({
        "ship" => { :name => rule("Black Pearl", :literal => true) }
      })
      test_value_and_expect(
        {:ship => {:name => "Blank Earl"}},
        Masterplan::FailedError, /value at 'root'=>'ship'=>'name' "Blank Earl" \(String\) is not equal to "Black Pearl"/
      )
      Masterplan.compare(
        :scheme => @scheme,
        :to => {:ship => {:name => "Black Pearl"}}
      ).should be_true
    end

    [nil, :full].each do |format|
      it "produces full output for format = #{format}" do
        lambda do
          Masterplan.compare(
            :scheme => @scheme,
            :to => { :ship => [] },
            :format => format
          )
        end.should raise_error(
          /value at 'root'=>'ship' \(Array\) is not a Hash !\n\s*?Expected:.*?but was/m
        )
      end
    end

    it "produces one-line output when using :mini format" do
      lambda do
        Masterplan.compare(
          :scheme => @scheme,
          :to => { :ship => [] },
          :format => :mini
        )
      end.should raise_error(
        "value at 'root'=>'ship' (Array) is not a Hash !"
      )
    end

    it "checks all values of value arrays, but only against the first array value of the scheme"
    it "checks all array values one-to-one if the compare_each rule is used"
  end

  it "converts into plain example hashes" do
    @scheme.to_hash.should == {
      "ship" => {
        :parts => [
          {
            "name" => "Mast",
            "scream" => "AAAAAAH",
            "length" => 12.3,
            "material" => "wood"
          },
          {
            "name" => "Rudder",
            "scream" => "HAAAAAARGH",
            "length" => nil,
            "material" => "steel"
          }
        ],
        :flags => {
          "image" => "jolly roger",
          "count" => 1
        }
      }
    }
  end
  it "doesn't create a Document out of anything other than a Hash"
  it "checks that the examples of rules obey the rules"
  it "has a unit test extension method"
end
