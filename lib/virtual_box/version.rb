# VirtualBox version detection. 

module VirtualBox
  @version_info = nil
  
  # True if the installed VirtualBox is the open-source edition.
  #
  # The open-source edition of VirtualBox has some limitations, such as no
  # support for RDP and USB devices.
  def self.ose?
    unless version[:edition]
      raise 'VirtualBox is not installed on this machine.'
    end
    version[:edition] == 'OSE'
  end
  
  # Version information about the VirtualBox package installed on this machine.
  #
  # @return [Hash<Symbol, Object>, Boolean] false if VirtualBox is not
  #     installed; otherwise, a hash with the following keys:
  #     :svn:: (number) the SVN revision that VirtualBox is built off of
  #     :edition:: the VirtualBox edition ('' for the personal edition, 'OSE'
  #                for the open-source edition)
  #     :release:: the public release number (e.g. '3.0.4')
  def self.version
    return @version_info unless @version_info.nil?
    
    cmd_result = run_command ['VBoxManage', '--version']
    if cmd_result[:status] != 0
      @version_info = {}
      return @version_info
    end
    
    output = cmd_result[:output].strip

    if revision_offset = output.rindex('r')
      revision = output[revision_offset + 1, output.length].to_i
      output.slice! revision_offset..-1
    else
      revision = nil
    end
    
    if edition_offset = output.rindex('_')
      edition = output[edition_offset + 1, output.length]
      output.slice! edition_offset..-1
    else
      edition = ''
    end
    
    @version_info = { :release => output, :svn => revision,
                      :edition => edition }
  end
  
  # Removes the cached information on the VirtualBox package version.
  # @return <NilObject> nil
  def self.reset_version_info!
    @version_info = nil
  end
end  # namespace VirtualBox
