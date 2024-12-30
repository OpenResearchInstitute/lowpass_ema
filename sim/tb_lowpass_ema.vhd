library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity EMA_Testbench is
end EMA_Testbench;

architecture Behavioral of EMA_Testbench is

    -- Constant
    constant ALPHA_W : natural := 8;

    -- Signals
    signal clk     : std_logic := '0';
    signal reset   : std_logic := '1';
    signal x_in    : signed(15 downto 0);
    signal ema_slv : std_logic_vector(15 DOWNTO 0);
    signal ema_out : signed(15 downto 0);
    signal ema_ena : std_logic;

    -- Test Data
    type input_array is array (0 to 7) of signed(15 downto 0);
    constant test_inputs : input_array := (
        to_signed(10, 16),
        to_signed(20, 16),
        to_signed(15, 16),
        to_signed(25, 16),
        to_signed(5, 16),
        to_signed(-10, 16),
        to_signed(0, 16),
        to_signed(30, 16)
    );

    signal index : integer := 0;

begin
    -- Instantiate the EMA Filter
    uut : ENTITY work.lowpass_ema(rtl)
        generic map (
            DATA_W  => 16,
            ALPHA_W => ALPHA_W,
            AVG_W   => 20
        )
        port map (
            clk     => clk,
            init    => reset,
            alpha   => std_logic_vector(to_unsigned(240, ALPHA_W)),
            data    => std_logic_vector(x_in),
            data_ena => '1',
            average => ema_slv,
            average_ena => ema_ena
        );

    ema_out <= signed(ema_slv);

    -- Clock Generation
    clk_process : process
    begin
        clk <= '0'; wait for 10 ns;
        clk <= '1'; wait for 10 ns;
    end process;

    -- Stimulus Process
    stimulus_process : process
    begin
        -- Reset the system
        reset <= '1';
        wait for 20 ns;
        reset <= '0';

        -- Apply test inputs
        for i in 0 to 7 loop
            x_in <= test_inputs(i);
            wait for 20 ns; -- Wait for one clock cycle
        end loop;

        -- End simulation
        wait;
    end process;
end Behavioral;