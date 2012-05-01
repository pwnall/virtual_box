module VirtualBox

# Specification for a virtual DHCP server.
class Dhcp
  # The name of the VirtualBox network served by this DHCP server.
  #
  # This name must match the name of a host-only or internal network that is
  # registered with VirtualBox.
  # @return [String]
  attr_accessor :net_name
  
  # This DHCP server's IP address on the virtual network that it serves.
  # @return [String]
  attr_accessor :ip
  
  # The network mask reported by this DHCP server.
  # @return [String]
  attr_accessor :netmask
  
  # The first IP address in this DHCP server's address pool.
  # @return [String]
  attr_accessor :start_ip

  # The last IP address in this DHCP server's address pool.
  # @return [String]
  attr_accessor :end_ip

  undef :ip
  def ip
    @ip ||= self.class.ip_btos((self.class.ip_stob(start_ip) &
                                self.class.ip_stob(netmask)) + 1)
  end

  undef :netmask
  def netmask
    @netmask ||= '255.255.255.0'
  end

  undef :start_ip
  def start_ip
    @start_ip ||= self.class.ip_btos(self.class.ip_stob(ip) + 1)
  end

  undef :end_ip
  def end_ip
    nm = self.class.ip_stob(netmask)
    @end_ip ||= self.class.ip_btos((self.class.ip_stob(start_ip) & nm) +
                                   ~nm - 1)
  end

  # Creates a DHCP server specification based on the given attributes.
  #
  # The DHCP server is not automatically added to VirtualBox.
  # @param [Hash<Symbol, Object>] options ActiveRecord-style initial values for
  #     attributes; can be used together with Net#to_hash to save and restore
  def initialize(options = {})
    options.each { |k, v| self.send :"#{k}=", v }
  end
  
  # Hash capturing this specification. Can be passed to Dhcp#new.
  #
  # @return [Hash<Symbol, Object>] Ruby-friendly Hash that can be used to
  #                                re-create this DHCP server specification
  def to_hash
    { :net_name => 'net_name', :ip => ip, :netmask => netmask,
      :start_ip => start_ip, :end_ip => end_ip }
  end
  
  # True if this DHCP rule has been registered with VirtualBox.
  def live?
    servers = self.class.all
    dhcp = servers.find { |server| server.net_name == net_name }
    dhcp ? true : false
  end
  
  # Adds this DHCP server to VirtualBox.
  #
  # @return [VirtualBox::Dhcp] self, for easy call chaining
  def add
    remove if live?
    
    result = VirtualBox.run_command ['VBoxManage', 'dhcpserver', 'add',
        '--netname', net_name, '--ip', ip, '--netmask', netmask,
        '--lowerip', start_ip, '--upperip', end_ip, '--enable']
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    self
  end
  
  # Removes this DHCP server from VirtualBox.
  #
  # @return [VirtualBox::Dhcp] self, for easy call chaining
  def remove
    VirtualBox.run_command ['VBoxManage', 'dhcpserver', 'remove', '--netname',
                            net_name]
    self
  end
  
  # The DHCP servers added to with VirtualBox.
  #
  # @return [Array<VirtualBox::Dhcp>] all the DHCP servers added to VirtualBox
  def self.all
    result = VirtualBox.run_command ['VBoxManage', '--nologo', 'list', '--long',
                                     'dhcpservers']
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    result.output.split("\n\n").
                  map { |dhcp_info| new.from_dhcp_info(dhcp_info) }
  end
  
  # Parses information about a DHCP server returned by VirtualBox.
  #
  # The parsed information is used to replace this network's specification.
  # @param [String] dhcp_info output from "VBoxManage list --long dhcpservers"
  #                           for one server
  # @return [VirtualBox::Dhcp] self, for easy call chaining
  def from_dhcp_info(dhcp_info)
    info = Hash[dhcp_info.split("\n").map { |line|
      line.split(':', 2).map(&:strip)
    }]

    self.net_name = info['NetworkName']
    self.ip = info['IP']
    self.netmask = info['NetworkMask']
    self.start_ip = info['lowerIPAddress']
    self.end_ip = info['upperIPAddress']
    self
  end
  
  # Converts an IP number into a string.
  #
  # @param [Integer] ip_number a 32-bit big-endian number holding an IP address
  # @return [String] the IP address, encoded using the dot (.) notation
  def self.ip_btos(ip_number)
    [ip_number].pack('N').unpack('C*').join('.')
  end
  
  # Converts an IP string into a number.
  #
  # @param [String] ip_string an IP address using the dot (.) notation
  # @return [Integer] the IP adddres, encoded as a 32-bit big-endian number
  def self.ip_stob(ip_string)
    ip_string.split('.').map(&:to_i).pack('C*').unpack('N').first
  end
end  # class VirtualBox::Dhcp

end  # namespace VirtualBox
