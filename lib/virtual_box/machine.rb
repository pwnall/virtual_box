# Configure a VM's general resources and settings.

# :nodoc: namespace
module VirtualBox


# Configuration for a virtual machine.
class Machine
  # The number of CPUs in the VM.
  attr_accessor :cpus

  # The amount of megabytes of RAM in the VM.
  attr_accessor :ram
  # The amount of megabytes of video RAM in the VM.
  attr_accessor :video_ram
  
  # The UUID presented to the guest OS.
  attr_accessor :hardware_id  
  
  # The OS that will be running in the virtualized VM.
  #
  # This is used to improve the virtualization performance.
  attr_accessor :os
  
  # Whether the VM supports PAE (36-bit address space).
  attr_accessor :pae  
  # Whether the VM supports ACPI.
  attr_accessor :acpi
  # Whether the VM supports I/O APIC.
  #
  # This is necessary for 64-bit OSes, but makes the virtualization slower.
  attr_accessor :io_apic
    
  # Whether the VM attempts to use hardware support (Intel VT-x or AMD-V).
  #
  # Hardware virtualization can increase VM performance, especially used in
  # conjunction with the other hardware virtualization options. However, using
  # hardware virtualzation in conjunction with other hypervisors can crash the
  # host machine.
  attr_accessor :hardware_virtualization
  # Whether the VM uses hardware support for nested paging.
  #
  # The option is used only if hardware_virtualization is set.
  attr_accessor :nested_paging
  # Whether the VM uses hardware support for tagged TLB (VPID).
  #
  # The option is used only if hardware_virtualization is set. 
  attr_accessor :tagged_tlb
  
  # Whether the VM supports 3D acceleration.
  #
  # 3D acceleration will only work with the proper guest extensions.
  attr_accessor :accelerate_3d
  
  # Whether the BIOS logo will fade in when the VM boots.
  attr_accessor :bios_logo_fade_in
  # Whether the BIOS logo will fade out when the VM boots.
  attr_accessor :bios_logo_fade_out
  # The number of seconds to display the BIOS logo when the VM boots.
  attr_accessor :bios_logo_display_time
  # Whether the BIOS allows the user to temporarily override the boot VM device. 
  #
  # If +false+, no override is allowed. Otherwise, the user can press F12 at
  # boot time to select a boot device. The user gets a prompt at boot time if
  # the value is +true+. If the value is +:menu_only+ the user does not get a
  # prompt, but can still press F12 to select a device.  
  attr_accessor :bios_boot_menu  
  # Indicates the boot device search order for the VM's BIOS.
  #
  # This is an array that can contain the following symbols: +:floppy+, +:dvd+,
  # +:disk+, +:net+. Symbols should not be repeated.
  attr_accessor :boot_order
  
  # If +true+, EFI firmware will be used instead of BIOS, for booting.
  attr_accessor :efi
  
  # Creates a VM configuration with the given attributes
  def initialize(options = {})
    reset
    options.each { |k, v| self.send :"#{k}=", v }
  end  
   
  # Arguments to "VBoxManage modifyvm" describing the VM's general settings.
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
  end
  
  # Hash capturing this configuration. Can be passed to Machine#new.
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
  # A hash that maps symbols to the proper VirtualBox OS IDs, and also maps
  # ID and description strings to symbols.
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
  # Returns a hash mapping each type ID to its description.
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
end  # class VirtualBox::Machine

end  # namespace VirtualBox
