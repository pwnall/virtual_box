# Run code via the command-line interface.

require 'English'
require 'shellwords'

# :nodoc: namespace
module VirtualBox

# Runs a command in a sub-shell, waiting until the command completes.
#
# Args:
#   args:: an array containing the name and arguments for the command to be ran
#
# Returns:
#   a hash with the following keys / methods:
#       :status:: the command's exit status
#       :output:: a string with the command's output 
def self.run_command(args)
  p args
  output = Kernel.`(Shellwords.shelljoin(args))
  puts output
  Hashie::Mash.new :status => $CHILD_STATUS.exitstatus, :output => output
end

end  # namespace VirtualBox
