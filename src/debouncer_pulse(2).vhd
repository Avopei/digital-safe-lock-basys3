library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity debouncer_pulse is
   Port (
       clk       : in  std_logic;
       btn       : in  std_logic;
       btn_level : out std_logic;
       btn_pulse : out std_logic
   );
end debouncer_pulse;

architecture Behavioral of debouncer_pulse is

   constant CLK_FREQ      : natural := 100_000_000;
   constant DEBOUNCE_TIME : natural := 5; -- ms
   constant DELAY         : natural := (CLK_FREQ / 1000) * DEBOUNCE_TIME;

   signal count        : natural range 0 to DELAY := 0;

   signal btn_meta     : std_logic := '0';
   signal btn_sync     : std_logic := '0';

   signal btn_sampled  : std_logic := '0';  -- last synchronized sample being checked
   signal btn_state    : std_logic := '0';  -- debounced stable state

   signal btn_prev     : std_logic := '0';
   signal pulse_int    : std_logic := '0';

begin

   process(clk)
   begin
       if rising_edge(clk) then

           -- 2FF synchronizer
           btn_meta <= btn;
           btn_sync <= btn_meta;

           -- debounce
           if btn_sync /= btn_sampled then
               btn_sampled <= btn_sync;
               count       <= 0;
           elsif count < DELAY then
               count <= count + 1;
           else
               btn_state <= btn_sampled;
           end if;

           -- rising-edge pulse from debounced signal
           pulse_int <= btn_state and not btn_prev;
           btn_prev  <= btn_state;

       end if;
   end process;

   btn_level <= btn_state;
   btn_pulse <= pulse_int;

end Behavioral;