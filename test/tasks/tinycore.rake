require 'fileutils'

# Tasks that build the TinyCore ISO used by the integration test.

# Produces TinyCore spins.
#
# The implementation is heavily based on the official instructions at
# http://wiki.tinycorelinux.net/wiki:remastering
class TinyCore
  # @return [String] path to the directory holding all the information
  attr_reader :base
  # @return [String] path to the vanilla Core ISO
  attr_reader :iso
  # @return [String] path to the unpacked version of the vanilla Core ISO
  attr_reader :cd_fs
  # @return [String] path to the directory caching extensions
  attr_reader :pkg
  # Path to the directory holding the contents of our remix's extension.
  # @return [String]
  attr_reader :ext_fs
  # @return [String] path to the CPIO+GZ file-system in the unpacked Core ISO
  attr_reader :fs_cpgz
  # @return [String] path to the unpacked version of the re-mastered ISO
  attr_reader :cd2_fs
  # @return [String] path to the CPIO+GZ with our remix's extension.
  attr_reader :ext_cpgz
  # @return [String] path to the CPIO+GZ file-system in the remixed Core ISO
  attr_reader :fs2_cpgz
  # @return [String] path to the remixed ISO
  attr_reader :iso2

  def initialize(base_path)
    @base = base_path
    recompute_paths
  end
  
  # Computes all the working paths based on the base path. 
  def recompute_paths
    @cd_fs = File.join base, 'cd'
    @cd2_fs = File.join base, 'cd2'
    @ext_fs = File.join base, 'ext'
    @pkg = File.join base, 'pkg'
    
    @iso = File.join base, 'core.iso'
    @iso2 = File.join base, 'remix.iso'
    @fs_cpgz = File.join cd_fs, 'boot/core.gz'
    @fs2_cpgz = File.join cd2_fs, 'boot/core.gz'
    @ext_cpgz = File.join pkg, 'remix_ext.gz'
  end
  private :recompute_paths
  
  # Ensures that the TinyCore CD file-system is unpacked somewhere.
  #
  # This method might download the core ISO, and unpack it.
  #
  # @return [String] the same path returned by #ext_fs
  def ensure_cd_fs_available
    return cd_fs if File.exist? cd_fs
    
    download_iso unless File.exist? iso
    unpack_iso
    ext_fs
  end
  
  # Downloads the core ISO.
  #
  # @raise [RuntimeError] if there's an error downloading the ISO
  # @return [TinyCore] self, for easy call chaining
  def download_iso
    FileUtils.mkdir_p base
    url = 'http://distro.ibiblio.org/tinycorelinux/4.x/x86/' +
          'release/Core-current.iso'
    download_file url, iso
    self
  end
  private :download_iso
  
  # Unpacks the core ISO.
  #
  # @raise [RuntimeError] if there's an error unpacking the ISO
  # @return [TinyCore] self, for easy call chaining
  def unpack_iso
    FileUtils.mkdir_p cd_fs
    unless shell "7z x -y -o#{cd_fs} #{iso}"
      FileUtils.rm_rf cd_fs
      raise "ISO unpacking failed"
    end
    self
  end
  private :unpack_iso
  
  # Ensures that a TinyCore extension and its dependencies are downloaded.
  #
  # @param [String] package_name the name of the package (e.g., "openssh")
  # @return [String] the file-system path where the package was downloaded
  def ensure_package_available(package_name)
    package_file = File.join pkg, "#{package_name}.tcz"
    return package_file if File.exist?(package_file)
    
    # NOTE: The check above relies on the dependencies being installed before
    #       the package itself.
    package_deps(package_name).each do |dependency|
      ensure_package_available dependency
    end
    
    package_url = 'http://distro.ibiblio.org/tinycorelinux/4.x/x86/tcz/' +
                  "#{package_name}.tcz"
    FileUtils.mkdir_p pkg
    download_file package_url, package_file
  end
  
  # The TinyCore packages that a package directly depends on.
  #
  # This method downloads the package's .dep file, if it doesn't already exist.
  #
  # @param [String] package_name the name of the package (e.g., "openssh")
  # @return [Array<String>] names of the package's direct dependencies
  def package_deps(package_name)
    FileUtils.mkdir_p pkg
    
    info_file = File.join pkg, "#{package_name}.tcz.dep"
    unless File.exist? info_file
      info_url = 'http://distro.ibiblio.org/tinycorelinux/4.x/x86/tcz/' +
                 "#{package_name}.tcz.dep"
      download_file info_url, info_file
    end
    
    deps = []
    File.read(info_file).split.map do |dep|
      break unless /\.tcz\Z/ =~ dep
      deps << dep.sub(/\.tcz\Z/, '')
    end
    deps
  end
  private :package_deps

  # Installs a TinyCore package and its deps to the extension file-system.
  #
  # @param [String] package_name the name of the package (e.g., "openssh")
  # @raise [RuntimeError] if some package download or decompression fails
  # @return [TinyCore] the same path returned by #ext_fs
  def install_package(package_name)
    ensure_package_available package_name
    package_transitive_deps(package_name).reverse.each do |dependency|
      unpack_package dependency
    end
    ext_fs
  end
  
  # All the TinyCore packages that a package indirectly depends on.
  #
  # This method downloads the referenced .dep files, if they don't already
  # exist.
  #
  # @param [String] package_name the name of the package (e.g., "openssh")
  # @param [Hash<String, Boolean>] dependencies internal argument that tracks
  #     the dependency table as it is being built
  # @return [Array<String>] names of all the packages that the given package
  #     indirectly depends on, including itself
  def package_transitive_deps(package_name, dependencies = {})
    dependencies[package_name] = true
    package_deps(package_name).each do |dependency|
      next if dependencies.has_key? dependency
      package_transitive_deps dependency, dependencies
    end
    dependencies.keys
  end
  private :package_transitive_deps
  
  # Extracts a TinyCore package to the extension file-system.
  #
  # @param [String] package_name the name of the package (e.g., "openssh")
  # @raise [RuntimeError] if the package decompression fails
  # @return [TinyCore] self, for easy call chaining
  def unpack_package(package_name)
    package_tcz = File.expand_path ensure_package_available(package_name)
    FileUtils.mkdir_p ext_fs
    out_dir = File.expand_path ext_fs
    unless shell "unsquashfs -d #{out_dir} -f -n #{package_tcz}"
      raise "TCZ unpacking failed"
    end
    self
  end
  private :unpack_package
  
  # Runs a block of code in the root of the extension file-system.
  # @return [Object] the return value of the given block
  def change_ext_fs(&block)
    FileUtils.mkdir_p ext_fs
    Dir.chdir ext_fs do
      yield self
    end
  end
  
  # Adds an init.d service to the list of services to be started at boot.
  # @return [TinyCore] self, for easy call chaining
  def autoboot_service(service_name)
    bootlocal = ensure_bootlocal_available
    
    path = File.join '/usr/local/etc/init.d', service_name
    unless File.exist?(ext_fs + path)
      path = File.join '/etc/init.d', service_name
    end
    
    commands = File.read(bootlocal).split
    return self if commands.any? { |command| /^#{path}/ =~ command }
    File.open(bootlocal, 'ab') { |f| f.write "#{path} start\n" }
    self
  end
  
  # Ensures that the bootlocal.sh file holding startup commands exists.
  #
  # If necessary, this method will create the file and its enclosing
  # directories, and set correct permissions on everything.
  #
  # @return [String] the path to the bootlocal.sh file in the unpacked extension
  #     filesystem
  def ensure_bootlocal_available
    opt = File.join ext_fs, 'opt'
    FileUtils.mkdir_p opt
    File.chmod 02775, opt
    
    bootlocal = File.join opt, 'bootlocal.sh'
    unless File.exist? bootlocal
      File.open(bootlocal, 'wb') { |f| f.write "#!/bin/sh\n" }
    end
    File.chmod 0775, bootlocal
    bootlocal
  end
  private :ensure_bootlocal_available
  
    
  def remaster
    ensure_cd2_fs_available
    build_initrd
    config_bootldr
    build_iso
  end
  
  # Ensures that the re-mastered CD file-system exists.
  #
  # If necessary, this method can download the Core ISO and unpack it, then
  # copy the unpacked version over.
  def ensure_cd2_fs_available
    return cd2_fs if File.exist?(cd2_fs)
    
    ensure_cd_fs_available
    FileUtils.cp_r cd_fs, cd2_fs
  end
  private :ensure_cd2_fs_available
  
  # Builds the file used as the initial RAM file-system by the remixed ISO.
  #
  # @return [String] the path to the initrd file.
  def build_initrd
    ensure_cd2_fs_available
    build_extension
    File.open fs2_cpgz, 'wb' do |f|
      f.write File.read_binary(fs_cpgz)
      f.write File.read_binary(ext_cpgz)
    end
    fs2_cpgz
  end
  private :build_initrd
  
  # Builds a GZ+CPIO initramfs extension out of the extension file-system.
  #
  # @return [String] the path to the GZ+CPIO file
  def build_extension
    FileUtils.mkdir_p pkg
    out_file = File.expand_path ext_cpgz
    Dir.chdir ext_fs do
      command = 'find . | cpio -o --format newc --owner=0:0 | ' +
                "gzip -2 > #{out_file}"
      unless shell command
        raise "CP+GZ packing error"
      end
      unless shell "advdef --recompress --shrink-insane --quiet #{out_file}"
        raise "CP+GZ re-compression error"
      end
    end
    ext_cpgz
  end
  private :build_extension
  
  # Patches the boot-loader configuration on the remixed ISO.
  #
  # The patched configuration has the timeout removed, for instant VM booting.
  #
  # @return [String] the path to the patched configuration file.
  def config_bootldr
    ensure_cd2_fs_available
    config_file = File.join cd2_fs, 'boot/isolinux/isolinux.cfg'
    data = File.read config_file
    data.gsub!(/^prompt .*$/, 'prompt 0')
    data.gsub!(/^timeout .*$/, 'timeout 0')
    File.open(config_file, 'w') { |f| f.write data }
    config_file
  end
  
  # Creates an ISO image out of the unpacked remixed CD file-system.
  #
  # @return [String] the path to the newly created ISO file
  def build_iso
    ensure_cd2_fs_available
    
    label = 'remixed-tc'
    boot_loader = 'boot/isolinux/isolinux.bin'
    boot_catalog = 'boot/isolinux/boot.cat'
    
    command = "mkisofs -l -J -R -r -V #{label} -no-emul-boot " +
              "-boot-load-size 4 -quiet " +
              "-boot-info-table -b #{boot_loader} -c #{boot_catalog} " +
              "-o #{iso2} #{cd2_fs}"
    unless shell command
      raise "ISO creation failed"
    end
    iso2
  end
  
  # Helper method for downloading a file over HTTP.
  #
  # @param [String] url the URL to download the file from
  # @param [String] file the file-system path where the file will be saved
  # @raise [RuntimeError] if there's an error downloading the file
  # @return [String] the value of the "file argument"
  def download_file(url, file)
    return file if shell("curl -o #{file} #{url}")
    
    File.unlink file if File.exist?(file)
    raise "Download failed"
  end
  private :download_file
  
  # Runs a shell command.
  # @param [String] command the command to be executed
  # @return [Boolean] true if the command's exit code was 0, false otherwise
  def shell(command)
    Kernel.system command
  end
  private :shell

  # Runs a shell command with super-user privileges.
  # @param [String] command the command to be executed
  # @return [Boolean] true if the command's exit code was 0, false otherwise
  def su_shell(command)
    # TODO(pwnall): use shellwords responsibly
    Kernel.system "sudo -i \"#{command}\""
  end
  private :su_shell
end

# All TinyCore files will be created here. This should be gitignored.
tinycore = TinyCore.new 'test/fixtures/tinycore'

file tinycore.iso2 do
  tinycore.ensure_cd_fs_available
  tinycore.install_package 'coreutils'
  tinycore.install_package 'openssh'
  tinycore.autoboot_service 'openssh'
    
  tinycore.change_ext_fs do
    FileUtils.cp 'usr/local/etc/ssh/ssh_config.example',
                 'usr/local/etc/ssh/ssh_config'
    FileUtils.cp 'usr/local/etc/ssh/sshd_config.example',
                 'usr/local/etc/ssh/sshd_config'
    data = File.read 'usr/local/etc/ssh/sshd_config'
    data.gsub!(/^#PasswordAuthentication .*$/, 'PasswordAuthentication yes')
    data.gsub!(/^#PermitEmptyPasswords .*$/, 'PermitEmptyPasswords yes')
    File.open 'usr/local/etc/ssh/sshd_config', 'w' do |f|
      f.write data
    end
  end
  
  tinycore.remaster
end

task :fixtures => tinycore.iso2
