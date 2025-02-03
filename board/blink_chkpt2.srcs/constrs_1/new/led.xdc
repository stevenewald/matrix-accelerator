
###############################################################################
# Pinout and Related I/O Constraints
###############################################################################

#
# SYS reset (input) signal.  The sys_reset_n signal should be
# obtained from the PCI Express interface if possible.  For
# slot based form factors, a system reset signal is usually
# present on the connector.  For cable based form factors, a
# system reset signal may not be available.  In this case, the
# system reset signal must be generated locally by some form of
# supervisory circuit.  You may change the IOSTANDARD and LOC
# to suit your requirements and VCCO voltage banking rules.
# Some 7 series devices do not have 3.3 V I/Os available.
# Therefore the appropriate level shift is required to operate
# with these devices that contain only 1.8 V banks.
#

set_property IOSTANDARD LVCMOS33 [get_ports group_led[0]]
set_property PACKAGE_PIN K22 [get_ports group_led[0]]

set_property IOSTANDARD LVCMOS33 [get_ports group_led[1]]
set_property PACKAGE_PIN J22 [get_ports group_led[1]]

set_property IOSTANDARD LVCMOS33 [get_ports corner_led]
set_property PACKAGE_PIN AB6 [get_ports corner_led]

set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]
set_property PULLUP true [get_ports sys_rst_n]
set_property PACKAGE_PIN N15 [get_ports sys_rst_n]

set_property LOC GTPE2_CHANNEL_X0Y0 [get_cells {des/design_1_i/axi_pcie_0/inst/comp_axi_enhanced_pcie/comp_enhanced_core_top_wrap/axi_pcie_enhanced_core_top_i/pcie_7x_v2_0_2_inst/pcie_top_with_gt_top.gt_ges.gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtp_channel.gtpe2_channel_i}]
set_property PACKAGE_PIN A8 [get_ports {pci_exp_rxn[0]}]
set_property PACKAGE_PIN A4 [get_ports {pci_exp_txn[0]}]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN pullup [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 2 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]

###############################################################################
# Physical Constraints
###############################################################################
#
# SYS clock 100 MHz (input) signal. The sys_clk_p and sys_clk_n
# signals are the PCI Express reference clock. Virtex-7 GT
# Transceiver architecture requires the use of a dedicated clock
# resources (FPGA input pins) associated with each GT Transceiver.
# To use these pins an IBUFDS primitive (refclk_ibuf) is
# instantiated in user's design.
# Please refer to the Virtex-7 GT Transceiver User Guide
# (UG) for guidelines regarding clock resource selection.
#


###############################################################################
# Timing Constraints
###############################################################################
#
create_clock -period 10.000 -name sys_clk [get_ports sys_clk_p]
#
#
#
#

#
#
# Timing ignoring the below pins to avoid CDC analysis, but care has been taken in RTL to sync properly to other clock domain.
#
#
##############################################################################
# Tandem Configuration Constraints
###############################################################################


set_property PACKAGE_PIN F6 [get_ports sys_clk_p]
