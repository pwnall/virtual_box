# Configures VirtualBox's DHCP server for virtual networks.

module VirtualBox

# Descriptor for a VirtualBox DHCP server rule.
class Dhcp
  # The name of the VirtualBox internal network served by this DHCP server.
  # @return [String]
  attr_accessor :name
  
  # The DHCP server's IP address.
  # @return [String]
  attr_accessor :ip
  
  # The network mask reported by the DHCP server.
  # @return [String]
  attr_accessor :netmask
  
  # The first IP address in the DHCP server address pool.
  # @return [String]
  attr_accessor :start_ip

  # The last IP address in the DHCP server address pool.
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

  # Creates a DHCP rule based on the given attributes.
  #
  # This does not register the rule with VirtualBox.
  def initialize(options)
    options.each { |k, v| self.send :"#{k}=", v }
  end
  
  # True if this DHCP rule has been registered with VirtualBox.
  def registered?
    rules = self.class.registered
    rule = rules.find { |rule| rule.name == name }
    rule ? true : false
  end
  
  # Registers this disk with VirtualBox.
  #
  # @return [VirtualBox::Dhcp] self, for easy call chaining
  def register
    unregister if registered?
    
    result = VirtualBox.run_command ['VBoxManage', 'dhcpserver', 'add',
        '--netname', name, '--ip', ip, '--netmask', netmask,
        '--lowerip', start_ip, '--upperip', end_ip, '--enable']
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    self
  end
  
  # De-registers this disk from VirtualBox's database.
  #
  # @return [VirtualBox::Dhcp] self, for easy call chaining
  def unregister
    VirtualBox.run_command ['VBoxManage', 'dhcpserver', 'remove',
                            '--netname', name]
    self
  end
  
  # All the DHCP rules registered with VirtualBox.
  #
  # @return [Array<VirtualBox::Dhcp the DHCP rules registered with VirtualBox
  def self.registered
    result = VirtualBox.run_command ['VBoxManage', '--nologo', 'list',
                                     '--long', 'dhcpservers']
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    result.output.split("\n\n").
                  map { |dhcp_info| parse_dhcp_info dhcp_info }
  end
  
  # Parses information about a DHCP rule returned by VirtualBox.
  #
  # @param [String] disk_info output from "VBoxManage list --long dhcpservers"
  #                           for one rule
  # @return [VirtualBox::Dhcp] self, for easy call chaining
  def self.parse_dhcp_info(dhcp_info)
    i = Hash[dhcp_info.split("\n").map { |line| line.split(':').map(&:strip) }]
    
    name = i['NetworkName']
    ip = i['IP']
    netmask = i['NetworkMask']
    start_ip = i['lowerIPAddress']
    end_ip = i['upperIPAddress']
    
    new :name => name, :ip => ip, :netmask => netmask, :start_ip => start_ip,
                       :end_ip => end_ip
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
