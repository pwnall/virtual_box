# Configure a VM's general resources and settings.

module VirtualBox

# Specification for a virtual machine's motherboard.
class Board
  # The number of CPUs (cores) on this board.
  # @return [Integer]
  attr_accessor :cpus

  # The amount of megabytes of RAM on this board.
  # @return [Integer]
  attr_accessor :ram
  # The amount of megabytes of video RAM on this board's video card.
  # @return [Integer]
  attr_accessor :video_ram
  
  # The UUID presented to the guest OS.
  # @return [String]
  attr_accessor :hardware_id  
  
  # The OS that will be running in the virtualized VM.
  #
  # Used to improve the virtualization performance.
  # @return [Symbol]
  attr_accessor :os
  
  # Whether the VM supports PAE (36-bit address space).
  # @return [Boolean]
  attr_accessor :pae  
  # Whether the VM supports ACPI.
  # @return [Boolean]
  attr_accessor :acpi
  # Whether the VM supports I/O APIC.
  #
  # This is necessary for 64-bit OSes, but makes the virtualization slower.
  # @return [Boolean]
  attr_accessor :io_apic
    
  # Whether the VMM attempts to use hardware support (Intel VT-x or AMD-V).
  #
  # Hardware virtualization can increase VM performance, especially used in
  # conjunction with the other hardware virtualization options. However, using
  # hardware virtualization in conjunction with other hypervisors can crash the
  # host machine.
  # @return [Boolean]
  attr_accessor :hardware_virtualization
  # Whether the VMM uses hardware support for nested paging.
  #
  # The option is used only if hardware_virtualization is set.
  # @return [Boolean]
  attr_accessor :nested_paging
  # Whether the VMM uses hardware support for tagged TLB (VPID).
  #
  # The option is used only if hardware_virtualization is set. 
  # @return [Boolean]
  attr_accessor :tagged_tlb
  
  # Whether the VM supports 3D acceleration.
  #
  # 3D acceleration will only work with the proper guest extensions.
  # @return [Boolean]
  attr_accessor :accelerate_3d
  
  # Whether the BIOS logo will fade in when the board boots.
  # @return [Boolean]
  attr_accessor :bios_logo_fade_in
  # Whether the BIOS logo will fade out when the board boots.
  # @return [Boolean]
  attr_accessor :bios_logo_fade_out
  # The number of seconds to display the BIOS logo when the board boots.
  # @return [Integer]
  attr_accessor :bios_logo_display_time
  # Whether the BIOS allows the user to temporarily override the boot VM device. 
  #
  # If false, no override is allowed. Otherwise, the user can press F12 at
  # boot time to select a boot device. The user gets a prompt at boot time if
  # the value is true. If the value is :menu_only the user does not get a
  # prompt, but can still press F12 to select a device.
  # @return [Boolean, Symbol]
  attr_accessor :bios_boot_menu  
  # Indicates the boot device search order for the VM's BIOS.
  #
  # This is an array that can contain the following symbols: :floppy+, :dvd,
  # :disk, :net. Symbols should not be repeated.
  # @return [Array<Symbol>]
  attr_accessor :boot_order
  
  # If +true+, EFI firmware will be used instead of BIOS, for booting.
  #
  # The VirtualBox documentation states that EFI booting is highly experimental,
  # and should only be used to virtualize MacOS.
  # @return [Boolean]
  attr_accessor :efi
  
  # Creates a new motherboard specification based on the given attributes.
  #
  # @param Hash<Symbol, Object> options ActiveRecord-style initial values for
  #     attributes; can be used together with Board#to_hash to save and restore
  def initialize(options = {})
    reset
    options.each { |k, v| self.send :"#{k}=", v }
  end  
   
  # Arguments to "VBoxManage modifyvm" describing the VM's general settings.
  #
  # @return [Array<String>] arguments that can be concatenated to a "VBoxManage
  #     modifyvm" command
  def to_params
    params = []
    params.push '--cpus', cpus.to_s
    params.push '--memory', ram.to_s
    params.push '--vram', video_ram.to_s
    params.push '--hardwareuuid', hardware_id
    params.push '--ostype',
               self.class.os_types[self.class.os_types[os.to_s]]
        
    params.push '--pae', pae ? 'on' : 'off'
    params.push '--acpi', acpi ? 'on' : 'off'
    params.push '--ioapic', io_apic ? 'on' : 'off'
    
    params.push '--hwvirtex', hardware_virtualization ? 'on' : 'off'
    params.push '--nestedpaging',
        (hardware_virtualization && nested_paging) ? 'on' : 'off'
    params.push '--vtxvpid',
        (hardware_virtualization && tagged_tlb) ? 'on' : 'off'
    
    params.push '--firmware', efi ? 'efi' : 'bios'
    params.push '--bioslogofadein', bios_logo_fade_in ? 'on' : 'off'
    params.push '--bioslogofadeout', bios_logo_fade_out ? 'on' : 'off'
    params.push '--bioslogodisplaytime', bios_logo_display_time.to_s

    bios_boot_menu_str = case bios_boot_menu
    when false
      'disabled'
    when :menu_only
      'message'
    else
      'messageandmenu'
    end
    params.push '--biosbootmenu', bios_boot_menu_str
    unique_boot_order = boot_order.uniq
    1.upto(4) do |i|
      device = unique_boot_order[i - 1]
      params.push "--boot#{i}", (device ? device.to_s : 'none')
    end
    
    params
  end
  
  # Parses "VBoxManage showvminfo --machinereadable" output into this instance.
  #
  # @param [Hash<String, String>] output parsed by Vm.parse_machine_readble  
  # @return [VirtualBox::Board] self, for easy call chaining
  def from_params(params)
    self.cpus = params['cpus'].to_i
    self.ram = params['memory'].to_i
    self.video_ram = params['vram'].to_i
    self.hardware_id = params['hardwareuuid']
    self.os = self.class.os_types[params['ostype']]

    self.pae = params['pae'] == 'on'    
    self.acpi = params['acpi'] == 'on'    
    self.io_apic = params['io_apic'] == 'on'    

    self.hardware_virtualization = params['hwvirtex'] == 'on'    
    self.nested_paging = params['nestedpaging'] == 'on'    
    self.tagged_tlb = params['vtxvpid'] == 'on'    

    self.efi = params['firmware'] == 'efi'
    self.bios_logo_fade_in = params['bioslogofadein'] == 'on'
    self.bios_logo_fade_out = params['bioslogofadeout'] == 'on'
    self.bios_logo_display_time = params['bioslogodisplaytime'].to_i
    
    self.bios_boot_menu = case params['bootmenu']
    when 'disabled'
       false
    when 'message'
      :menu_only
    else
      true
    end
    
    self.boot_order = []
    %w(boot1 boot2 boot3 boot4).each do |boot_key|
      next unless params[boot_key] && params[boot_key] != 'none'
      boot_order << params[boot_key].to_sym
    end
    
    self
  end
  
  # Resets to default settings.
  #
  # The defaults are chosen somewhat arbitrarily by the gem's author.
  # @return [VirtualBox::Board] self, for easy call chaining
  def reset
    self.cpus = 1
    self.ram = 512
    self.video_ram = 18
    self.hardware_id = UUID.generate

    self.os = :other    
    self.pae = false
    self.acpi = true
    self.io_apic = false
    
    self.hardware_virtualization = true
    self.nested_paging = true
    self.tagged_tlb = true
    self.accelerate_3d = false
    
    self.efi = false
    self.bios_logo_fade_in = false    
    self.bios_logo_fade_out = false
    self.bios_logo_display_time = 0
    self.bios_boot_menu = false
    
    self.boot_order = [:disk, :net, :dvd]
    self
  end
  
  # Hash capturing this motherboard specification. Can be passed to Board#new.
  #
  # @return [Hash<Symbol, Object>] Ruby-friendly Hash that can be used to
  #                                re-create this motherboard specification
  def to_hash
    { :cpus => cpus, :ram => ram, :video_ram => video_ram,
      :hardware_id => hardware_id, :os => os, :pae => pae, :acpi => acpi,
      :io_apic => io_apic, :hardware_virtualization => hardware_virtualization,
      :nested_paging => nested_paging, :tagged_tlb => tagged_tlb,
      :accelerate_3d => accelerate_3d, :efi => efi,
      :bios_logo_fade_in => bios_logo_fade_in,
      :bios_logo_fade_out => bios_logo_fade_out,
      :bios_logo_display_time => bios_logo_display_time,
      :bios_boot_menu => bios_boot_menu }
  end
  
  # The OS types supported by the VirtualBox installation.
  #
  # @return [Hash<Symbol|String, String|Symbol>] mapping from
  #     programmer-friendly symbols (e.g. :linux26) to proper VirtualBox OS IDs,
  #     and from VirtualBox IDs and description strings to programmer-friendly
  #     symbols
  def self.os_types
    return @os_types if @os_types
    
    @os_types = {}
    list_os_types.each do |key, value|
      os_id = key.downcase.to_sym
      @os_types[key] = os_id
      @os_types[key.downcase] = os_id
      @os_types[value] = os_id
      @os_types[os_id] = key
    end
    @os_types
  end
  
  # Queries VirtualBox for available OS types.
  #
  # @return [Hash<String, String> mapping from each VirtualBox OS type ID to its
  #     description
  def self.list_os_types
    result = VirtualBox.run_command ['VBoxManage', '--nologo', 'list',
                                     '--long', 'ostypes']
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    
    types = result.output.split("\n\n").map do |os_info|
      i = Hash[os_info.split("\n").map { |line| line.split(':').map(&:strip) }]
      [i['ID'], i['Description']]
    end
    Hash[types]
  end
end  # class VirtualBox::Board

end  # namespace VirtualBox
