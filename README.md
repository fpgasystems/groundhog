#groundhog

Groundhog implements a SATA host bus adapter. This Verilog-based project creates an easy-to-use interface between a user circuit on a Xilinx FPGA and a SATA hard drive or SSD.

This project includes binaries and example project files for the Digilent XUP-V5 board. This is a popular prototyping board that also includes two SATA headers. The project can easily be ported to any Virtex 5 that supports GTP tiles (any of the LXT, SXT, TXT or FXT series chips but not the LX devices). This allows us to connect the FPGA to SATA I/II drives.

Thanks to Lisa Liu from Xilinx, the latest release of Groundhog also includes a ported version of the HBA Verilog code to the Virtex 7-based platform VC709,  using the GTH tiles. The current version only supports SATA II but a SATA III compatible version is being developed.
