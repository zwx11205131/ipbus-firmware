----------------------------------------------------------------------------------
-- Module encapsulating Xilinx xdma core and interface to native dual BRAM
-- Raghunandan Shukla, TIFR
--

----------------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.ALL;

library unisim;
use unisim.VComponents.all;

use work.pcie_decl.all;
use work.ipbus_axi_decl.all;


entity pcie_xdma_axi_if is
  generic(
    C_M_AXI_ID_WIDTH: natural := 4;
    C_S_AXI_DATA_WIDTH : natural := C_AXI_DATA_WIDTH;
    C_M_AXI_DATA_WIDTH : natural := C_AXI_DATA_WIDTH;
    C_S_AXI_ADDR_WIDTH : natural := 64;
    C_M_AXI_ADDR_WIDTH : natural := 64;
    C_NUM_USR_IRQ : natural := 1
  );
  port (
    pci_sys_clk_p: in std_logic;
    pci_sys_clk_n: in std_logic;
    pci_exp_txp: out std_logic_vector (C_PCIE_LANES - 1 downto 0 );
    pci_exp_txn: out std_logic_vector (C_PCIE_LANES - 1 downto 0 );
    pci_exp_rxp: in std_logic_vector (C_PCIE_LANES - 1 downto 0 );
    pci_exp_rxn: in std_logic_vector (C_PCIE_LANES - 1 downto 0 );
    pci_sys_rst_n_c: in std_logic;

    axi_ms : out axi4mm_ms(araddr(12 downto 0), awaddr(12 downto 0), wdata(63 downto 0));
    axi_sm : in axi4mm_sm(rdata(63 downto 0));

    -- descriptor status
    h2c0_dsc_done: out std_logic;
    -- User interrupts
    pcie_int_event0: in std_logic
  );
end pcie_xdma_axi_if;

architecture rtl of pcie_xdma_axi_if is

  signal sys_clk, sys_clk_gt: std_logic;

  signal user_lnk_up: std_logic;

  signal usr_irq_req: std_logic_vector ( C_NUM_USR_IRQ - 1 downto 0 );  -- pass to the upper module
  signal usr_irq_ack: std_logic_vector ( C_NUM_USR_IRQ - 1 downto 0 );  -- pass to the upper module

  signal xdma_axi_araddr: std_logic_vector(C_M_AXI_DATA_WIDTH - 1 DOWNTO 0);
  signal xdma_axi_awaddr: std_logic_vector(C_M_AXI_DATA_WIDTH - 1 DOWNTO 0);

  signal msi_vector_width: std_logic_vector ( 2 downto 0 );
  signal msi_enable: std_logic;

  signal axi_ms_i: axi4mm_ms(araddr(12 downto 0), awaddr(12 downto 0), wdata(63 downto 0));

  signal cfg_ltssm_state: std_logic_vector ( 5 downto 0 ) ;

  signal h2c_sts_0: std_logic_vector ( 7 downto 0 ) ;

  -- components

  COMPONENT xdma_0
    PORT (
      sys_clk : IN STD_LOGIC;
      sys_clk_gt : IN STD_LOGIC;
      sys_rst_n : IN STD_LOGIC;
      user_lnk_up : OUT STD_LOGIC;
      pci_exp_txp : OUT STD_LOGIC_VECTOR(C_PCIE_LANES - 1 DOWNTO 0);
      pci_exp_txn : OUT STD_LOGIC_VECTOR(C_PCIE_LANES - 1 DOWNTO 0);
      pci_exp_rxp : IN STD_LOGIC_VECTOR(C_PCIE_LANES - 1 DOWNTO 0);
      pci_exp_rxn : IN STD_LOGIC_VECTOR(C_PCIE_LANES - 1 DOWNTO 0);
      axi_aclk : OUT STD_LOGIC;
      axi_aresetn : OUT STD_LOGIC;
      usr_irq_req : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      usr_irq_ack : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      msi_enable : OUT STD_LOGIC;
      msi_vector_width : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      m_axi_awready : IN STD_LOGIC;
      m_axi_wready : IN STD_LOGIC;
      m_axi_bid : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      m_axi_bvalid : IN STD_LOGIC;
      m_axi_arready : IN STD_LOGIC;
      m_axi_rid : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_rdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      m_axi_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      m_axi_rlast : IN STD_LOGIC;
      m_axi_rvalid : IN STD_LOGIC;
      m_axi_awid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_awaddr : OUT STD_LOGIC_VECTOR(C_M_AXI_DATA_WIDTH - 1 DOWNTO 0);
      m_axi_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      m_axi_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      m_axi_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      m_axi_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      m_axi_awvalid : OUT STD_LOGIC;
      m_axi_awlock : OUT STD_LOGIC;
      m_axi_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_wdata : OUT STD_LOGIC_VECTOR(C_M_AXI_DATA_WIDTH - 1 DOWNTO 0);
      m_axi_wstrb : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      m_axi_wlast : OUT STD_LOGIC;
      m_axi_wvalid : OUT STD_LOGIC;
      m_axi_bready : OUT STD_LOGIC;
      m_axi_arid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_araddr : OUT STD_LOGIC_VECTOR(C_M_AXI_DATA_WIDTH - 1 DOWNTO 0);
      m_axi_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      m_axi_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      m_axi_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      m_axi_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
      m_axi_arvalid : OUT STD_LOGIC;
      m_axi_arlock : OUT STD_LOGIC;
      m_axi_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      m_axi_rready : OUT STD_LOGIC;

      cfg_mgmt_addr : IN STD_LOGIC_VECTOR(18 DOWNTO 0);
      cfg_mgmt_write : IN STD_LOGIC;
      cfg_mgmt_write_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      cfg_mgmt_byte_enable : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      cfg_mgmt_read : IN STD_LOGIC;
      cfg_mgmt_read_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
      cfg_mgmt_read_write_done : OUT STD_LOGIC;
      cfg_mgmt_type1_cfg_reg_access : IN STD_LOGIC;
      c2h_sts_0 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      h2c_sts_0 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      int_qpll1lock_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      int_qpll1outrefclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      int_qpll1outclk_out : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
    );
  END COMPONENT;


