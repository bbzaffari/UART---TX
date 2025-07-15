--------------------------------------------------------------------------------------------    
--  Name: Bruno Bavaresco Zaffari
--  Uart_tx
--------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity uart_tx is
    port(
        clock_in            : in std_logic;
        reset_in            : in std_logic;
        data_p_in           : in std_logic_vector(7 downto 0);
        data_p_en_in        : in std_logic;
        uart_rate_tx_sel    : in std_logic_vector(1 downto 0);
        uart_data_tx        : out std_logic
    );
end uart_tx;

architecture rtl of uart_tx is
	type states is (IDLE, START, RECEIVE, STOP, DONE);
	type data_t is (U_HAVE, U_DONT_HAVE, U_GOT_ERROR);
	type what is (SEND, NAN);
    signal state : states := IDLE;
	signal do_i_have_data : data_t;
	signal to_do : what;
    ------------------------------------------------------------------------
	signal baud_divisor, baud_divisor_temp : integer range 0 to 1041 := 0;
    signal tick                      : std_logic:= '0';
	------------------------------------------------------------------------
	signal sts_full_sig              : std_logic := '0';
	signal sts_empty_sig             : std_logic := '0';
	signal sts_high_sig              : std_logic := '0';
	signal sts_low_sig               : std_logic := '0';
	signal sts_error_sig             : std_logic := '0';
	signal counter       : integer range 0 to 1041 := 0;
	------------------------------------------------------------------------
	signal rd_data_sig : std_logic_vector(0 to 7);
	signal rd_en_sig : std_logic;
	------------------------------------------------------------------------
	signal data_reg   : std_logic_vector(0 to 7) := (others => '0');
	signal data_temp  : std_logic_vector(0 to 7) := (others => '0');
    signal bit_index  : integer range 0 to 7 := 0;
	signal delay, flag_delay : std_logic := '0';
	signal has_temp   : std_logic := '0';
	
	--signal data : std_logic_vector(7 downto 0);
	signal data : std_logic_vector(0 to 7);
	
	-- novo sinal
	signal fifo_ready : integer range 0 to 5 := 0;	
	constant MAX_DELAY_FIFO : integer := 5; --é sintetizavel	


begin
	--------------------------------------------------------------------------------------------
	----------------------------- Instância do gerador de baud rate-----------------------------
	--------------------------------------------------------------------------------------------
    baud_divisor_temp <= 1040 when uart_rate_tx_sel = "00"else -- (int)10416/(int)10(ns) = 1041
						 520 when uart_rate_tx_sel = "01" else -- (int)5208/(int)10(ns) = 520
						 346 when uart_rate_tx_sel = "10" else -- (int)3472/(int)10(ns) = 347
						 172 when uart_rate_tx_sel = "11" else -- (int)1736/(int)10(ns) = 173
						 1040;-- (int)10416/(int)10(ns) = 1041 + 1 = 1042
	
	p_baud_divisor_update: process(clock_in)
    begin
        if rising_edge(clock_in) then
            if reset_in = '1' then
                baud_divisor <= baud_divisor_temp;
            elsif state = IDLE or state = DONE then
                baud_divisor <= baud_divisor_temp;
            end if;
        end if;
    end process;
	
	------------------------------------------------------------------------
    -- Geração do pulso de tick para cada bit de transmissão
    ------------------------------------------------------------------------
    p_tick_generator: process(clock_in)
    begin
        if rising_edge(clock_in) then
            if reset_in = '1' then
                tick    <= '0';
                counter <= 0;
            elsif state = START or state = RECEIVE or state = STOP then
                if counter = baud_divisor then
                    tick    <= '1';
                    counter <= 0;
                else
                    tick    <= '0';
                    counter <= counter + 1;
                end if;
            else
                tick    <= '0';
                counter <= 0;
            end if;
        end if;
    end process;
					
    --------------------------------------------------------------------------------------------
	----------------------------- fifo instance to hold messages -------------------------------
	--------------------------------------------------------------------------------------------

	fifo: entity work.FIFO_SYNC port map(
        clk => clock_in,
        rst => reset_in,
        wr_en => data_p_en_in,
        wr_data => data_p_in,
        rd_en => rd_en_sig,
        rd_data => rd_data_sig,
        sts_full => sts_full_sig,
        sts_empty => sts_empty_sig,
        sts_high => sts_high_sig,
        sts_low => sts_low_sig,
        sts_error => sts_error_sig
    );
	
	p_data_availability_check:process(clock_in)
	begin
	if rising_edge(clock_in) then
		if(reset_in = '1') then
			do_i_have_data <= U_DONT_HAVE;
		elsif sts_empty_sig  = '1' then
			do_i_have_data <= U_DONT_HAVE;
		elsif sts_error_sig = '1' then 
			do_i_have_data <= U_GOT_ERROR;
		else 
			do_i_have_data <= U_HAVE;
		end if;
	end if;
	end process;
	
	p_fifo_read_control:process(clock_in)
	begin
		if rising_edge(clock_in) then
			if(reset_in = '1') then
				rd_en_sig <= '0';
				data  <= (others => '0');
				flagsend <= '0';
				to_do <= NAN;
				fifo_ready <= 0;
			elsif state = IDLE and flagsend = '0' then
				if do_i_have_data = U_HAVE then
					if fifo_ready = 0 then
						rd_en_sig <= '1';
						fifo_ready <= fifo_ready + 1;
					elsif fifo_ready < MAX_DELAY_FIFO then
						fifo_ready <= fifo_ready + 1;
						if fifo_ready = 1 then	
							data <= rd_data_sig;
							rd_en_sig <= '0';
						end if;
					else
						fifo_ready <= 0;
						to_do <= SEND;
						flagsend <= '1';
					end if;
				elsif do_i_have_data = U_DONT_HAVE then
					rd_en_sig <= '0';
					to_do <= NAN;
				elsif do_i_have_data = U_GOT_ERROR then
					rd_en_sig <= '0';
					to_do <= ERROR;
				end if;
			elsif state = DONE then
				flagsend <= '0';
			else 
				rd_en_sig <= '0';
			end if;	
		end if;			
	end process;

	
     ------------------------------------------------------------------------
    -- Máquina de estados de transmissão UART
    ------------------------------------------------------------------------
    p_uart_tx_fsm: process(clock_in)
    begin
        if rising_edge(clock_in) then
            if reset_in = '1' then
                state         <= IDLE;
                bit_index     <= 0;
                uart_data_tx  <= '1';  -- linha ociosa = '1'
            else
                case to_do is
                    when SEND =>
                        case state is
                            when IDLE =>
                                state <= START;

                            when START =>
                                if tick = '1' then
                                    uart_data_tx <= '0';  -- start bit
                                    state         <= RECEIVE;
                                end if;

                            when RECEIVE =>
                                if tick = '1' then
                                    uart_data_tx <= data_reg(bit_index);
                                    if bit_index = 7 then
                                        state <= STOP;
                                    else
                                        bit_index <= bit_index + 1;
                                    end if;
                                end if;

                            when STOP =>
                                if tick = '1' then
                                    state <= DONE;
									report "TX has successfully send ->" & integer'image(to_integer(unsigned(data_reg)));
                                end if;

                            when DONE =>
                                -- emite stop bit e finaliza
                                uart_data_tx <= '1';
                                bit_index    <= 0;
                                state        <= IDLE;

                        end case;

                    when others =>
                        -- sem dados para enviar, mantém linha em '1'
                        uart_data_tx <= '1';
                        state        <= IDLE;
                        bit_index    <= 0;
                end case;
            end if;
        end if;
    end process;

end rtl;
