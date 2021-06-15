#$LOAD_PATH << File.join(File.dirname(__FILE__), "Progression")
module AFH; end
module XXX
    class<< self
    @@debug = true
    @@indent_count = 1
    def inc; @@indent_count += 1; end
    def dec; @@indent_count -= 1; end
    def clear; @@indent_count = 0; end
    def indent(s=nil, char: '|', indent_count: @@indent_count)
        if s.nil?
            char * indent_count# + " "
        else
            s = s.to_s
            raise RuntimeError, "s is #{s.class.name}" if s.class.name != "String"
            s.gsub(/^|(?<=\n)/, indent(nil, char: char, indent_count: indent_count))
        end
    end
    @@added_methods = AFH.methods - Object.methods 
    @@last_added_methods = []
    def newly_added_methods
        @@added_methods = AFH.methods - Object.methods - @@last_added_methods
        @@last_added_methods.concat @@added_methods
        @@added_methods
    end
    def added_methods
        AFH.methods - Object.methods
    end
    @@added_instance_methods = AFH.instance_methods
    @@last_added_instance_methods = []
    def newly_added_instance_methods
        @@added_instance_methods = AFH.instance_methods -  @@last_added_instance_methods
        @@last_added_instance_methods.concat @@added_instance_methods
        @@added_instance_methods
    end
    def added_instance_methods
        AFH.instance_methods
    end
    def strip(file)
        file.sub(/^.*\/plugins\//i, "")
    end
    def bof(file)
        puts "v" * 80
        puts indent(strip(file) + "\n"\
            "Added methods #{added_methods}\n"\
            "Added instance methods #{added_instance_methods}", char: ">")
        inc
        nil
    end
    def eof(file)
        dec
        puts indent(strip(file) + "\n"\
            "Newly added methods #{newly_added_methods}\n"\
            "Newly added instance methods #{newly_added_instance_methods}", char: "<")
        puts "^" * 80
        nil
    end
    def puts_(*s)
        s.each{|e| puts indent e}
        nil
    end
    end # class << self
end

puts "#{self.class.method 'require'}"
puts "#{self.class.method 'require_relative'}"

def require(path)
  XXX::puts_ "require: (#{path}) #{caller[0]}"
  #super
  Kernel.require path
end

# This doesn't work like the function above for some reason.
# def require_relative(path)
  # XXX::puts_ "require_relative: (#{path}) #{caller[0]}"
  # #super
  # Kernel.require_relative path
# end

puts "#{self.class.method 'require'}"
puts "#{self.class.method 'require_relative'}"
 
XXX::bof(__FILE__)
module AFH
    # By not putting this in the class << self; end block, this function will
    # become part of the methods mixed into a class when using include directive.
    # This has to be added before any require/require_relative call, so that
    # if there are any AFH calls, they will be redirected correctly.
    
    # If the function cannot be found in this class, then check ::AFH.
    def method_missing(method, *args, &block)
        puts "Found methods: #{AFH::methods.select {|e|e.match /#{match}/}.to_s}"
        if AFH.respond_to?(method)
            AFH.send(method, *args, &block)
        else
            super
        end
    end
end
XXX::eof(__FILE__)

XXX::bof(__FILE__)
require 'sketchup.rb'
require 'progression/progression.rb'

module AFH
    class << self
    # show ruby console
    SKETCHUP_CONSOLE.show

    puts "Loaded " + __FILE__
    if !self.respond_to?(:reload)
        # Will eventually need to use this
        # extension = SketchupExtension.new('Progression', 'progression/progression')

        # Menu item
        UI.menu("Plugins").add_item("Reload") {
            AFH.reload
        }

        UI.menu("Plugins").add_item("Progression") {
            AFH.progression_tool
        }
    end

    def suspend_verbose
        original_verbose = $VERBOSE
        $VERBOSE = nil
        yield
        
        rescue
        puts callstack
        raise
        
        ensure
        $VERBOSE = original_verbose
    end
    
    # Reload extension by running this method from the Ruby Console:
    #   Example::HelloWorld.reload
    def reload
        suspend_verbose do
            file = File.realpath(__FILE__)
            puts "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n\nLoading #{file}"
            # Cannot use `Sketchup.load` because its an alias for `Sketchup.require`.
            load file
        end
    end
    end # class << self
end

XXX::eof(__FILE__)
