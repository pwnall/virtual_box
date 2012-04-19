# Configure a VM's general resources and settings.

# :nodoc: namespace
module VirtualBox


# Configuration for a network card.
class Nic
  # The kind of network emulation implemented on this card.
  #
  # Can be one of the following values:
  #   :nat:: uses VirtualBox internal NAT engine to hide under host OS
  #   :bridged:: bypasses host OS, connects directly to a network interface
  #   :host:: virtual network connecting guest to host
  #   :virtual:: virtual network connecting multiple guests
  attr_accessor :mode
  
  # The NIC controller chip.
  #
  # Can be one of the following values:
  #    :amd:: AMD PCNet FAST III (good default)
  #    :intel:: Intel PRO/1000 MT Server (for newer Windows systems)
  #    :intel_xp:: Intel PRO/1000 MT Server (for Windows XP)
  #    :virtio:: fake card optimized for virtualization (custom drivers needed)
  attr_accessor :chip
  
  # Identifier of the network that the NIC is connected to.
  #
  # The identifier differs depending on the networking mode:
  #   bridged:: name of the bridge network interface on the host
  #   host:: name of the host-only network interface
  #   virtual:: virtual network name
  attr_accessor :net_id
  
  # MAC address for the network card, as a hexadecimal string.
  #
  # Example: '001122334455'
  #
  # If null, the network card will receive a random address.
  attr_accessor :mac
  
  # Path to a file that logs a network trace for the VM.
  #
  # Can be null to disable tracing.
  attr_accessor :trace_file
    
  undef :mode
  # :nodoc: defined as accessor
  def mode
    @mode ||= :none
  end

  undef :chip
  # :nodoc: defined as accessor
  def chip
    @chip ||= (:mode == :virtual) ? :virtual : :amd
  end
  
  undef :mac
  # :nodoc: defined as accessor
  def mac
    @mac ||= '001122334455'
  end
  undef :mac=
  # :nodoc: defined as accessor
  def mac=(new_mac)
    @mac = new_mac && new_mac.upcase.gsub(/[^0-9A-F]/, '')
  end
  
  # Creates a NIC with the given attributes
  def initialize(options = {})
    options.each { |k, v| self.send :"#{k}=", v }
  end  
   
  # Arguments to "VBoxManage modifyvm" describing the NIC.
  #
  # Args:
  #   nic_id:: the number of the card (1-4) connected to the host
  def to_params(nic_id)
    params = []
        
    params.push "--nic#{nic_id}"
    case mode
    when :none
      params.push 'none'
      return params
    when :nat
      params.push 'nat'
    when :bridged
      params.push 'bridged', "--bridgeadapter#{nic_id}", net_id
    when :virtual
      params.push 'intnet', "--intnet#{nic_id}", net_id
    when :host
      params.push 'hostonly', "--hostonlyadapter#{nic_id}", net_id
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
  def from_params(params, nic_id)
    case params["nic#{nic_id}"]
    when 'nat'
      self.mode = :nat
    when 'bridged'
      self.mode = :bridged
      self.net_id = params["bridgeadapter#{nic_id}"]
    when 'intnet'
      self.mode = :virtual
      self.net_id = params["intnet#{nic_id}"]
    when 'hostonly'
      self.mode = :host
      self.net_id = params["hostonlyadapter#{nic_id}"]    
    when 'none'
      self.mode = :none
      self.chip = nil
      self.net_id = nil
      self.mac = nil
      self.trace_file = nil
      return      
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
  
  # Hash capturing this configuration. Can be passed to Machine#new.
  def to_hash
    { :mode => mode, :chip => chip, :net_id => net_id, :mac => mac,
      :trace_file => trace_file }
  end
  
  # Information about the NICs attached to the computer.
  #
  # Returns an array of hashes with the following keys:
  #   :id:: the inteface id (use when setting a Nic's net_id)
  #   :ip:: the IP address (check for 0.0.0.0 to see if it's live)
  #   :mask:: the netmask
  #   :mac:: the NICs MAC address
  def self.host_nics
    @host_nics ||= get_host_nics
  end

  # Queries VirtualBox for the network interfaces on the computer.
  #
  # See host_nics for return type.  
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
end  # class VirtualBox::Nic

end  # namespace VirtualBox