begin

  h2c0_dsc_done <= h2c_sts_0( 3 );

  ibufds_gte3_sys_clk : IBUFDS_GTE3
    generic map (
      REFCLK_HROW_CK_SEL => "00"        -- clock divider 1 for ODiv2
      )
    port map (
      O     => sys_clk_gt,              -- 100 MHz output clock
      ODIV2 => sys_clk,                 -- also 100 mHz
      CEB   => '0',
      I     => pci_sys_clk_p,
      IB    => pci_sys_clk_n
      );

  xdma_0_i : xdma_0
    port map (
      sys_clk           => sys_clk,
      sys_clk_gt        => sys_clk_gt,
      sys_rst_n         => pci_sys_rst_n_c,
      user_lnk_up       => user_lnk_up,
      pci_exp_txp       => pci_exp_txp,
      pci_exp_txn       => pci_exp_txn,
      pci_exp_rxp       => pci_exp_rxp,
      pci_exp_rxn       => pci_exp_rxn,
      axi_aclk          => axi_ms_i.aclk,
      axi_aresetn       => axi_ms_i.aresetn,
      usr_irq_req       => usr_irq_req,
      usr_irq_ack       => usr_irq_ack,
      msi_enable        => msi_enable,
      msi_vector_width  => msi_vector_width,

      m_axi_awready     => axi_sm.awready,
      m_axi_wready      => axi_sm.wready,
      m_axi_bid         => axi_sm.bid,
      m_axi_bresp       => axi_sm.bresp,
      m_axi_bvalid      => axi_sm.bvalid,
      m_axi_arready     => axi_sm.arready,
      m_axi_rid         => axi_sm.rid,
      m_axi_rdata       => axi_sm.rdata,
      m_axi_rresp       => axi_sm.rresp,
      m_axi_rlast       => axi_sm.rlast,
      m_axi_rvalid      => axi_sm.rvalid,
      m_axi_awid        => axi_ms_i.awid,
      m_axi_awaddr      => xdma_axi_awaddr,
      m_axi_awlen       => axi_ms_i.awlen,
      m_axi_awsize      => axi_ms_i.awsize,
      m_axi_awburst     => axi_ms_i.awburst,
      m_axi_awprot      => axi_ms_i.awprot,
      m_axi_awvalid     => axi_ms_i.awvalid,
      m_axi_awlock      => axi_ms_i.awlock,
      m_axi_awcache     => axi_ms_i.awcache,
      m_axi_wdata       => axi_ms_i.wdata,
      m_axi_wstrb       => axi_ms_i.wstrb,
      m_axi_wlast       => axi_ms_i.wlast,
      m_axi_wvalid      => axi_ms_i.wvalid,
      m_axi_bready      => axi_ms_i.bready,
      m_axi_arid        => axi_ms_i.arid,
      m_axi_araddr      => xdma_axi_araddr,
      m_axi_arlen       => axi_ms_i.arlen,
      m_axi_arsize      => axi_ms_i.arsize,
      m_axi_arburst     => axi_ms_i.arburst,
      m_axi_arprot      => axi_ms_i.arprot,
      m_axi_arvalid     => axi_ms_i.arvalid,
      m_axi_arlock      => axi_ms_i.arlock,
      m_axi_arcache     => axi_ms_i.arcache,
      m_axi_rready      => axi_ms_i.rready,
      -- CFG
      cfg_mgmt_addr        => "000" & X"0000",
      cfg_mgmt_write       => '0',
      cfg_mgmt_write_data  => X"00000000",
      cfg_mgmt_byte_enable => X"0",
      cfg_mgmt_read        => '0',
      cfg_mgmt_read_data   => open,
      cfg_mgmt_type1_cfg_reg_access => '0',

      c2h_sts_0            => open,
      h2c_sts_0            => h2c_sts_0,

      int_qpll1lock_out      => open,
      int_qpll1outrefclk_out => open,
      int_qpll1outclk_out    => open
    );

  axi_ms_i.araddr <= xdma_axi_araddr(axi_ms.araddr'length - 1 downto 0);
  axi_ms_i.awaddr <= xdma_axi_awaddr(axi_ms.awaddr'length - 1 downto 0);
  axi_ms <= axi_ms_i;

  irq_gen: entity work.pcie_int_gen_msix
    port map (
      pcie_usr_clk     => axi_ms_i.aclk,
      pcie_sys_rst_n   => axi_ms_i.aresetn,
      pcie_usr_int_req => usr_irq_req(0),
      pcie_usr_int_ack => usr_irq_ack(0),
      pcie_event0      => pcie_int_event0
    );


end rtl;
