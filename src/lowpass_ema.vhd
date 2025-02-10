------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------
--  _______                             ________                                            ______
--  __  __ \________ _____ _______      ___  __ \_____ _____________ ______ ___________________  /_
--  _  / / /___  __ \_  _ \__  __ \     __  /_/ /_  _ \__  ___/_  _ \_  __ `/__  ___/_  ___/__  __ \
--  / /_/ / __  /_/ //  __/_  / / /     _  _, _/ /  __/_(__  ) /  __// /_/ / _  /    / /__  _  / / /
--  \____/  _  .___/ \___/ /_/ /_/      /_/ |_|  \___/ /____/  \___/ \__,_/  /_/     \___/  /_/ /_/
--          /_/
--                   ________                _____ _____ _____         _____
--                   ____  _/_______ __________  /____(_)__  /_____  ____  /______
--                    __  /  __  __ \__  ___/_  __/__  / _  __/_  / / /_  __/_  _ \
--                   __/ /   _  / / /_(__  ) / /_  _  /  / /_  / /_/ / / /_  /  __/
--                   /___/   /_/ /_/ /____/  \__/  /_/   \__/  \__,_/  \__/  \___/
--
------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------
-- Copyright
------------------------------------------------------------------------------------------------------
--
-- Copyright 2024 by M. Wishek <matthew@wishek.com>
--
------------------------------------------------------------------------------------------------------
-- License
------------------------------------------------------------------------------------------------------
--
-- This source describes Open Hardware and is licensed under the CERN-OHL-W v2.
--
-- You may redistribute and modify this source and make products using it under
-- the terms of the CERN-OHL-W v2 (https://ohwr.org/cern_ohl_w_v2.txt).
--
-- This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING
-- OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A PARTICULAR PURPOSE.
-- Please see the CERN-OHL-W v2 for applicable conditions.
--
-- Source location: TBD
--
-- As per CERN-OHL-W v2 section 4.1, should You produce hardware based on this
-- source, You must maintain the Source Location visible on the external case of
-- the products you make using this source.
--
------------------------------------------------------------------------------------------------------
-- Block name and description
------------------------------------------------------------------------------------------------------
--
-- This block implements an exponential moving average filter.
--
-- Documentation location: TBD
--
------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------
-- ╦  ┬┌┐ ┬─┐┌─┐┬─┐┬┌─┐┌─┐
-- ║  │├┴┐├┬┘├─┤├┬┘│├┤ └─┐
-- ╩═╝┴└─┘┴└─┴ ┴┴└─┴└─┘└─┘
------------------------------------------------------------------------------------------------------
-- Libraries

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;


------------------------------------------------------------------------------------------------------
-- ╔═╗┌┐┌┌┬┐┬┌┬┐┬ ┬
-- ║╣ │││ │ │ │ └┬┘
-- ╚═╝┘└┘ ┴ ┴ ┴  ┴ 
------------------------------------------------------------------------------------------------------
-- Entity

ENTITY lowpass_ema IS 
	GENERIC (
		ALPHA_W 		: NATURAL := 18;
		DATA_W 			: NATURAL := 23;
		MULT_A_W		: NATURAL := 25;
		MULT_B_W 		: NATURAL := 18;
		PROD_W			: NATURAL := 43 -- MULT_A_W + MULT_B_W
	);
	PORT (
		clk 				: IN  std_logic;
		init 				: IN  std_logic;

		alpha 				: IN  std_logic_vector(ALPHA_W -1 DOWNTO 0); -- u0.ALPHA_W

		data 				: IN  std_logic_vector(DATA_W -1 DOWNTO 0);  -- uDATA_W.0
		data_ena 			: IN  std_logic;

		average 			: OUT std_logic_vector(DATA_W -1 DOWNTO 0);  -- uDATA_W.0
		average_ena 		: OUT std_logic
	);
END ENTITY lowpass_ema;

------------------------------------------------------------------------------------------------------
-- ╔═╗┬─┐┌─┐┬ ┬┬┌┬┐┌─┐┌─┐┌┬┐┬ ┬┬─┐┌─┐
-- ╠═╣├┬┘│  ├─┤│ │ ├┤ │   │ │ │├┬┘├┤ 
-- ╩ ╩┴└─└─┘┴ ┴┴ ┴ └─┘└─┘ ┴ └─┘┴└─└─┘
------------------------------------------------------------------------------------------------------
-- Architecture

ARCHITECTURE rtl OF lowpass_ema IS 

	CONSTANT alpha_max		: signed(ALPHA_W -1 DOWNTO 0) := to_signed(2**(ALPHA_W-1) -1, ALPHA_W);

	SIGNAL data_signed		: signed(DATA_W -1 DOWNTO 0);

	SIGNAL alpha_signed		: signed(ALPHA_W -1 DOWNTO 0);
	SIGNAL alpha_m 			: signed(ALPHA_W -1 DOWNTO 0);

	CONSTANT SUM_SHIFT 		: NATURAL := PROD_W - MULT_A_W;
	SIGNAL sum				: signed(PROD_W -1 DOWNTO 0);
	SIGNAL sum_r			: signed(PROD_W - SUM_SHIFT -1 DOWNTO 0);

	CONSTANT MULT_DATA_SHIFT: NATURAL := PROD_W - ALPHA_W - DATA_W + 1;
	SIGNAL mult_data 		: signed(PROD_W -1 DOWNTO 0);

	CONSTANT MULT_SUM_SHIFT	: NATURAL := SUM_SHIFT - (ALPHA_W -1);
	SIGNAL mult_sum 		: signed(PROD_W -1 DOWNTO 0);

	CONSTANT AVG_SHIFT 		: NATURAL := PROD_W - DATA_W;

	-- Debug stuff

	CONSTANT FULL_SCALE 	: REAL := real(2**((DATA_W+1)/2-1)-1);

	SIGNAL avg_rms 			: REAL := 0.0;
	SIGNAL avg_real 		: REAL := 0.0;


BEGIN 

-- pragma translate_off
ASSERT False REPORT "PROD_W: " & integer'image(PROD_W) SEVERITY NOTE;
ASSERT False REPORT "SUM_SHIFT: " & integer'image(SUM_SHIFT) SEVERITY NOTE;
ASSERT False REPORT "MULT_DATA_SHIFT: " & integer'image(MULT_DATA_SHIFT) SEVERITY NOTE;
ASSERT False REPORT "MULT_SUM_SHIFT: " & integer'image(MULT_SUM_SHIFT) SEVERITY NOTE;
ASSERT False REPORT "AVG_SHIFT: " & integer'image(AVG_SHIFT) SEVERITY NOTE;
ASSERT False REPORT "FULL_SCALE: " & real'image(FULL_SCALE) SEVERITY NOTE;
--ASSERT False REPORT "AVG_REAL: " & real'image(avg_real) SEVERITY NOTE;

--avg_real <= SQRT(real(integer(to_integer(shift_right(sum, AVG_SHIFT)))));
--avg_rms <= 20.0*LOG10(avg_real/FULL_SCALE) WHEN avg_real > 0.0 ELSE 0.0;
-- pragma translate_on

average 	<= std_logic_vector(resize(shift_right(sum, AVG_SHIFT), DATA_W));

alpha_signed <= signed(alpha);
alpha_m 	 <= alpha_max - alpha_signed;

data_signed <= signed(data);

sum_r 		<= resize(shift_right(sum, SUM_SHIFT), PROD_W - SUM_SHIFT);

mult_data 	<= shift_left(resize(data_signed * alpha_signed, PROD_W), MULT_DATA_SHIFT);
mult_sum 	<= shift_left(resize(sum_r * alpha_m, PROD_W), MULT_SUM_SHIFT);

proc : PROCESS (clk)
BEGIN
	IF clk'EVENT AND clk = '1' THEN
		IF init = '1' THEN 
			sum	<= (OTHERS => '0');
			average_ena <= '0';
		ELSE

			-- ema[n] =  ( alpha*16*x[n]*16 + [1-alpha]*ema[n-1] ) / 256

			sum <= mult_data + mult_sum;
			average_ena <= data_ena;

		END IF;
	END IF;
END PROCESS proc;

END ARCHITECTURE rtl;



