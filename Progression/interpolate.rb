XXX::bof(__FILE__)
require 'sketchup.rb'
require_relative 'enum.rb'
require_relative 'assert.rb'
require_relative 'debug.rb'

module AFH

    ## INTERPOLATE begin
    END_ENUM        = Enum_type.new "END_ENUM", :rotate, :translate, :both
    END_ROTATE      = END_ENUM.enum_const :rotate   
    END_TRANSLATE   = END_ENUM.enum_const :translate
    END_BOTH        = END_ENUM.enum_const :both    
    
    WHICH_1ST_ENUM  = Enum_type.new "WHICH_1ST_ENUM", :rotate, :translate
    FIRST_ROTATE    = WHICH_1ST_ENUM.enum_const :rotate
    FIRST_TRANSLATE = WHICH_1ST_ENUM.enum_const :translate
    
    class Interpolate
        include AFH

        attr_reader :translation_segment_count, :rotation_segment_count   
        # segments is how many translation inner_segment_count there are.
        def initialize(t1, t2, rotation_point, inner_segment_count, start_with, finish_with, which_1st, debug: false)
            puts indent var_s(:start_with, :finish_with, :which_1st){|_|eval _};
            Assert(ArgumentError){ True?(inner_segment_count > 0) { "inner_segment_count must be > 0."} }
            END_ENUM.assert_compariable(start_with, error_type: ArgumentError);
            END_ENUM.assert_compariable(finish_with, error_type: ArgumentError);
            WHICH_1ST_ENUM.assert_compariable(which_1st, error_type: ArgumentError);
            wrap(debug) {
            # The number represents the inner_segment_count.
            # A 'T' or 'R' represents that a translation or rotation will occur
            # and how many times in that block.  They DO NOT represent the
            # order in which they occur.  Order is done in one shot with all
            # rotations grouped together and all translations grouped together.
            # The order in which each group is applied first is controlled by
            # which_1st.
            #
            #   sr = start with rotate     fr = finish with rotate
            #   st = start with translate  ft = finish with translate
            # 
            #           | fr & !ft      | !fr & ft      | !fr & !ft     |
            # ----------+---------------+---------------+---------------+
            # sr & !st  | 1  R   TR   R | 1  R   TR   T | 1  R   TR     |  
            #           | 2  R  TRTR  R | 2  R  TRTR  T | 2  R  TRTR    |  
            #           | 3  R TRTRTR R | 3  R TRTRTR T | 3  R TRTRTR   |  
            # ----------+---------------+---------------+---------------+
            # !sr & st  | 1  T   TR   R | 1  T   TR   T | 1  T   TR     |
            #           | 2  T  TRTR  R | 2  T  TRTR  T | 2  T  TRTR    |
            #           | 3  T TRTRTR R | 3  T TRTRTR T | 3  T TRTRTR   |
            # ----------+---------------+---------------+---------------+
            # !sr & !st | 1      TR   R | 1      TR   T | 1      TR     |  
            #           | 2     TRTR  R | 2     TRTR  T | 2     TRTR    |  
            #           | 3    TRTRTR R | 3    TRTRTR T | 3    TRTRTR   |  
            # ----------+---------------+---------------+---------------+
            #
            # Note that sr & st == !sr & !st and fr & ft == !fr & !ft, and is
            # why those rows and columns are missing.
            
            @rotation_segment_count = @translation_segment_count = inner_segment_count
            @translation_segment_count += 1 if start_with  == END_TRANSLATE
            @translation_segment_count += 1 if finish_with == END_TRANSLATE
            @rotation_segment_count    += 1 if start_with  == END_ROTATE
            @rotation_segment_count    += 1 if finish_with == END_ROTATE

            @start_with  = start_with 
            @finish_with = finish_with
            @which_1st   = which_1st
            
            Debug(debug) { puts indent "t1 = #{to_ts t1}" }
            Debug(debug) { puts indent "t2 = #{to_ts t2}" }
            # translation calculation
            @translate_info = lm_translation(t1, t2)

            # rotate calculation
            # translate t1 to origin, rotate, translate back
            # translate t1 to origin, rotate, translate back is the same as rotate t1 around lm_origin_point(t1)
            # rotate t1 around lm_origin_point(t1)
            @rotate_info = lm_rotation(t1, t2, rotation_point, debug: debug)

            @t1 = t1 # needed to premultiply rotation/translation matrices
            @t2 = t2 # only needed for verification and maybe to remove rounding errors for final transform.
            Debug(debug) { puts indent "@translate_info = #{@translate_info}" }
            Debug(debug) { puts indent "@rotate_info = #{@rotate_info}"       }

            @rotation     = generate_transforms(@rotate_info, 1.0/ (@rotation_segment_count-1)).reduce(IDENTITY, :*)
            @translation  = generate_transform(@translate_info, 1.0/(@translation_segment_count-1))
            puts indent "#{1.0/(@rotation_segment_count-1)}  @rotation     = #{to_ts @rotation}"
            puts indent "@translation  = #{to_ts @translation}"

            # +1 because 0 is t1
            @length = [@rotation_segment_count, @translation_segment_count].max + 1
            case @start_with
            when END_ROTATE
                @first_rotation    = IDENTITY
                @first_translation = @translation
            when END_TRANSLATE
                @first_rotation    = @rotation
                @first_translation = IDENTITY
            else # END_BOTH
                @first_rotation    = IDENTITY
                @first_translation = IDENTITY
            end
            
            case @finish_with
            when END_TRANSLATE
                @last_rotation    = IDENTITY
                @last_translation = @translation
            when END_ROTATE
                @last_rotation    = @rotation
                @last_translation = IDENTITY
            else # END_BOTH
                @last_rotation    = IDENTITY
                @last_translation = IDENTITY
            end
            puts "HERE!", var_s(:@start_with, :@finish_with, :@last_rotation,  :@first_rotation,  :@last_translation,  :@first_translation,  :t1){|_|eval _}
            test_equal(lm_origin_point(@last_rotation * @first_rotation * @last_translation * @first_translation * t1), lm_origin_point(t2), "t1 doesn't translate origin to t2.")
            test_equal(@last_rotation * @first_rotation * @last_translation * @first_translation * t1, t2, "t1 doesn't translate and rotate to t2.")
            test_equal(lm_origin_point(self[-1]), lm_origin_point(t2), "(a) t1 doesn't translate origin to t2.")
            test_equal(self[-1], t2, "(a) t1 doesn't translate and rotate to t2.")
            }
        end

        # number of transforms needed
        def length
            @length
        end

        def [](i)
            wrap {
            puts indent var_s(:i){|e| eval e}
            Assert { True?(i < @length) { "Index #{i} exceeds bounds of array.  Array size is #{@length}."} }
            if i < 0
                i += @length # negative value means start at end and go towards beginning.
            end
            Assert { True?(i >= 0) { "Negative index #{i - @length} exceeds bounds of array.  Array size is #{@length}."} }
            # I may optimize later, so that if the index is one greater than
            # the last, I can just do a single multipliaion.  This may be useful
            # for large segment values.
            #return pow_positive(@translation, i) * @t1
            if i == 0
                @t1
            else
                translate = @first_translation
                rotate    = @first_rotation
                i -= 1
                puts indent var_s(:i, :@length) {|_|eval _}
                if i < @length
                    translate *= pow_positive(@translation, i)
                    rotate    *= pow_positive(@rotation, i)
                end
                if i == @length
                    translate *= @last_translation
                    rotate    *= @last_rotation
                end
                if @which_1st == FIRST_TRANSLATE
                    rotate * translate * @t1
                else
                    translate * rotate * @t1
                end
            end
            }
        end
        
        def each
            @length.times { |i| yield self[i] }
        end

        def arrives_at_t2?
            transform_equal?(self[@length - 1] * @t1, @t2)
        end

        def to_s
            var_s(:t1, :t1, :translate_info, :rotate_info) {|_|eval _}
        end
    end
    ## INTERPOLATE end
    
end
XXX::eof(__FILE__)