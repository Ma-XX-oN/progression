XXX::bof(__FILE__)
require 'sketchup.rb'
require_relative 'assert.rb'

module AFH
    class KeyBindings
        include AFH
        
        DELAY = 0.5
        RATE = 0.05
        def initialize(*keybindings)
            # takes an array of the following elements
            @modifiers = 0
            @keybindings = {}
            @key_repeat_id = nil
            @key_down = nil
            keybindings.each { |e|
                AssertCode{
                    unrecognized_parameters = e.keys - [:modifiers, :keys, :code, :on_press]
                    Assert(ArgumentError){ True?(unrecognized_parameters.empty?) {
                            "Unrecognized key binding parameter(s) #{unrecognized_parameters} in line:\n#{e}\n"} }
                }
                modifier = Array(e[:modifiers]).reduce(0) {|a,m|
                    Assert(ArgumentError){ True?(MODIFIER_MAP.key?(m)) { "Unrecognized modifier #{m}"} }
                    a |= MODIFIER_MAP.fetch(m)
                }
                Assert(ArgumentError){ True?(e.key? :keys) { "Must have a key to bind to."} }
                Assert(ArgumentError){ True?(e.key? :code) { "Must have code to execute."} }
                # default UP
                on_press = e[:on_press].nil? ? UP : [:down, :up].find_index(e[:on_press])
                Assert(ArgumentError){ True?(!on_press.nil?) { "Invalid press state #{e[:on_press]}."} }
                Array(e.fetch(:keys)).each {|k|
                    key = (String === k ? k[0].ord : k)
                    @keybindings[key] ||= {}
                    @keybindings[key][modifier] ||= []
                    @keybindings[key][modifier][on_press] = e[:code]
                    # puts var_s(VarVal.new("@keybindings[#{key}][#{modifier}][#{on_press}]", "@keybindings[key][modifier][on_press]")){|e|eval e}
                }
            }
        end

        def handle_key(key, on_press, fake_repeat = false)
            Assert(ArgumentError){ True?(any_of(:up, :down, on_press, &:==)) { "Invalid press value #{on_press}."} }
            warn "#{on_press} #{key}"
            kill_repeat_timer unless fake_repeat
            if on_press == :down
                if !modifier_down?(key)
                    handled = execute_binding(key, DOWN)
                    start_repeat_timer_with key
                end
            elsif !modifier_up?(key)
                handled = execute_binding(key, UP)
            end
            handled
        end
        
        private

        def key_press_delay_finished
            @key_repeat_id = UI::start_timer(RATE, true) { handle_key(@key_down, :down, true) }
        end

        def start_repeat_timer_with(key)
            return unless @key_repeat_id.nil?
            @key_down = key
            @key_repeat_id = UI::start_timer(DELAY) { key_press_delay_finished }
        end

        def kill_repeat_timer
            return if @key_repeat_id.nil?
            UI::stop_timer(@key_repeat_id)
            @key_repeat_id = nil
        end
        
        MODIFIER_MAP =  { VK_SHIFT => 1, VK_CONTROL => 2, VK_ALT => 3 }
        DOWN = 0
        UP   = 1

        def execute_binding(key, on_press)
            Assert(ArgumentError){ True?((DOWN..UP) === on_press) { "Invalid on press state."} }
            if @keybindings[key] && @keybindings[key][@modifiers] && @keybindings[key][@modifiers][on_press]
                @keybindings[key][@modifiers][on_press].call
                true
            else
                false
            end
        end
        
        def modifier_down?(key)
            if MODIFIER_MAP.key? key
                @modifiers |= MODIFIER_MAP[key]
                true
            else
                false
            end
        end
        
        def modifier_up?(key)
            if MODIFIER_MAP.key? key
                @modifiers &= ~MODIFIER_MAP[key]
                true
            else
                false
            end
        end
    end
end
XXX::eof(__FILE__)