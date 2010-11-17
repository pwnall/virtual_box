# Configure VirtualBox's DHCP server for virtual networks.

# :nodoc: namespace
module VirtualBox


# Descriptor for a VirtualBox DHCP server rule.
class Dhcp
  # Name for the VirtualBox internal network.
  attr_accessor :name
  
  # IP address of the DHCP server.
  attr_accessor :ip
  
  # Network mask reported by the DHCP server.
  attr_accessor :netmask
  
  # First IP address in the DHCP server address pool.
  attr_accessor :start_ip

  # Last IP address in the DHCP server address pool.
  attr_accessor :end_ip

  undef :ip
  # :nodoc: defined as accessor
  def ip
    @ip ||= self.class.ip_btos((self.class.ip_stob(start_ip) &
                                self.class.ip_stob(netmask)) + 1)
  end

  undef :netmask
  # :nodoc: defined as accessor
  def netmask
    @netmask ||= '255.255.255.0'
  end

  undef :start_ip
  # :nodoc: defined as accessor
  def start_ip
    @start_ip ||= self.class.ip_btos(self.class.ip_stob(ip) + 1)
  end

  undef :end_ip
  # :nodoc: defined as accessor
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
  def unregister
    VirtualBox.run_command ['VBoxManage', 'dhcpserver', 'remove',
                            '--netname', name]
    self
  end
  
  # Array of all the DHCP rules registered with VirtualBox.
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
  # Args:
  #   disk_info:: output from VBoxManage list --long dhcpservers for one rule
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
  def self.ip_btos(ip_number)
    [ip_number].pack('N').unpack('C*').join('.')
  end
  
  # Converts an IP string into a number.
  def self.ip_stob(ip_string)
    ip_string.split('.').map(&:to_i).pack('C*').unpack('N').first
  end
end  # class VirtualBox::Dhcp

end  # namespace VirtualBox
