# Run code via the command-line interface.

require 'English'
require 'shellwords'

module VirtualBox

# Runs a command in a sub-shell, waiting until the command completes.
#
# @param [Array<String>] args the name and arguments for the command to be run
#
# @return [Hashie::Mash<Symbol, String>] hash with the following keys / methods:
#     :status:: the command's exit status
#     :output:: a string with the command's output
def self.run_command(args)
  output = Kernel.`(Shellwords.shelljoin(args))
  Hashie::Mash.new :status => $CHILD_STATUS.exitstatus, :output => output
end

end  # namespace VirtualBox
