# Manage the VM lifecycle.

# :nodoc: namespace
module VirtualBox


# VirtualBox virtual machine.
class Vm
  # The UUID that the VM is registered with in VirtualBox.
  attr_accessor :uid
  
  # Name for the VM.
  attr_accessor :name
  
  # General VM configuration (Machine instance).
  attr_accessor :specs
  
  # Network interfaces.
  attr_accessor :nics
  private :nics=
  
  # If true, the VM's screen will be displayed in a GUI.
  #
  # This is only intended for manual testing.
  attr_accessor :gui
    
  undef :uid
  # :nodoc: documented as accessor
  def uid
    @uid ||= UUID.generate
  end
  
  undef :name
  # :nodoc: documented as accessor
  def name
    @name ||= 'rbx_' + uid.gsub('-', '')
  end
  
  undef :specs
  # :nodoc: documented as accessor
  def specs
    @specs ||= Machine.new
  end
  
  # Creates a VM based on the given attributes.
  #
  # This does not register the VM with VirtualBox.
  def initialize(options = {})
    self.nics = Array.new(8) { VirtualBox::Nic.new :mode => :none }
    options.each { |k, v| self.send :"#{k}=", v }
  end
  
  # True if this VM has been registered with VirtualBox.
  def registered?
    self.class.registered_uids.include? uid
  end
  
  # Registers this VM with VirtualBox.
  def register
    unregister if registered?
    
    result = VirtualBox.run_command ['VBoxManage', 'createvm',
        '--name', name, '--uuid', uid, '--register']
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    
    push_config
    
    self
  end
  
  # De-registers this VM from VirtualBox's database.
  def unregister
    VirtualBox.run_command ['VBoxManage', 'unregistervm', uid, '--delete']
    self
  end
  
  # Starts the virtual machine.
  def start
    register unless registered?
    
    result = VirtualBox.run_command ['VBoxManage', '--nologo', 'startvm', uid,
                                     '--type', gui ? 'gui' : 'headless']
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    self
  end
  
  # Stops the virtual machine simulation.
  #
  # This is equivalent to pulling the power cord from a physical machine.
  def stop
    control :kill
    self
  end

  # Controls a started virtual machine.
  #
  # The following actions are supported:
  #   :kill:: hard power-off (pulling the power cord from the machine)
  #   :power_button:: Power button press
  #   :nmi:: NMI (non-maskable interrupt)
  def control(action)
    action = case action
    when :kill
      'poweroff'
    when :power_button
      'acpipowerbutton'
    when :nmi
      'injectnmi'
    end

    result = VirtualBox.run_command ['VBoxManage', '--nologo', 'controlvm', uid,
                                     action]
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    self
  end
  
  # Creates the virtual machine configuration in VirtualBox.
  #
  # Args:
  #   config_path:: path to the VM configuration file that will be created
  def create_configuration(config_path = nil)
    raise 'Cannot create a configuration without a VM name' unless name
    
    command = %|VBoxManage --nologo createvm --name "#{name}"|
    if config_path
      command += %| --settingsfile "#{File.expand_path config_path}"|
    end
    
    result = VirtualBox.shell_command command
    raise 'VM creation failed' unless result[:status] == 0
    
    uuid_match = /^UUID: (.*)$/.match result[:output]
    unless uuid_match
      raise "VM creation didn't output a UUID:\n#{result[:output]}"
    end
    self.uuid = uuid_match[1]    
    config_match = /^Settings file: '(.*)'$/.match result[:output]
    unless uuid_match
      raise "VM creation didn't output a config file path:\n#{result[:output]}"
    end
    self.config_file = config_match[1]
    
    true
  end
  
  # All machines registered with VirtualBox.
  def self.registered_uids
    result = VirtualBox.run_command ['VBoxManage', '--nologo', 'list', 'vms']
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    result.output.split("\n").map do |id_info|
      uid_offset = id_info.rindex(?{) + 1
      uid = id_info[uid_offset...-1]  # Exclude the closing }
    end
  end

  # All machines that are started in VirtualBox.
  def self.started_uids
    result = VirtualBox.run_command ['VBoxManage', '--nologo', 'list',
                                     'runningvms']
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    result.output.split("\n").map do |id_info|
      uid_offset = id_info.rindex(?{) + 1
      uid = id_info[uid_offset...-1]  # Exclude the closing }
    end
  end
  
  # Updates the configuration in VirtualBox to reflect this VM's configuration. 
  def push_config
    command = ['VBoxManage', 'modifyvm', uid]
    command.push *specs.to_params
    nics.each_with_index { |nic, index| command.push *nic.to_params(index + 1) }
    if VirtualBox.run_command(command).status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    self
  end
  
  # Updates this VM's configuration to reflect the VirtualBox configuration.
  def pull_config
    result = VirtualBox.run_command ['VBoxManage', '--nologo', 'showvminfo',
                                     '--machinereadable', uid]
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    
    config = Hash[result.output.split("\n").map { |line|
      key, value = *line.split('=', 2)
      value = value[1...-1] if value[0] == ?"  # Remove string quotes ("").
      [key, value]
    }]
    
    self.name = config['name']
    self.uid = config['UUID']
    specs.from_params config
    
    nic_count = config.keys.select { |key| /^nic\d+$/ =~ key }.max[3..-1].to_i
    1.upto(nic_count) do |index|
      nics[index - 1] ||= VirtualBox::Nic.new
      nics[index - 1].from_params config, index
    end
    
    self
  end
end  # class VirtualBox::Vm

end  # namespace VirtualBox
