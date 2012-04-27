# Manage the VM lifecycle.

module VirtualBox

# VirtualBox virtual machine.
class Vm
  # The UUID that the VM is registered with in VirtualBox.
  attr_accessor :uid
  
  # [String] Name for the VM.
  attr_accessor :name
  
  # [VirtualBox::Machine] General VM configuration.
  attr_accessor :specs
  
  # [Array<VirtualBox::Nic>] Network interfaces.
  attr_accessor :nics
  private :nics=
  
  # [Array<VirtualBox::IoBus>] IO controllers connecting disks to the VM.
  attr_accessor :io_buses
  undef :io_buses=
  # :nodoc: defined as accessor
  def io_buses=(new_io_buses)
    @io_buses = new_io_buses.map do |io_bus|
      if io_bus.kind_of? VirtualBox::IoBus
        io_bus
      else
        VirtualBox::IoBus.new io_bus
      end
    end
  end
  
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
  #
  # @return [Vm] self, for easy call chaining
  def initialize(options = {})
    self.nics = Array.new(8) { VirtualBox::Nic.new :mode => :none }
    self.io_buses = []
    options.each { |k, v| self.send :"#{k}=", v }
  end
  
  # True if this VM has been registered with VirtualBox.
  #
  # @return [Boolean] true for VMs that are already registered with VirtualBox
  def registered?
    self.class.registered_uids.include? uid
  end
  
  # Registers this VM with VirtualBox.
  #
  # @return [Vm] self, for easy metod chaining
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
  #
  # @return [Vm] self, for easy metod chaining
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
  # @param [String] config_path path to the VM configuration file that will be
  #                             created
  # @return [VirtualBox::Vm] self, for easy call chaining
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
    
    self
  end
  
  # The UUIDs of all VMs that are registered with VirtualBox.
  #
  # @return [Array<String>] UUIDs for VMs that VirtualBox is aware of
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

  # The UUIDs of all VirtualBox VMs that are started.
  #
  # @return [Array<String>] UUIDs for VMs that are running in VirtualBox
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
  #
  # @return [VirtualBox::Vm] self, for easy call chaining
  def push_config
    command = ['VBoxManage', 'modifyvm', uid]
    command.concat specs.to_params
    nics.each_with_index do |nic, index|
      command.concat nic.to_params(index + 1)
    end
    if VirtualBox.run_command(command).status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    
    io_buses.each { |bus| bus.add_to self }
     
    self
  end
  
  # Updates this VM's configuration to reflect the VirtualBox configuration.
  #
  # @return [VirtualBox::Vm] self, for easy call chaining
  def pull_config
    result = VirtualBox.run_command ['VBoxManage', '--nologo', 'showvminfo',
                                     '--machinereadable', uid]
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    
    config = self.class.parse_machine_readable result.output
    
    self.name = config['name']
    self.uid = config['UUID']
    specs.from_params config
    
    nic_count = config.keys.select { |key| /^nic\d+$/ =~ key }.max[3..-1].to_i
    1.upto nic_count do |index|
      nics[index - 1] ||= VirtualBox::Nic.new
      nics[index - 1].from_params config, index
    end

    bus_count = 1 + (config.keys.select { |key|
      /^storagecontrollername\d+$/ =~ key
    }.max || "storagecontrollername-1")[21..-1].to_i
    0.upto bus_count - 1 do |index|
      io_buses[index] ||= VirtualBox::IoBus.new
      io_buses[index].from_params config, index
    end
    
    self
  end
  
  # Parses the output of the 'VBoxManage showvminfo --machinereadable' command.
  #
  # @param [String] the command output
  # @return [Hash<String, Object>] a Hash whose keys are the strings on the left
  #     side of "=" on each line, and whose values are the strings on the right
  #     side
  def self.parse_machine_readable(output)
    Hash[output.split("\n").map { |line|
      key, value = *line.split('=', 2)
      key = key[1...-1] if key[0] == ?"  # Remove string quotes ("").
      value = value[1...-1] if value[0] == ?"  # Remove string quotes ("").
      [key, value]
    }]    
  end
end  # class VirtualBox::Vm

end  # namespace VirtualBox
