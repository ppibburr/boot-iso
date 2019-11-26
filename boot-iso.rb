
module BootISO
  class Storage
    attr_accessor :paths, :grub_cfg

    def initialize grub_cfg: nil
      @paths = ["/home/snapshot",(b="#{ENV['HOME']}/boot-iso")+"/mx", b+"/debian", b+"/ubuntu"]
      @grub_cfg = grub_cfg
      `touch #{grub_cfg}`
    end
    
    def target(f)
      File.expand_path(f)
    end
    
    def entries pth
      "submenu \"#{target(pth)}\" {\n"+
        Dir.glob("#{pth}/*.iso").map do |f|
          f = target(f)
          case File.basename(pth)
          when /mx|snapshot/
            """ submenu '#{f}' {
   menuentry '#{f} - lang=en_US kbd=us tz=America/New_York' {
      set iso_path=#{f}
      search --no-floppy --set=root --file $iso_path
      probe -u $root --set=buuid
      loopback loop $iso_path
      set root=(loop)
      
      linux  /antiX/vmlinuz buuid=$buuid fromiso=$iso_path quiet lang=en_US  kbd=us tz=America/New_York
      initrd /antiX/initrd.gz
   }
   
   menuentry '#{f} - text menus' {
      set iso_path=#{f}
      search --no-floppy --set=root --file $iso_path
      probe -u $root --set=buuid
      loopback loop $iso_path
      set root=(loop)
      
      linux  /antiX/vmlinuz buuid=$buuid fromiso=$iso_path quiet menus
      initrd /antiX/initrd.gz
   }
   
   menuentry '#{f} - Failsafe' {
      set iso_path=#{f}
      search --no-floppy --set=root --file $iso_path
      probe -u $root --set=buuid
      loopback loop $iso_path
      set root=(loop)
     
      linux  /antiX/vmlinuz buuid=$buuid fromiso=$iso_path quiet failsafe
      initrd /antiX/initrd.gz
   }
 }
"""
          else
          ""
          end
        end.join("\n")+
      "}"
    end
  
    def write_grub 
      base = open(grub_cfg).read.gsub(/(\# \<BootISO\>.*\# \<\/BootISO\>)/m,'').strip+"\n\n"
      File.open(grub_cfg, "w") do |f| 
        f.puts base
        f.puts "# <BootISO>"
        f.puts(paths.map do |p| File.exist?(p) ? entries(p) : "" end.join("\n"))
        f.puts "# </BootISO>"
      end    
    end
    
    def x *c
      c.each do |_|
        puts _
        system _
      end
    end
  end
  
  class HardDisk < Storage
    def initialize grub_cfg: "/boot/grub/custom.cfg"
      super
    end
  end
  
  class USB < Storage
    attr_reader :mount_point
    def target(f)
      super(f).gsub(mount_point,'')
    end  
    def initialize mount_point: nil
      @mount_point = File.expand_path(mount_point)
      super grub_cfg: mount_point+"/efi/boot/grub.cfg"
      @paths = ["#{mount_point}/snapshot",(b="#{mount_point}/boot-iso")+"/mx", b+"/debian", b+"/ubuntu"]
      @paths.each do |p| `mkdir -p #{p}` end
      #if !File.exist?(mount_point+"/boot/grub")
        `mkdir -p #{mount_point}/boot/grub`
        `touch #{mount_point}/boot/grub/grub.cfg`
      
        init_disk
      #end
    end
    
    def init_disk
      cmd="""grub-mkimage -o bootx64.efi -p /efi/boot -O x86_64-efi \
 fat iso9660 part_gpt part_msdos \
 normal boot linux configfile loopback chain \
 efifwsetup efi_gop efi_uga \
 ls search search_label search_fs_uuid search_fs_file \
 gfxterm gfxterm_background gfxterm_menu test all_video loadenv \
 exfat ext2 ntfs btrfs hfsplus udf"""
      x cmd
      x "cp -rf bootx64.efi #{mount_point}/efi/boot"
      x "rm bootx64.efi"
    end
  end
end

if ARGV.index("--usb")
  storage = BootISO::USB.new(mount_point: ARGV.last)
else
  storage = BootISO::HardDisk.new()
end

storage.write_grub
