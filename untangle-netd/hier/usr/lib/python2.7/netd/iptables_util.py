import os
import sys
import subprocess
import datetime
import traceback
import string
from netd.network_util import NetworkUtil

# This class is a utility class with utility functions providing
# useful tools for dealing with iptables rules
class IptablesUtil:

    settings = None

    @staticmethod
    def interface_condition_string_to_interface_list( value ):
        intfs = []
        
        for substr in value.split(","):
            if substr == "wan":
                intf_values  = NetworkUtil.wan_list()
                for intfId in intf_values:
                    if intfId not in intfs:
                        intfs.append(intfId)
            elif substr == "non_wan":
                intf_values  = NetworkUtil.non_wan_list()
                for intfId in intf_values:
                    if intfId not in intfs:
                        intfs.append(intfId)
                intfs.append(0xfa) # OpenVPN (250) is a non_wan 
                intfs.append(0xfb) # L2TP (251) is a non_wan 
                intfs.append(0xfc) # Xauth (252) is a non_wan 
                intfs.append(0xfd) # GRE (253) is a non_wan 
            else:
                intfs.append(int(substr))

        return intfs
                    

    # This method takes a list of conditions from a rule and translates them into a string containing the iptables conditions
    # It returns a list of strings, because some set of conditions require multiple iptables rules
    # Example input: ['conditionType':'SRC_INTF', 'value':'1'] -> ["-m connmark --mark 0x01/0xff"]
    # Example input: ['conditionType':'DST_PORT', 'value':'123'] -> ["-p udp --dport 123", "-p tcp --dport 123"]
    @staticmethod
    def conditions_to_iptables_string( conditions, comment=None, verbosity=0 ):
        
        current_strings = [ "" ];

        if conditions is None:
            return current_strings;

        if comment != None:
                current_strings = [ current + (" -m comment --comment \"%s\" " % comment)  for current in current_strings ]

        hasProtocolCondition = False
        for condition in conditions:
            if 'conditionType' not in condition:
                print "ERROR: Ignoring invalid condition: %s" % str(condition)
                continue
            if condition['conditionType'] == 'PROTOCOL':
                hasProtocolCondition = True

        for condition in conditions:
            if 'conditionType' not in condition:
                print "ERROR: Ignoring invalid condition: %s" % str(condition)
                continue

            conditionStr = ""
            conditionType = condition['conditionType']
            invert = False
            value = None
            if 'value' in condition:
                value = condition['value']
            if 'invert' in condition and condition['invert']:
                invert = True

            if conditionType == "PROTOCOL":
                if "any" in value:
                    continue

                protos = value.split(",")
                if invert and len(protos)>1:
                    print "ERROR: invert not supported on multiple protocol condition"
                    continue
                if len(protos) == 0:
                    print "ERROR: interface condition with no interfaces"
                    continue
                orig_current_strings = current_strings
                current_strings = []
                # split current rules for each protocol specified
                for i in range(0 , len(protos) ):
                    conditionStr = ""
                    if invert:
                        conditionStr = conditionStr + " ! "
                    conditionStr = conditionStr + (" --protocol %s " % string.lower(protos[i]))
                    current_strings = current_strings + [ conditionStr + current for current in orig_current_strings ]

            if conditionType == "SRC_INTF":
                if "any" in value:
                    continue # no need to do anything

                intfs = IptablesUtil.interface_condition_string_to_interface_list( value )

                if invert and len(intfs) > 1:
                    print "ERROR: invert not supported on multiple interface condition"
                    continue
                if len(intfs) == 0:
                    print "ERROR: interface condition with no interfaces"
                    continue
                orig_current_strings = current_strings
                current_strings = []
                # split current rules for each intf specified
                for i in range(0 , len(intfs) ):
                    conditionStr = ""
                    if invert:
                        conditionStr = conditionStr + " ! "
                    conditionStr = conditionStr + (" -m connmark --mark 0x%04X/0x00FF " % int(intfs[i]))
                    current_strings = current_strings + [ current + conditionStr for current in orig_current_strings ]

            if conditionType == "DST_INTF":
                if "any" in value:
                    continue # no need to do anything

                intfs = IptablesUtil.interface_condition_string_to_interface_list( value )

                if invert and len(intfs) > 1:
                    print "ERROR: invert not supported on multiple interface condition"
                    continue
                if len(intfs) == 0:
                    print "ERROR: interface condition with no interfaces"
                    continue
                orig_current_strings = current_strings
                current_strings = []
                # split current rules for each intf specified
                for i in range(0 , len(intfs) ):
                    conditionStr = ""
                    if invert:
                        conditionStr = conditionStr + " ! "
                    conditionStr = conditionStr + (" -m connmark --mark 0x%04X/0xFF00 " % (int(intfs[i]) << 8))
                    current_strings = current_strings + [ current + conditionStr for current in orig_current_strings ]

            if conditionType == "SRC_MAC":
                if invert:
                    conditionStr = conditionStr + " ! "
                conditionStr = conditionStr + " -m mac --mac-source %s " % value
                current_strings = [ current + conditionStr for current in current_strings ]

            if conditionType == "SRC_ADDR":
                if "any" in value:
                    continue # no need to do anything

                srcs = value.split(",")
                if invert and len(srcs) > 1:
                    print "ERROR: invert not supported on multiple addr condition"
                    continue
                if len(srcs) == 0:
                    print "ERROR: address condition with no interfaces"
                    continue

                orig_current_strings = current_strings
                current_strings = []
                for i in srcs:
                    conditionStr = ""
                    if invert:
                        conditionStr = conditionStr + " ! "
                    if "-" in i:
                        conditionStr = conditionStr + " -m iprange --src-range %s " % i
                    else:
                        conditionStr = conditionStr + " --source %s " % i
                    current_strings = current_strings + [ current + conditionStr for current in orig_current_strings ]

            if conditionType == "DST_ADDR":
                if "any" in value:
                    continue # no need to do anything

                dsts = value.split(",")
                if invert and len(dsts) > 1:
                    print "ERROR: invert not supported on multiple addr condition"
                    continue
                if len(dsts) == 0:
                    print "ERROR: address condition with no interfaces"
                    continue

                orig_current_strings = current_strings
                current_strings = []
                for i in dsts:
                    conditionStr = ""
                    if invert:
                        conditionStr = conditionStr + " ! "
                    if "-" in i:
                        conditionStr = conditionStr + " -m iprange --dst-range %s " % i
                    else:
                        conditionStr = conditionStr + " --destination %s " % i
                    current_strings = current_strings + [ current + conditionStr for current in orig_current_strings ]

            if conditionType == "SRC_PORT":
                if "any" in value:
                    continue # no need to do anything

                value = value.replace("-",":").replace(" ","") # iptables uses colon to represent range not dash
                conditionStr = conditionStr + " -m multiport"
                if invert:
                    conditionStr = conditionStr + " ! "
                conditionStr = conditionStr + " --source-ports %s " % value
                if not hasProtocolCondition:
                    # port explicitly means either TCP or UDP, since no protocol condition has been specified, use "TCP,UDP" as the protocol condition
                    current_strings = [ " --protocol udp " + current for current in current_strings ] + [ " --protocol tcp " + current for current in current_strings ]
                current_strings = [ current + conditionStr for current in current_strings ]

            if conditionType == "DST_PORT":
                if "any" in value:
                    continue # no need to do anything

                value = value.replace("-",":").replace(" ","") # iptables uses colon to represent range not dash
                conditionStr = conditionStr + " -m multiport " 
                if invert:
                    conditionStr = conditionStr + " ! "
                conditionStr = conditionStr + " --destination-ports %s " % value
                if not hasProtocolCondition:
                    # port explicitly means either TCP or UDP, since no protocol condition has been specified, use "TCP,UDP" as the protocol condition
                    current_strings = [ " --protocol udp " + current for current in current_strings ] + [ " --protocol tcp " + current for current in current_strings ]
                current_strings = [ current + conditionStr for current in current_strings ]

            if conditionType == "DST_LOCAL":
                if invert:
                    conditionStr = conditionStr + " ! "
                conditionStr = conditionStr + " -m addrtype --dst-type local "
                current_strings = [ current + conditionStr for current in current_strings ]
                

        return current_strings;
        
