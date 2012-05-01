module VirtualBox

# Descriptor for a virtual network managed by Virtual Box.
class Net 
  # The IP address received by the host computer on this virtual network.
  # @return [String]
  attr_accessor :ip
  
  # The network mask received by the host computer on this virtual network.
  # @return [String]
  attr_accessor :netmask

  # The name of the host's virtual NIC that's connected to this network.
  #
  # VirtualBox's CLI does not provide a way to set the NIC name. Therefore, this
  # attribute is read-only, and it is automatically set when the network is
  # registered with VirtualBox.
  # @return [String]
  attr_reader :if_name

  # The name of the VirtualBox internal network.
  #
  # VirtualBox's CLI does not provide a way to set the internal network name.
  # Therefore, this attribute is read-only, and it is automatically set when the
  # network is registered with VirtualBox.
  # @return [String]
  attr_reader :name
  
  # The MAC address of the host's virtual NIC that's connected to this network.
  #
  # VirtualBox's CLI does not provide a way to set the MAC. Therefore, this
  # attribute is read-only, and it is automatically set when the network is
  # registered with VirtualBox.
  # @return [String]
  attr_reader :mac
  
  # Creates a virtual network specification rule based on the given attributes.
  #
  # The network is not automatically added to VirtualBox.
  # @param [Hash<Symbol, Object>] options ActiveRecord-style initial values for
  #     attributes; can be used together with Net#to_hash to save and restore
  def initialize(options = {})
    options.each { |k, v| self.send :"#{k}=", v }
  end

  # Hash capturing this specification. Can be passed to Net#new.
  #
  # @return [Hash<Symbol, Object>] Ruby-friendly Hash that can be used to
  #                                re-create this virtual network specification
  def to_hash
    { :ip => ip, :netmask => netmask }
  end
  
  # True if this virtual network has been added to VirtualBox.
  # @return [Boolean] true if this network exists, false otherwise
  def live?
    networks = self.class.all
    network = networks.find { |net| net.if_name == if_name }
    network ? true : false
  end
  
  # Adds this virtual network specification to VirtualBox.
  #
  # @return [VirtualBox::Net] self, for easy call chaining
  def add
    unless if_name.nil?
      raise "Virtual network already added to VirtualBox"
    end
    
    # Create the network and pull its name.
    result = VirtualBox.run_command ['VBoxManage', '--nologo', 'hostonlyif',
        'create']
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    unless match = /^interface\s+'(.*)'\s+.*created/i.match(result.output)
      raise "VirtualBox output does not include interface name"
    end
    @if_name = match[1]
    
    # Now list all the networks to pull the rest of the information.
    networks = self.class.all
    network = networks.find { |net| net.if_name == if_name }
    @name = network.name
    @mac = network.mac
    
    if (ip && ip != network.ip) || (netmask && netmask != network.netmask)
      result = VirtualBox.run_command ['VBoxManage', '--nologo', 'hostonlyif',
          'ipconfig', if_name, '--ip', ip, '--netmask', netmask]
      if result.status != 0
        raise 'Unexpected error code returned by VirtualBox'
      end
    else
      self.ip = network.ip
      self.netmask = network.netmask
    end
    
    self
  end
  
  # Removes this virtual network from VirtualBox's database.
  #
  # @return [VirtualBox::Net] self, for easy call chaining
  def remove
    unless if_name.nil?
      VirtualBox.run_command ['VBoxManage', 'hostonlyif', 'remove', if_name]
    end
    self
  end
  
  # The DHCP servers added to with VirtualBox.
  #
  # @return [Array<VirtualBox::Dhcp>] all the DHCP servers added to VirtualBox
  def self.all
    result = VirtualBox.run_command ['VBoxManage', '--nologo', 'list', '--long',
                                     'hostonlyifs']
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    result.output.split("\n\n").
                  map { |net_info| new.from_net_info(net_info) }
  end
  
  # Parses information about a DHCP server returned by VirtualBox.
  #
  # The parsed information is used to replace this network's specification.
  # @param [String] net_info output from "VBoxManage list --long hostonlyifs"
  #                          for one network
  # @return [VirtualBox::Net] self, for easy call chaining
  def from_net_info(net_info)
    info = Hash[net_info.split("\n").map { |line|
      line.split(':', 2).map(&:strip)
    }]
    
    @if_name = info['Name']
    @name = info['VBoxNetworkName']
    @mac = info['HardwareAddress'].upcase.gsub(/[^0-9A-F]/, '')
    self.ip = info['IPAddress']
    self.netmask = info['NetworkMask']
    self
  end
end  # class VirtualBox::Dhcp

end  # namespace VirtualBox
