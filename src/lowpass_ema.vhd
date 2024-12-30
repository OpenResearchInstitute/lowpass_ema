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


------------------------------------------------------------------------------------------------------
-- ╔═╗┌┐┌┌┬┐┬┌┬┐┬ ┬
-- ║╣ │││ │ │ │ └┬┘
-- ╚═╝┘└┘ ┴ ┴ ┴  ┴ 
------------------------------------------------------------------------------------------------------
-- Entity

ENTITY lowpass_ema IS 
	GENERIC (
		ALPHA_W 		: NATURAL := 8;
		DATA_W 			: NATURAL := 16;
		AVG_W 			: NATURAL := 16
	);
	PORT (
		clk 				: IN  std_logic;
		init 				: IN  std_logic;

		alpha 				: IN  std_logic_vector(ALPHA_W -1 DOWNTO 0);

		data 				: IN  std_logic_vector(DATA_W -1 DOWNTO 0);
		data_ena 			: IN  std_logic;

		average 			: OUT std_logic_vector(DATA_W -1 DOWNTO 0);
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

	CONSTANT SHIFT_IN 		: NATURAL := AVG_W - DATA_W;

	CONSTANT alpha_max		: unsigned(ALPHA_W -1 DOWNTO 0) := to_unsigned(2**ALPHA_W -1, ALPHA_W);

	SIGNAL data_r 			: signed(AVG_W -1 DOWNTO 0);
	SIGNAL alpha_r			: unsigned(AVG_W -1 DOWNTO 0);
	SIGNAL alpha_m 			: unsigned(AVG_W -1 DOWNTO 0);
	SIGNAL ema				: signed(AVG_W -1 DOWNTO 0);

BEGIN 

-- truncate and round
average <= std_logic_vector(resize(shift_right(shift_right(ema, ALPHA_W-1)+1, 1), DATA_W));
average_ena <= '1';

data_r 	<= shift_left(resize(signed(data),AVG_W),SHIFT_IN);
alpha_r <= shift_left(resize(unsigned(alpha),AVG_W),SHIFT_IN);
alpha_m <= resize(alpha_max - unsigned(alpha), AVG_W);

proc : PROCESS (clk)
BEGIN
	IF clk'EVENT AND clk = '1' THEN
		IF init = '1' THEN 
			ema	<= (OTHERS => '0');
		ELSE

			-- ema[n] =  ( alpha*16*x[n]*16 + [1-alpha]*ema[n-1] ) / 256

			ema <= resize(shift_right(data_r * signed(alpha_r) + ema * signed(alpha_m), ALPHA_W), AVG_W);


		END IF;
	END IF;
END PROCESS proc;

END ARCHITECTURE rtl;



