# Compatibility shims so JSDuck (originally written for Ruby 1.8/1.9) runs on
# modern Ruby (3.2+). Loaded as early as possible from bin/jsduck.
#
# Ruby 3.2 removed File.exists? / Dir.exists? (renamed to exist?) and unified
# Fixnum / Bignum into Integer. JSDuck still uses the old names in a few places.

File.singleton_class.send(:alias_method, :exists?, :exist?) unless File.respond_to?(:exists?)
Dir.singleton_class.send(:alias_method, :exists?, :exist?) unless Dir.respond_to?(:exists?)

Fixnum = Integer unless defined?(Fixnum)
Bignum = Integer unless defined?(Bignum)
