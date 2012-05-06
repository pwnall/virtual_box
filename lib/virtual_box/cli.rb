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
  begin
    output = Kernel.`(Shellwords.shelljoin(args) + ' 2>&1')
    Hashie::Mash.new :status => $CHILD_STATUS.exitstatus, :output => output

    # TODO(pwnall): this should work, but it makes VirtualBox slow as hell
    # child = POSIX::Spawn::Child.new(*args)
    # Hashie::Mash.new :status => child.status.exitstatus, :output => child.out
  rescue SystemCallError
    Hashie::Mash.new :status => -1, :output => ''
  end
end

end  # namespace VirtualBox
