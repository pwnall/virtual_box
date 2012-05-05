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
    #output = Kernel.`(Shellwords.shelljoin(args))
    #Hashie::Mash.new :status => $CHILD_STATUS.exitstatus, :output => output
    command_line = [args.first].concat args
    pid, stdin_pipe, stdout_pipe, stderr_pipe = POSIX::Spawn.popen4 args
    stdin_pipe.close
    output = []
    output << stdout_pipe.read rescue nil
    _, status = Process::wait2 pid
    output << stdout_pipe.read rescue nil
    Hashie::Mash.new :status => status.exitstatus, :output => output.join('')
  rescue SystemCallError
    Hashie::Mash.new :status => -1, :output => ''
  end
end

end  # namespace VirtualBox
