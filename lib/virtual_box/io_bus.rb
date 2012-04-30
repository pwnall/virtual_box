# Keep track of the IO controllers in a VM.

module VirtualBox

# Specification for a IO controller attached to a virtual machine.
class IoBus
  # A user-friendly name for the I/O controller.
  #
  # I/O controller names must be unique within the scope of a virtual machine.
  # VirtualBox uses "IDE Controller" and "SATA Controller" as default names.
  # @return [String]
  attr_accessor :name
  
  # The kind of bus used by this controller.
  #
  # The following bus types are recognized: :ide, :sata, :sas, :scsi, :floppy.
  # @return [Symbol]
  attr_accessor :bus
  
  # The chipset simulated by the IO controller
  #
  # The following chipsets are recogniezd:
  # IDE :: :piix3, :piix4, and :ich6
  # SATA :: :ahci (Intel AHCI)
  # SCSI :: :lsi_logic and :bus_logic
  # SAS :: lsi_logic_sas
  # Floppy :: :i82078
  # @return [Symbol]
  attr_accessor :chip
  
  # True if the VM BIOS considers this controller bootable.
  # @return [Boolean]
  attr_accessor :bootable
  
  # True if the controller's I/O bypasses the host OS cache.
  # @return [Boolean]
  attr_accessor :no_cache
  
  # The maximum number of I/O devices supported by this controller.
  # @return [Integer]
  attr_accessor :max_ports
  
  # The disks connected to this controller's bus.
  # @return [Hash<Array<Integer>, VirtualBox::Disk>]
  attr_accessor :disks
  
  undef :name
  def name
    @name ||= case bus
    when :ide, :sata, :scsi, :sas
      "#{bus.upcase} Controller"
    when :floppy
      'Floppy Controller'
    end
  end 
  
  undef :no_cache
  def no_cache
    @no_cache.nil? ? false : @bootable
  end

  undef :bootable
  def bootable
    @bootable.nil? ? true : @bootable
  end
  
  undef :chip
  def chip
    @chip ||= case @bus
    when :ide
      :piix4
    when :sata
      :ahci
    when :scsi
      :lsi_logic
    when :sas
      :lsi_logic_sas
    when :floppy
      :i82078
    end
  end
  
  undef :bus
  def bus
    @bus ||= case @chip
    when :piix3, :piix4, :ich6
      :ide
    when :ahci
      :sata
    when :lsi_logic, :bus_logic
      :scsi
    when :lsi_logic_sas
      :sas
    when :i82078
      :floppy
    end
  end
  
  undef :max_ports
  def max_ports
    @max_ports ||= case bus
    when :sata
      30
    when :sas, :scsi
      16
    when :ide
      2
    when :floppy
      1
    end
  end
  
  undef :disks=
  def disks=(new_disks)
    @disks = {}
    new_disks.each do |disk|
      if disk.kind_of? VirtualBox::Disk
        @disks[[first_free_port, 0]] = disk
      else
        options = disk.dup
        port = options.delete(:port) || first_free_port
        device = options.delete(:device) || 0
        @disks[[port, device]] = VirtualBox::Disk.new options
      end
    end
    new_disks
  end
  
  # Parses "VBoxManage showvminfo --machinereadable" output into this instance.
  #
  # @return [VirtualBox::IoBus] self, for easy call chaining
  def from_params(params, bus_id)
    self.name = params["storagecontrollername#{bus_id}"]
    self.bootable = params["storagecontrollerbootable#{bus_id}"] == 'on'
    self.max_ports = params["storagecontrollermaxportcount#{bus_id}"].to_i
    case params["storagecontrollertype#{bus_id}"]
    when 'PIIX3'
      self.chip = :piix3
    when 'PIIX4'
      self.chip = :piix4
    when 'ICH6'
      self.chip = :ich6      
    when 'IntelAhci'
      self.chip = :ahci
    when 'LsiLogic'
      self.chip = :lsi_logic
    when 'BusLogic'
      self.chip = :bus_logic
    when 'LSILogicSAS'
      self.chip = :lsi_logic_sas
    when 'I82078'
      self.chip = :i82078
    end
    self.no_cache = nil
    
    image_re = /\A#{name}-(\d+)-(\d+)\Z/
    @disks = {}
    params.each do |key, value|
      next unless match = image_re.match(key)
      next if value == 'none'
      port, device = match[1].to_i, match[2].to_i
      @disks[[port, device]] = VirtualBox::Disk.new :file => value
    end
    self
  end
  
  # Parameters for "VBoxManage storagectl" to add this IO bus to a VM.
  #
  # @return [Array<String>] the parameters for a "VBoxManage storagectl" command
  #     that get this IO bus added to a VM.
  def to_params
    params = []
    params.push '--name', name
    params.push '--add', bus.to_s
    params.push '--controller', case chip
    when :piix3, :piix4, :ich6, :i82078
      chip.to_s.upcase
    when :ahci
      'IntelAhci'
    when :lsi_logic
      'LsiLogic'
    when :bus_logic
      'BusLogic'
    when :lsi_logic_sas
      'LSILogicSAS'
    end
    params.push '--sataportcount', max_ports.to_s
    params.push '--hostiocache', (no_cache ? 'off' : 'on')
    params.push '--bootable', (bootable ? 'on' : 'off')
  end
  

  # Adds this IO bus and all its disks to a virtual machine.
  #
  # @param [VirtualBox::Vm] vm the virtual machine that this IO controller will
  #                            be added to
  # @return [VirtualBox::IoBus] self, for easy call chaining
  def add_to(vm)
    add_bus_to vm
    disks.each do |port_device, disk|
      disk.add_to vm, self, port_device.first, port_device.last
    end
    self
  end
  
  # Removes this IO bus from a virtual machine.
  #
  # @param [VirtualBox::Vm] vm the virtual machine that this IO controller will
  #                            be removed from
  # @return [VirtualBox::IoBus] self, for easy call chaining
  def remove_from(vm)
    result = VirtualBox.run_command ['VBoxManage', '--nologo', 'storagectl',
                                     vm.uuid, '--name', name, '--remove']
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    self
  end

  # Adds this IO bus to a virtual machine.
  #
  # @param [VirtualBox::Vm] vm the virtual machine that this IO bus will be
  #                            added to
  # @return [VirtualBox::IoBus] self, for easy call chaining
  def add_bus_to(vm)
    command = ['VBoxManage', '--nologo', 'storagectl', vm.uid].concat to_params
    result = VirtualBox.run_command command
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    self
  end
  
  # Creates a new IO controller specification based on the given attributes.
  #
  # @param Hash<Symbol, Object> options ActiveRecord-style initial values for
  #     attributes; can be used together with IoBus#to_hash to save and restore
  def initialize(options = {})
    @disks = {}
    options.each { |k, v| self.send :"#{k}=", v }
  end
  
  # Hash capturing this specification. Can be passed to IoBus#new.
  #
  # @return [Hash<Symbol, Object>] Ruby-friendly Hash that can be used to
  #                                re-create this IO controller specification
  def to_hash
    disk_hashes = disks.map do |port_device, disk|
      disk.to_hash.merge! :port => port_device.first,
                          :device => port_device.last
    end
    { :name => name, :bus => bus, :chip => chip, :bootable => bootable,
      :no_cache => no_cache, :max_ports => max_ports, :disks => disk_hashes }
  end

  # Finds an unused port on this IO controller's bus.
  # @return [Integer] a port number that a new disk can be attached to
  def first_free_port
    disks.empty? ? 0 : disks.keys.min.first + 1
  end
end  # class VirtualBox::IoBus

end  # namespace VirtualBox
