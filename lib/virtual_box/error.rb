module VirtualBox

# Raised when the VirtualBox CLI returns a non-zero error code. 
class Error < StandardError
  # The exit code of the failed VirtualBox command.
  # @return [Integer]
  attr_reader :exit_code
  
  # The combined stdout and stderr of the failed VirtualBox command.
  # @return [String] 
  attr_reader :output

  # Called by raise.
  #
  # @param [Hash<Symbol, Object>] cli_result the return value of a
  #     VirtualBox.run call.
  def initialize(cli_result)
    @exit_code = cli_result[:status]
    @output = output
    
    super "VirtualBox CLI exited with code #{@exit_code}:\n#{@output}\n"
  end
end  # class VirtualBox::Error

end  # namespace VirtualBox
