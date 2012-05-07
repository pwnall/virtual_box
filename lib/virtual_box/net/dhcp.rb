module VirtualBox

class Net

# Specification for a virtual DHCP server.
class Dhcp
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
  
  # Adds this DHCP server to VirtualBox.
  #
  # @param [String, VirtualBox::Net] net_or_name the name of the VirtualBox
  #     virtual network that this server will be connected to
  # @return [VirtualBox::Net::Dhcp] self, for easy call chaining
  def add(net_or_name)
    command = ['VBoxManage', 'dhcpserver', 'add', '--ip', ip,
        '--netmask', netmask, '--lowerip', start_ip, '--upperip', end_ip,
        '--enable']
    if net_or_name.kind_of? VirtualBox::Net
      command.push '--ifname', net_or_name.name
    else
      command.push '--netname', net_or_name
    end

    VirtualBox.run_command! command
    self
  end
  
  # Removes this DHCP server from VirtualBox.
  #
  # @param [String, VirtualBox::Net] net_or_name the name of the VirtualBox
  #     virtual network that this server was connected to
  # @return [VirtualBox::Net::Dhcp] self, for easy call chaining
  def remove(net_or_name)
    command = ['VBoxManage', 'dhcpserver', 'remove']
    if net_or_name.kind_of? VirtualBox::Net
      command.push '--ifname', net_or_name.name
    else
      command.push '--netname', net_or_name
    end

    VirtualBox.run_command command
    self
  end
  
  # The DHCP servers added to with VirtualBox.
  #
  # @return [Hash<String, VirtualBox::Dhcp>] all the DHCP servers added to
  #     VirtualBox, indexed by the name of the virtual network that they serve
  def self.all
    output = VirtualBox.run_command! ['VBoxManage', '--nologo', 'list',
                                      '--long', 'dhcpservers']
    Hash[output.split("\n\n").map { |dhcp_info|
      dhcp = new
      if_name = dhcp.from_dhcp_info(dhcp_info)
      [if_name, dhcp]
    }]
  end
  
  # Parses information about a DHCP server returned by VirtualBox.
  #
  # The parsed information is used to replace this network's specification.
  # @param [String] dhcp_info output from "VBoxManage list --long dhcpservers"
  #                           for one server
  # @return [String] the name of the virtual network served by this DHCP server
  def from_dhcp_info(dhcp_info)
    info = Hash[dhcp_info.split("\n").map { |line|
      line.split(':', 2).map(&:strip)
    }]

    self.ip = info['IP']
    self.netmask = info['NetworkMask']
    self.start_ip = info['lowerIPAddress']
    self.end_ip = info['upperIPAddress']

    info['NetworkName']
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
end  # class VirtualBox::Net::Dhcp

end  # class VirtualBox::Net

end  # namespace VirtualBox
