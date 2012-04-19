# Run code via the command-line interface.

require 'English'
require 'shellwords'

# :nodoc: namespace
module VirtualBox


# Descriptor for a VirtualBox hard-disk or DVD image.
class Disk
  # Path to the file storing the disk image.
  attr_accessor :file
  
  # The disk image format. Can be :raw, :vdi, :vmdk, or :vhd.
  attr_accessor :format
  
  # The type of media that the image represents. Can be :disk or :dvd
  attr_accessor :media
  
  # The UUID that the image is registered with in VirtualBox.
  attr_accessor :uid
  
  undef :format
  # :nodoc: documented as accessor
  def format
    @format ||= self.class.guess_image_format file
  end

  undef :media
  # :nodoc: documented as accessor
  def media
    @media ||= self.class.guess_media_type file
  end
  
  undef :uid
  # :nodoc: documented as accessor
  def uid
    @uid ||= UUID.generate
  end
  
  # Creates a new image descriptor based on the given attributes.
  #
  # This does not create a file, or register a disk image with VirtualBox.
  def initialize(options)
    options.each { |k, v| self.send :"#{k}=", v }
    self.file = File.expand_path file
  end

  # True if this disk image has been registered with VirtualBox.
  def registered?
    images = (media == :dvd) ? self.class.registered_dvds :
                               self.class.registered_hdds
    image = images.find { |image| image.file == file }
    if image
      self.uid = image.uid
      return true
    end
    false
  end
  
  # Registers this disk with VirtualBox.
  def register
    unregister if registered?
    
    if media == :dvd
      command = ['VBoxManage', 'openmedium', media.to_s, '--uuid', uid]
    else
      command = ['VBoxManage', 'openmedium', media.to_s, file,
                 '--type', 'normal', '--uuid', uid]
    end
    result = VirtualBox.run_command command
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    self
  end
  
  # De-registers this disk from VirtualBox's database.
  def unregister
    VirtualBox.run_command ['VBoxManage', 'closemedium', media.to_s, file]
    self
  end
  
  # Returns an array of Disk instances for the registered images.
  def self.registered
    registered_hdds + registered_dvds
  end
  
  # Array of disk images corresponding to the HDDs registered with VirtualBox.
  def self.registered_hdds
    result = VirtualBox.run_command ['VBoxManage', '--nologo', 'list',
                                     '--long', 'hdds']
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    result.output.split("\n\n").
                  map { |disk_info| parse_disk_info disk_info, :disk }
  end
  
  # Array of disk images corresponding to the DVDs registered with VirtualBox.
  def self.registered_dvds
    result = VirtualBox.run_command ['VBoxManage', '--nologo', 'list',
                                     '--long', 'hdds']
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    dvds = result.output.split("\n\n").
                  map { |disk_info| parse_disk_info disk_info, :dvd }
  end

  # Parses information about a disk returned by the VirtualBox manager.
  #
  # Args:
  #   disk_info:: output from VBoxManage list --long hdds for one disk
  #   media:: :hdd or :dvd
  def self.parse_disk_info(disk_info, media)
    i = Hash[disk_info.split("\n").map { |line| line.split(':').map(&:strip) }]
    
    format = i['Format'].downcase.to_sym
    path = i['Location']
    type = i['Type']
    uid = i['UUID']
    parent_uid = i['Parent UUID']
    parent_uid = nil if parent_uid == 'base'
    
    new :file => path, :uid => uid, :format => format, :media => media
  end
  
  # Creates a VirtualBox disk image.
  #
  # The options hash takes the following keys:
  #   file:: the path to the file that will contain the disk image
  #   size:: the image size, in bytes
  #   format:: image format (can also be auto-detected by the file extension)
  #   prealloc:: if false, the image file grows as blocks are used
  #
  # Returns a Disk instance describing the image that was created.
  def self.create(options)
    path = options[:file]
    format = options[:format] || guess_image_format(path)
    size_mb = (options[:size] / (1024 * 1024)).to_i
    memo = options[:memo] || 'Created with the virtual_box RubyGem'
    variant = options[:prealloc] ? 'Fixed' : 'Standard'
    
    result = VirtualBox.run_command ['VBoxManage', '--nologo', 'createhd',
        '--filename', path, '--size', size_mb.to_s, '--format', format.to_s,
        '--variant', variant]
    if result.status != 0
      raise 'Unexpected error code returned by VirtualBox'
    end
    uid_match = /UUID: (.*)$/.match result.output
    unless uid_match
      raise 'VirtualBox output does not include disk UUID'
    end
    
    Disk.new :file => path, :format => format, :media => :disk,
             :uid => uid_match[1]
  end
  
  # Disk image format based on the extension in the file name.
  def self.guess_image_format(image_file)
    parts = File.basename(image_file).split('.')
    if parts.length >= 2
      case parts.last
      when 'vdi'
        :vdi
      when 'vmdk'
        :vmdk
      when 'vhd'
        :vhd
      when 'iso'
        :raw
      else
        :vdi
      end
    else
      :vdi
    end
  end
  
  # Disk media type on the extension in the file name.
  def self.guess_media_type(image_file)
    parts = File.basename(image_file).split('.')
    if parts.length >= 2
      case parts.last
      when 'iso'
        :dvd
      else
        :disk
      end
    else
      :disk
    end
  end
end  # class VirtualBox::Disk

end  # namespace VirtualBox
