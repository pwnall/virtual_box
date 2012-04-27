# Keep track of the IO controllers in a VM.

module VirtualBox

# IO controller.
class IoBus
  # Controller name, unique to a VM.
  #
  # VirtualBox uses "IDE Controller" and "SATA Controller" as default names.
  attr_accessor :name
  
  # The kind of bus used by the controller.
  #
  # The following types are recognized: :ide, :sata, :sas, :scsi, :floppy.
  attr_accessor :bus
  
  # Controller type.
  #
  # The following chipsets are recogniezd. The :piix3, :piix4, and :ich6 IDE
  # chipsets, the :ahci SATA chipset, the :lsi_logic and :bus_logic SCSI
  # chipsets, the :lsi_logic_sas SAS chipset, and the :i82078 floppy chipset.
  attr_accessor :chip
  
  # True if the VM BIOS considers this controller as bootable.
  attr_accessor :bootable
  
  # True if the I/O for this controller should bypass the host OS cache.
  attr_accessor :no_cache
  
  # Maximum number of I/O devices that can be attached to this controller's bus.
  attr_accessor :max_ports
  
  undef :name
  # :nodoc: defined as accessor
  def name
    @name ||= case bus
    when :ide, :sata, :scsi, :sas
      "#{bus.upcase} Controller"
    when :floppy
      'Floppy Controller'
    end
  end 
  
  undef :no_cache
  # :nodoc: defined as accessor
  def no_cache
    @no_cache.nil? ? false : @bootable
  end

  undef :bootable
  # :nodoc: defined as accessor
  def bootable
    @bootable.nil? ? true : @bootable
  end
  
  undef :chip
  # :nodoc: defined as accessor
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
  # :nodoc: defined as accessor
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
  # :nodoc: defined as accessor
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
  
  # Parses "VBoxManage showvminfo --machinereadable" output into this instance.
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
  
  # Adds this IO bus to a virtual machine.
  #
  # @param [VirtualBox::Vm] vm the virtual machine that this IO bus will be
  #                            added to
  def add_to(vm)
    command = ['VBoxManage', 'storagectl', vm.uid].concat to_params
    result = VirtualBox.run_command command
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
  end
  
  # Removes this IO bus from a virtual machine.
  #
  # @param [VirtualBox::Vm] vm the virtual machine that this IO bus will be
  #                            removed from
  def remove_from(vm)
    command = ['VBoxManage', 'storagectl', vm.uuid, '--name', name, '--remove']
    result = VirtualBox.run_command command
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
  end

  # Creates a new image descriptor based on the given attributes.
  #
  # @param Hash<Symbol, Object> options ActiveRecord-style initial values for
  #     attributes; can be used together with IoBus#to_hash to save and restore
  def initialize(options = {})
    options.each { |k, v| self.send :"#{k}=", v }
  end
  
  # Hash capturing this specification. Can be passed to IoBus#new.
  #
  # @return Hash<Symbol, Object> programmer-friendly Hash that can be used to
  #                              restore the Nic spec on another machine  
  def to_hash
    { :name => name, :bus => bus, :chip => chip, :bootable => bootable,
      :no_cache => no_cache, :max_ports => max_ports }
  end
end  # class VirtualBox::IoBus

end  # namespace VirtualBox
