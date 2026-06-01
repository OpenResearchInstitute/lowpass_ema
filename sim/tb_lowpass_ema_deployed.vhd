library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.ENV.ALL;

-- Reproduces the silicon power-detector EMA exactly as instantiated:
-- power_detector DATA_W=16  =>  EMA DATA_W=31, MULT_A_W=33, PROD_W=51, ALPHA_W=18.
-- Feeds a STEADY positive squared-power value (like a real dsum ~4.5M),
-- alpha1=4096, and reports the converged average.
--   Correct EMA  -> average climbs to ~4,400,000.
--   Broken EMA   -> average rails (all-ones / -1) or sits at 0, like the hardware.
entity tb_lowpass_ema_deployed is
end entity;

architecture sim of tb_lowpass_ema_deployed is
  constant ALPHA_W  : natural := 18;
  constant DATA_W   : natural := 31;   -- 2*16 - 1
  constant MULT_A_W : natural := 33;   -- (2*16 - 1) + 2
  constant MULT_B_W : natural := 18;
  constant PROD_W   : natural := 51;   -- MULT_A_W + MULT_B_W

  signal clk         : std_logic := '0';
  signal init        : std_logic := '1';
  signal alpha       : std_logic_vector(ALPHA_W-1 downto 0) :=
                         std_logic_vector(to_unsigned(4096, ALPHA_W));
  signal data        : std_logic_vector(DATA_W-1 downto 0)  :=
                         std_logic_vector(to_unsigned(4500000, DATA_W)); -- clean +, bit30 clear
  signal data_ena    : std_logic := '1';
  signal average     : std_logic_vector(DATA_W-1 downto 0);
  signal average_ena : std_logic;
  signal n           : integer := 0;
begin
  uut : entity work.lowpass_ema(rtl)
    generic map (
      ALPHA_W => ALPHA_W, DATA_W => DATA_W,
      MULT_A_W => MULT_A_W, MULT_B_W => MULT_B_W, PROD_W => PROD_W
    )
    port map (
      clk => clk, init => init, alpha => alpha,
      data => data, data_ena => data_ena,
      average => average, average_ena => average_ena
    );

  clk <= not clk after 5 ns;

  process(clk)
  begin
    if rising_edge(clk) then
      n <= n + 1;
      if n = 3 then init <= '0'; end if;          -- release reset after a few cycles
      if (n mod 4000 = 0) and n > 0 then
        report "n=" & integer'image(n) &
               "  average=" & integer'image(to_integer(signed(average)));
      end if;
      if n = 60000 then
        report "FINAL average=" & integer'image(to_integer(signed(average))) &
               "   (expect ~4,400,000 if the EMA works; 0 or negative if it rails)";
        stop;
      end if;
    end if;
  end process;
end architecture;
