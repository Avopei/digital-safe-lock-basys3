
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity safe_lock is
    Port ( rst  : in  STD_LOGIC;
           clk  : in  STD_LOGIC;

           btnL : in  STD_LOGIC;
           btnU : in  STD_LOGIC;
           btnR : in  STD_LOGIC;
           btnD : in  STD_LOGIC;

           led  : out STD_LOGIC_VECTOR (15 downto 0);

           seg  : out STD_LOGIC_VECTOR (0 to 6);
           dp   : out STD_LOGIC;
           an   : out STD_LOGIC_VECTOR (3 downto 0));
end safe_lock;

architecture Behavioral of safe_lock is

    --------------------------------------------------------------------
    -- COMPONENTE
    --------------------------------------------------------------------

    component debouncer_pulse is
        Port ( clk       : in  STD_LOGIC;
               btn       : in  STD_LOGIC;
               btn_level : out STD_LOGIC;
               btn_pulse : out STD_LOGIC);
    end component;

    component driver7seg is
        Port ( clk    : in  STD_LOGIC;
               Din    : in  STD_LOGIC_VECTOR (15 downto 0);
               an     : out STD_LOGIC_VECTOR (3 downto 0);
               seg    : out STD_LOGIC_VECTOR (0 to 6);
               dp_in  : in  STD_LOGIC_VECTOR (3 downto 0);
               dp_out : out STD_LOGIC;
               rst    : in  STD_LOGIC);
    end component;

    --------------------------------------------------------------------
    -- CONSTANTE
    --------------------------------------------------------------------

    -- Codul corect este: U, R, D, L
    -- L = 0, U = 1, R = 2, D = 3
    constant CODE0 : integer range 0 to 3 := 1; -- btnU
    constant CODE1 : integer range 0 to 3 := 2; -- btnR
    constant CODE2 : integer range 0 to 3 := 3; -- btnD
    constant CODE3 : integer range 0 to 3 := 0; -- btnL

    constant LOCK_TIME : integer := 10; -- 10 secunde

    --------------------------------------------------------------------
    -- STARI FSM
    --------------------------------------------------------------------

    type states is (IDLE, DIGIT2, DIGIT3, DIGIT4, WRONG, LOCKED, OPENED);
    signal current_state : states := IDLE;

    --------------------------------------------------------------------
    -- SEMNALE BUTOANE
    --------------------------------------------------------------------

    signal btnL_pulse : STD_LOGIC;
    signal btnU_pulse : STD_LOGIC;
    signal btnR_pulse : STD_LOGIC;
    signal btnD_pulse : STD_LOGIC;

    signal key_pressed : STD_LOGIC := '0';
    signal key_value   : integer range 0 to 3 := 0;

    --------------------------------------------------------------------
    -- SEMNALE INTERNE
    --------------------------------------------------------------------

    signal ok_so_far    : STD_LOGIC := '1';
    signal attempts     : integer range 0 to 3 := 0;
    signal lock_seconds : integer range 0 to LOCK_TIME := LOCK_TIME;

    signal ce_1s    : STD_LOGIC := '0';
    signal ce_blink : STD_LOGIC := '0';

    signal blink_led : STD_LOGIC := '0';

    signal display_value : STD_LOGIC_VECTOR(15 downto 0) := x"0000";
    signal led_value     : STD_LOGIC_VECTOR(15 downto 0) := x"0000";

