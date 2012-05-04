require 'securerandom'

module VirtualBox

class Vm

# Configuration for a network card.
class Nic
  # The kind of network emulation implemented on this card.
  #
  # Can be one of the following values:
  # :nat:: uses VirtualBox internal NAT engine to hide under host OS
  # :bridged:: bypasses host OS, connects directly to a network interface
  # :host:: virtual network connecting guest to host
  # :virtual:: virtual network connecting multiple guests
  # @return [Symbol]
  attr_accessor :mode
  
  # The NIC controller chip.
  #
  # Can be one of the following values:
  # :amd:: AMD PCNet FAST III (good default)
  # :intel:: Intel PRO/1000 MT Server (for newer Windows systems)
  # :intel_xp:: Intel PRO/1000 MT Server (for Windows XP)
  # :virtio:: fake card optimized for virtualization (custom drivers needed)
  # @return [Symbol]
  attr_accessor :chip
  
  # Name of the virtual network that the NIC is connected to.
  #
  # The identifier differs depending on the networking mode:
  # :nat:: not applicable
  # :bridged:: name of the bridge network interface on the host
  # :host:: name of the host-only network interface
  # :virtual:: virtual network name
  # @return [Symbol]
  attr_accessor :net_name
  
  # MAC address for the network card, as a hexadecimal string.
  #
  # The format for specifying MACs is '0123456789AB'. A random MAC will be
  # generated if one is not assigned. 
  # @return [String]
  attr_accessor :mac
  
  # Path to a file that logs a network trace for the VM.
  #
  # Can be null to disable tracing.
  # @return [String]
  attr_accessor :trace_file
    
  undef :mode
  def mode
    @mode ||= :nat
  end

  undef :chip
  def chip
    @chip ||= (:mode == :virtual) ? :virtual : :amd
  end
  
  undef :mac
  def mac
    return @mac if @mac
    @mac = SecureRandom.hex(6).upcase
    @mac[1] = 'A'  # Set the OUI bits to unicast and globally unique
    @mac
  end
  undef :mac=
  def mac=(new_mac)
    @mac = new_mac && new_mac.upcase.gsub(/[^0-9A-F]/, '')
  end
  
  # Creates a NIC with the given attributes.
  #
  # @param [Hash<Symbol, Object>] options ActiveRecord-style initial values for
  #     attributes; can be used together with Nic#to_hash to save and restore
  def initialize(options = {})
    options.each { |k, v| self.send :"#{k}=", v }
  end  
   
  # Arguments to "VBoxManage modifyvm" describing the NIC.
  #
  # @param [Number] nic_id the number of the card (1-4) connected to the host
  # @return [Array<String>] arguments that can be concatenated to a "VBoxManage
  #     modifyvm" command to express this NIC specification
  def to_params(nic_id)
    params = []
        
    params.push "--nic#{nic_id}"
    case mode
    when :nat
      params.push 'nat'
    when :bridged
      params.push 'bridged', "--bridgeadapter#{nic_id}", net_name
    when :virtual
      params.push 'intnet', "--intnet#{nic_id}", net_name
    when :host
      params.push 'hostonly', "--hostonlyadapter#{nic_id}", net_name
    else
      params.push 'null'
    end
    
    params.push "--nictype#{nic_id}", case chip
    when :amd
      'Am79C973'
    when :intel
      '82545EM'
    when :intel_xp
      '82543GC'
    when :virtual
      'virtio'
    end      
    
    params.push "--cableconnected#{nic_id}", 'on'    
    params.push "--macaddress#{nic_id}", mac if mac
    
    params.push "--nictrace#{nic_id}"
    if trace_file
      params.push 'on', "--nictracefile#{nic_id}", trace_file
    else
      params.push 'off'
    end
    
    params
  end
  
  # Parses "VBoxManage showvminfo --machinereadable" output into this instance.
  #
  # @param [Hash<String, String>] params the "VBoxManage showvminfo" output,
  #                                      parsed by Vm.parse_machine_readble
  # @param [Integer] nic_id the NIC's number in the VM
  # @return [VirtualBox::Vm::Nic] self, for easy call chaining
  def from_params(params, nic_id)
    case params["nic#{nic_id}"]
    when 'nat'
      self.mode = :nat
    when 'bridged'
      self.mode = :bridged
      self.net_name = params["bridgeadapter#{nic_id}"]
    when 'intnet'
      self.mode = :virtual
      self.net_name = params["intnet#{nic_id}"]
    when 'hostonly'
      self.mode = :host
      self.net_name = params["hostonlyadapter#{nic_id}"]    
    end
    
    self.chip = case params["nictype#{nic_id}"]
    when 'Am79C970A', 'Am79C973',
      :amd
    when '82543GC'
      :intel_xp
    when '82540OEM', '82545EM'
      :intel
    when 'virtio'
      :virtual
    else
      (self.mode == :virtual) ? :virtual : :amd
    end
    
    self.mac = params["macaddress#{nic_id}"]
    if params["nictrace#{nic_id}"] == 'on'
      self.trace_file = params["nictracefile#{nic_id}"]
    else
      self.trace_file = nil
    end
   
    self
  end
  
  # Hash capturing this specification. Can be passed to Nic#new.
  #
  # @return [Hash<Symbol, Object>] Ruby-friendly Hash that can be used to
  #                                re-create this NIC specification
  def to_hash
    { :mode => mode, :chip => chip, :net_name => net_name, :mac => mac,
      :trace_file => trace_file }
  end
  
  # Information about the NICs attached to the computer.
  #
  # @return [Array<Hash<Symbol, Object>>] an array with one hash per NIC; hashes
  #     have the following keys:
  #     :id:: the inteface id (use when setting a Nic's net_id)
  #     :ip:: the IP address (check for 0.0.0.0 to see if it's live)
  #     :mask:: the netmask
  #     :mac:: the NICs MAC address
  def self.host_nics
    @host_nics ||= get_host_nics
  end

  # Queries VirtualBox for the network interfaces on the computer.
  #
  # @return (see .host_nics)
  def self.get_host_nics    
    result = VirtualBox.run_command ['VBoxManage', '--nologo', 'list',
                                     '--long', 'hostifs']
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    
    result.output.split("\n\n").map do |nic_info|
      i = Hash[nic_info.split("\n").map { |line|
        line.split(':', 2).map(&:strip)
      }]
      {
        :id => i['Name'], :ip => i['IPAddress'], :mask => i['NetworkMask'],
        :mac => i['HardwareAddress'].upcase.gsub(/[^0-9A-F]/, '')
      }
    end
  end
end  # class VirtualBox::Vm::Nic

end  # class VirtualBox::Vm

end  # namespace VirtualBox
