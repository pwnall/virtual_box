# Manage the VM lifecycle.

module VirtualBox

# VirtualBox virtual machine.
class Vm
  # The UUID used to register this virtual machine with VirtualBox.
  #
  # The UUID is used to identify the VM in many VirtualBox commands. It should
  # not be changed once the VM is registered. In fact, the UUID should not
  # be manually assigned under normal use.
  # @return [String]
  attr_accessor :uid
  
  # A user-friendly name for this virtual machine.
  #
  # If not assigned, a unique name will be generated based on the VM's UUID.
  #
  # @return [String]
  attr_accessor :name
  
  # The general VM configuration.
  # @return [VirtualBox::Board]
  attr_accessor :board
  
  # The IO controllers (and disks) connected to the VM.
  # @return [Array<VirtualBox::IoBus>]
  attr_accessor :io_buses
  
  # The network cards connected to this virtual machine.
  # @return [Array<VirtualBox::Nic>]
  attr_accessor :nics
  
  # If true, the VM's screen will be displayed in a GUI.
  #
  # This is only intended for manual testing. Many continuous integration
  # servers cannot display the VirtualBox GUI, so this attribute should not be
  # set to true in test suites.
  # @return [Boolean]
  attr_accessor :gui
    
  undef :uid
  def uid
    @uid ||= UUID.generate
  end
  
  undef :name
  def name
    @name ||= 'rbx_' + uid.gsub('-', '')
  end
  
  undef :board=
  def board=(new_board)
    @board = if new_board.kind_of?(VirtualBox::Board)
      new_board
    else
      VirtualBox::Board.new new_board
    end
  end

  undef :io_buses=
  def io_buses=(new_io_buses)
    @io_buses = new_io_buses.map do |io_bus|
      if io_bus.kind_of?(VirtualBox::IoBus)
        io_bus
      else
        VirtualBox::IoBus.new io_bus
      end
    end
  end
  
  undef :nics=
  def nics=(new_nics)
    @nics = []
    new_nics.each do |nic|
      if nic.kind_of?(VirtualBox::Nic) || nic.nil?
        @nics << nic
      else
        options = nic.dup
        port = options.delete(:port) || @nics.length
        @nics[port] = VirtualBox::Nic.new options
      end
    end
    new_nics
  end
  
  # Creates a new virtual machine specification based on the given attributes.
  #
  # @param Hash<Symbol, Object> options ActiveRecord-style initial values for
  #     attributes; can be used together with Vm#to_hash to save and restore
  def initialize(options = {})
    self.board = {}
    self.io_buses = []
    self.nics = []
    self.gui = false
    options.each { |k, v| self.send :"#{k}=", v }
  end
  
  # Hash capturing this specification. Can be passed to Vm#new.
  #
  # @return [Hash<Symbol, Object>] Ruby-friendly Hash that can be used to
  #                                re-create this virtual machine specification
  def to_hash
    {
      :name => name, :uid => uid, :gui => gui,
      :board => board.to_hash, :io_buses => io_buses.map(&:to_hash),
      :nics => nics.map.
           with_index { |nic, i| nic && nic.to_hash.merge!(:port => i) }.
           reject!(&:nil?)
    }
  end
  
  # True if this VM has been registered with VirtualBox.
  #
  # @return [Boolean] true for VMs that are already registered with VirtualBox
  def registered?
    self.class.registered_uids.include? uid
  end
  
  # Registers this VM with VirtualBox.
  #
  # @return [VirtualBox::Vm] self, for easy call chaining
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
  # @return [VirtualBox::Vm] self, for easy call chaining
  def unregister
    VirtualBox.run_command ['VBoxManage', 'unregistervm', uid, '--delete']
    self
  end
  
  # Starts the virtual machine.
  #
  # @return [VirtualBox::Vm] self, for easy call chaining
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
  # @return [VirtualBox::Vm] self, for easy call chaining
  def stop
    control :kill
    self
  end

  # Controls a started virtual machine.
  #
  # @param [Symbol] action the following actions are supported: 
  #   :kill:: hard power-off (pulling the power cord from the machine)
  #   :power_button:: Power button press
  #   :nmi:: NMI (non-maskable interrupt)
  # @return [VirtualBox::Vm] self, for easy call chaining
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
    command.concat board.to_params
    nics.each_with_index do |nic, index|
      if nic.nil?
        command.push "--nic#{index + 1}", 'none'
      else
        command.concat nic.to_params(index + 1)
      end
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
    board.from_params config
    
    nic_count = config.keys.select { |key| /^nic\d+$/ =~ key }.max[3..-1].to_i
    1.upto nic_count do |index|
      if config["nic#{index}"] == 'none'
        nics[index - 1] = nil
      else
        nics[index - 1] ||= VirtualBox::Nic.new
        nics[index - 1].from_params config, index
      end
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
