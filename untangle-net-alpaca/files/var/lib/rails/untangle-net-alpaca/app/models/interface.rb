class Interface < ActiveRecord::Base
  ## Link for a static configuration
  has_one :intf_static, :dependent => :destroy
  
  ## Link for the dynamic/dhcp configuration
  has_one :intf_dynamic, :dependent => :destroy

  ## Link for the bridge configuration.
  has_one :intf_bridge, :dependent => :destroy

  ## Link for the pppoe configuration.
  has_one :intf_pppoe, :dependent => :destroy

  ## Link for all of the interfaces that are bridged with this interface.
  has_many( :bridged_interfaces, :class_name => "IntfBridge", :foreign_key => "bridge_interface_id" )

  def Interface.valid_dhcp_server?
    dhcp_server_settings = DhcpServerSettings.find( :first )
    if dhcp_server_settings.nil? or dhcp_server_settings.enabled == false
      return true
    end
    if dhcp_server_settings.start_address.nil? or dhcp_server_settings.start_address.length == 0 or dhcp_server_settings.end_address.nil? or dhcp_server_settings.end_address.length == 0
      return false
    end
    start_address = IPAddr.new( dhcp_server_settings.start_address )
    end_address = IPAddr.new( dhcp_server_settings.end_address )
    interfaces = Interface.find( :all )
    interfaces.each do |interface|
      if interface.config_type == InterfaceHelper::ConfigType::STATIC and ! interface.intf_static.nil?
        interface.intf_static.ip_networks.each do |ip_network|
          ip_addr = IPAddr.new( ip_network.ip + "/" + ip_network.netmask )
          if ip_addr.include?( start_address ) and ip_addr.include?( end_address )
            return true
          end
        end
      end
    end
    return false
  end

  ## Return true if this interface is bridged with another interface
  def is_bridge?
    ## If the config is in bridge mode, then just return true if the bridged
    ## interface is non-nil
    return !intf_bridge.bridge_interface.nil? if self.config_type == InterfaceHelper::ConfigType::BRIDGE
    
    ## Otherwise grab all of the bridged interfaces and check if any of them
    ## are actually configured as bridges
    bi = self.bridged_interfaces.map{ |ib| ib.interface }
    bi = bi.delete_if { |ib| ib.nil? || ib.config_type != InterfaceHelper::ConfigType::BRIDGE }
    
    ## If there are any entries, then this is a bridge
    ( bi.nil? || bi.empty? ) ? false : true
  end
  
  ## Get the config type
  def current_config
    case self.config_type
    when InterfaceHelper::ConfigType::STATIC
      return intf_static
    when InterfaceHelper::ConfigType::DYNAMIC
      return intf_dynamic
    when InterfaceHelper::ConfigType::BRIDGE
      return intf_bridge
    when InterfaceHelper::ConfigType::PPPOE
      return intf_pppoe
    end

    ## unknown config type?
    nil
  end

  class ConfigVisitor
    def intf_static( interface, config )
    end

    def intf_dynamic( interface, config )
    end

    def intf_bridge( interface, config )
    end

    def intf_pppoe( interface, config )
    end
  end

  def visit_config( visitor )
    current_config.accept( self, visitor )
  end


  def carrier
    carrier = "Unknown".t
    begin
      f = "/sys/class/net/" + self.os_name + "/carrier"
      sysfs = File.new( f, "r" )
      c = sysfs.readchar
      if c == 49 #ascii for 1
        carrier = "Connected".t
      else
        carrier = "Disconnected".t
      end
    rescue Exception => exception
      logger.error "Error reading carrier status: " + exception.to_s
      carrier = "Unknown".t
    end
    return carrier
  end

  def interface_status
    return `/usr/share/untangle-net-alpaca/scripts/get-interface-status #{self.os_name}`
  end

  def current_mtu
    mtu_line = `ifconfig #{self.os_name} | grep MTU`
    after_label = mtu_line.split("MTU:")[1]
    mtu = after_label.split(" ")[0]
    return mtu
  end

  def hardware_address
    address = "Unknown".t
    begin
      sysfs = File.new( "/sys/class/net/" + self.os_name + "/address", "r" )
      address = sysfs.readline
    rescue Exception => exception
      address = "Unknown".t
    end
    return address
  end


end