begin

    --------------------------------------------------------------------
    -- DEBOUNCERE PENTRU BUTOANE
    --------------------------------------------------------------------

    deb_L : debouncer_pulse port map (
        clk       => clk,
        btn       => btnL,
        btn_level => open,
        btn_pulse => btnL_pulse
    );

    deb_U : debouncer_pulse port map (
        clk       => clk,
        btn       => btnU,
        btn_level => open,
        btn_pulse => btnU_pulse
    );

    deb_R : debouncer_pulse port map (
        clk       => clk,
        btn       => btnR,
        btn_level => open,
        btn_pulse => btnR_pulse
    );

    deb_D : debouncer_pulse port map (
        clk       => clk,
        btn       => btnD,
        btn_level => open,
        btn_pulse => btnD_pulse
    );

    --------------------------------------------------------------------
    -- DETECTARE BUTON APASAT
    --------------------------------------------------------------------

    key_detect : process(btnL_pulse, btnU_pulse, btnR_pulse, btnD_pulse)
    begin
        key_pressed <= '0';
        key_value   <= 0;

        if btnL_pulse = '1' then
            key_pressed <= '1';
            key_value   <= 0;

        elsif btnU_pulse = '1' then
            key_pressed <= '1';
            key_value   <= 1;

        elsif btnR_pulse = '1' then
            key_pressed <= '1';
            key_value   <= 2;

        elsif btnD_pulse = '1' then
            key_pressed <= '1';
            key_value   <= 3;
        end if;
    end process;

    --------------------------------------------------------------------
    -- CLOCK ENABLE 1 SECUNDA
    -- Folosit pentru countdown-ul de LOCKED si durata starii WRONG
    --------------------------------------------------------------------

    divider_1s : process(rst, clk)
        constant N_1S : integer := 100_000_000; -- 100 MHz => 1 secunda
        variable q : integer range 0 to N_1S - 1 := 0;
    begin
        if rst = '1' then
            q := 0;
            ce_1s <= '0';

        elsif rising_edge(clk) then
            if q = N_1S - 1 then
                q := 0;
                ce_1s <= '1';
            else
                q := q + 1;
                ce_1s <= '0';
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- CLOCK ENABLE PENTRU BLINK LED
    -- LED-urile clipesc de 5 ori pe secunda in starea WRONG
    --------------------------------------------------------------------

    divider_blink : process(rst, clk)
        constant N_BLINK : integer := 10_000_000; -- 0.1 secunde la 100 MHz
        variable q : integer range 0 to N_BLINK - 1 := 0;
    begin
        if rst = '1' then
            q := 0;
            ce_blink <= '0';

        elsif rising_edge(clk) then
            if q = N_BLINK - 1 then
                q := 0;
                ce_blink <= '1';
            else
                q := q + 1;
                ce_blink <= '0';
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- SEMNAL BLINK
    --------------------------------------------------------------------

    blink_process : process(rst, clk)
    begin
        if rst = '1' then
            blink_led <= '0';

        elsif rising_edge(clk) then
            if current_state = WRONG then
                if ce_blink = '1' then
                    blink_led <= not blink_led;
                end if;
            else
                blink_led <= '0';
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- FSM PRINCIPAL
    --------------------------------------------------------------------

    fsm : process(rst, clk)
    begin
        if rst = '1' then
            current_state <= IDLE;
            ok_so_far    <= '1';
            attempts     <= 0;
            lock_seconds <= LOCK_TIME;

        elsif rising_edge(clk) then

            case current_state is

                when IDLE =>
                    ok_so_far    <= '1';
                    lock_seconds <= LOCK_TIME;

                    if key_pressed = '1' then
                        if key_value = CODE0 then
                            ok_so_far <= '1';
                        else
                            ok_so_far <= '0';
                        end if;

                        current_state <= DIGIT2;
                    end if;

                when DIGIT2 =>
                    if key_pressed = '1' then
                        if key_value = CODE1 and ok_so_far = '1' then
                            ok_so_far <= '1';
                        else
                            ok_so_far <= '0';
                        end if;

                        current_state <= DIGIT3;
                    end if;

                when DIGIT3 =>
                    if key_pressed = '1' then
                        if key_value = CODE2 and ok_so_far = '1' then
                            ok_so_far <= '1';
                        else
                            ok_so_far <= '0';
                        end if;

                        current_state <= DIGIT4;
                    end if;

                when DIGIT4 =>
                    if key_pressed = '1' then

                        if key_value = CODE3 and ok_so_far = '1' then
                            current_state <= OPENED;
                            attempts      <= 0;

                        else
                            if attempts = 2 then
                                current_state <= LOCKED;
                                attempts      <= 0;
                                lock_seconds  <= LOCK_TIME;
                            else
                                attempts      <= attempts + 1;
                                current_state <= WRONG;
                            end if;
                        end if;

                        ok_so_far <= '1';
                    end if;

                when WRONG =>
                    if ce_1s = '1' then
                        current_state <= IDLE;
                    end if;

                when LOCKED =>
                    if ce_1s = '1' then
                        if lock_seconds <= 1 then
                            current_state <= IDLE;
                            lock_seconds  <= LOCK_TIME;
                        else
                            lock_seconds <= lock_seconds - 1;
                        end if;
                    end if;

                when OPENED =>
                    current_state <= OPENED;

                when others =>
                    current_state <= IDLE;

            end case;
        end if;
    end process;

    --------------------------------------------------------------------
    -- CONTROL LED-URI
    --------------------------------------------------------------------

    led_control : process(current_state, blink_led)
    begin
        case current_state is

            when IDLE =>
                led_value <= x"0001";

            when DIGIT2 =>
                led_value <= x"0003";

            when DIGIT3 =>
                led_value <= x"0007";

            when DIGIT4 =>
                led_value <= x"000F";

            when WRONG =>
                if blink_led = '1' then
                    led_value <= x"FFFF";
                else
                    led_value <= x"0000";
                end if;

            when LOCKED =>
                led_value <= x"F000";

            when OPENED =>
                led_value <= x"00FF";

            when others =>
                led_value <= x"0000";

        end case;
    end process;

    led <= led_value;

    --------------------------------------------------------------------
    -- CONTROL AFISAJ 7 SEGMENTE
    --------------------------------------------------------------------

    display_control : process(current_state, lock_seconds,attempts)
        variable tens  : integer range 0 to 9;
        variable unit_digit : integer range 0 to 9;
        variable remaining : integer range 0 to 3;
    begin
        display_value <= x"0000";
        remaining := 3-attempts;
        
        case current_state is

            when IDLE =>
               --Afiseaza cate incercari mai are utilizatorul:
               -- 0003 = 3 incercari ramase
               -- 0002 = 2 incercari ramase
               -- 0001 = 1 incercari ramase
                display_value <= x"000" &
                       std_logic_vector(to_unsigned(remaining, 4));
                       
            when DIGIT2 =>
                display_value <= x"0001";

            when DIGIT3 =>
                display_value <= x"0002";

            when DIGIT4 =>
                display_value <= x"0003";

            when WRONG =>
                display_value <= x"000F"; -- F = failed / cod gresit

            when LOCKED =>
            --Dupa a3 a greseala intra i
                tens  := lock_seconds / 10;
                unit_digit := lock_seconds mod 10;

                display_value <= x"00" &
                                 std_logic_vector(to_unsigned(tens, 4)) &
                                 std_logic_vector(to_unsigned(unit_digit, 4));

            when OPENED =>
                display_value <= x"1111"; -- safe deschis

            when others =>
                display_value <= x"0000";

        end case;
    end process;

    --------------------------------------------------------------------
    -- DRIVER 7 SEGMENTE
    --------------------------------------------------------------------

    ssd : driver7seg port map (
        clk    => clk,
        rst    => rst,
        Din    => display_value,
        dp_in  => "0000",
        an     => an,
        seg    => seg,
        dp_out => dp
    );

end Behavioral;
