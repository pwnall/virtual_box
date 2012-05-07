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
  attr_reader :name

  # The name of the VirtualBox internal network.
  #
  # This is most likely not useful outside the VirtualBox API.
  #
  # VirtualBox's CLI does not provide a way to set the internal network name.
  # Therefore, this attribute is read-only, and it is automatically set when the
  # network is registered with VirtualBox.
  # @return [String]
  attr_reader :vbox_name
  
  # The MAC address of the host's virtual NIC that's connected to this network.
  #
  # VirtualBox's CLI does not provide a way to set the MAC. Therefore, this
  # attribute is read-only, and it is automatically set when the network is
  # registered with VirtualBox.
  # @return [String]
  attr_reader :mac
  
  # The VirtualBox-powered DHCP server configured to serve this interface.
  # @return [VirtualBox::Net::Dhcp, NilClass]
  attr_accessor :dhcp
  
  undef :dhcp=
  def dhcp=(new_dhcp)
    if new_dhcp.nil?
      @dhcp = nil
    elsif new_dhcp.kind_of? VirtualBox::Net::Dhcp
      @dhcp = new_dhcp
    else
      @dhcp = VirtualBox::Net::Dhcp.new new_dhcp
    end
  end
  
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
    { :ip => ip, :netmask => netmask, :dhcp => dhcp && dhcp.to_hash }
  end
  
  # True if this virtual network has been added to VirtualBox.
  # @return [Boolean] true if this network exists, false otherwise
  def live?
    networks = self.class.all false
    network = networks.find { |net| net.name == name }
    network ? true : false
  end
  
  # Adds this virtual network specification to VirtualBox.
  #
  # @return [VirtualBox::Net] self, for easy call chaining
  def add
    unless name.nil?
      raise "Virtual network already added to VirtualBox"
    end
    
    # Create the network and pull its name.
    output = VirtualBox.run_command! ['VBoxManage', '--nologo', 'hostonlyif',
                                      'create']
    unless match = /^interface\s+'(.*)'\s+.*created/i.match(output)
      raise "VirtualBox output does not include interface name"
    end
    @name = match[1]
    
    # Query VirtualBox to pull the rest of the information.
    network = self.class.named name
    @vbox_name = network.vbox_name
    @mac = network.mac
    
    if (ip && ip != network.ip) || (netmask && netmask != network.netmask)
      VirtualBox.run_command! ['VBoxManage', '--nologo', 'hostonlyif',
          'ipconfig', name, '--ip', ip, '--netmask', netmask]
    else
      self.ip = network.ip
      self.netmask = network.netmask
    end
    
    # Register the DHCP server, if it's connected.
    dhcp.add self if dhcp
    
    self
  end
  
  # Removes this virtual network from VirtualBox's database.
  #
  # @return [VirtualBox::Net] self, for easy call chaining
  def remove
    unless name.nil?
      dhcp.remove self if dhcp
      VirtualBox.run_command ['VBoxManage', 'hostonlyif', 'remove', name]
    end
    self
  end
  
  # The virtual networks added to VirtualBox.
  #
  # @param [Boolean] with_dhcp if false, the returned VirtualBox::Net instances
  #     will have their dhcp property set to nil, even if they have DHCP
  #     servers; this saves a CLI call when DHCP information is not needed
  # @return [Array<VirtualBox::Net>] all the DHCP servers added to VirtualBox
  def self.all(with_dhcp = true)
    dhcps = with_dhcp ? VirtualBox::Net::Dhcp.all : {}
    
    output = VirtualBox.run_command! ['VBoxManage', '--nologo', 'list',
                                      '--long', 'hostonlyifs']
    output.split("\n\n").map do |net_info|
      net = new.from_net_info net_info
      net.dhcp = dhcps[net.vbox_name]
      net
    end
  end
  
  # The virtual network added to VirtualBox with a given name.
  #
  # This is a convenience for calling find on Net.all, so it's just as
  # inefficient.
  # @param [String] name the name to look for
  # @param [Boolean] with_dhcp if false, the returned VirtualBox::Net instance
  #     will have its dhcp property set to nil, even if it has a DHCP
  #     server; this saves a CLI call when DHCP information is not needed
  def self.named(name, with_dhcp = true)
    networks = all with_dhcp
    networks.find { |net| net.name == name }
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
    
    @name = info['Name']
    @vbox_name = info['VBoxNetworkName']
    @mac = info['HardwareAddress'].upcase.gsub(/[^0-9A-F]/, '')
    self.ip = info['IPAddress']
    self.netmask = info['NetworkMask']
    self
  end
  
  
  # Information about the NICs attached to the computer.
  #
  # @return [Array<Hash<Symbol, Object>>] an array with one hash per NIC; hashes
  #     have the following keys:
  #     :name:: the NIC device's name (use when setting a Nic's net_name)
  #     :ip:: the IP address (compare against 0.0.0.0 to see if it's live)
  #     :mask:: the network mask used to figure out broadcasting
  #     :mac:: the NICs MAC address (format: "AB0123456789")
  def self.host_nics
    @host_nics ||= host_nics!
  end

  # Queries VirtualBox for the network interfaces on the computer.
  #
  # @return (see .host_nics)
  def self.host_nics!
    output = VirtualBox.run_command! ['VBoxManage', '--nologo', 'list',
                                      '--long', 'hostifs']
    output.split("\n\n").map do |nic_info|
      info = Hash[nic_info.split("\n").map { |line|
        line.split(':', 2).map(&:strip)
      }]
      {
        :name => info['Name'], :ip => info['IPAddress'],
        :mask => info['NetworkMask'],
        :mac => info['HardwareAddress'].upcase.gsub(/[^0-9A-F]/, '')
      }
    end
  end
end  # class VirtualBox::Net

end  # namespace VirtualBox
