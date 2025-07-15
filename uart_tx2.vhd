--------------------------------------------------------------------------------------------
--  Name: Bruno Bavaresco Zaffari
--  Uart_tx sem FIFO
--------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
    port(
        clock_in            : in  std_logic;
        reset_in            : in  std_logic;
        data_p_in           : in  std_logic_vector(7 downto 0);
        data_p_en_in        : in  std_logic;
        uart_rate_tx_sel    : in  std_logic_vector(1 downto 0);
        uart_data_tx        : out std_logic
    );
end uart_tx;

architecture rtl of uart_tx is
    -- FSM states
    type states is (IDLE, START, RECEIVE, STOP, DONE);
    signal state      : states := IDLE;
    -- Control signal: indica quando há um byte pronto pra enviar
    type what_t is (NAN, SEND);
    signal to_do: what_t := NAN;
    -- Registrador de dados e índice de bit
    signal data_reg   : std_logic_vector(0 to 7) := (others => '0');
	signal data_temp  : std_logic_vector(0 to 7) := (others => '0');
    signal bit_index  : integer range 0 to 7 := 0;
	signal delay, flag_delay : std_logic := '0';
	signal has_temp   : std_logic := '0';
	
    -- Baud-rate generator
    signal baud_divisor, baud_divisor_temp : integer range 0 to 1041 := 0;
    signal counter    : integer range 0 to 1041 := 0;
	signal tick       : std_logic := '0';

begin

    ------------------------------------------------------------------------
    -- Atualização do divisor de baud conforme seleção
    ------------------------------------------------------------------------
    baud_divisor_temp <= 1040 when uart_rate_tx_sel = "00" else
                         520  when uart_rate_tx_sel = "01" else
                         346  when uart_rate_tx_sel = "10" else
                         172  when uart_rate_tx_sel = "11" else
                         1040;  -- default

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

    -------------------------------------------------------------------------------------------
    -- Captura direta do byte a ser enviado ( com possibilidade de capturar um bit de espera)
    -------------------------------------------------------------------------------------------
    p_load_data: process(clock_in)
    begin
        if rising_edge(clock_in) then
            if reset_in = '1' then
				data_temp  <= (others => '0');
				data_reg   <= (others => '0');
				flag_delay <= '0';
				has_temp   <= '0';
                to_do      <= NAN;
				delay      <= '0';
				
            else
                if data_p_en_in = '1' then
					report "TX has received <--------" & integer'image(to_integer(unsigned(data_p_in)));
					
					if state = IDLE or state = DONE then
					-- carrega dado e sinaliza envio
						data_reg <= data_p_in;
						to_do    <= SEND;
						flag_delay <='1';
					else 
					-- guarda dado e levanta flag
						data_temp <= data_p_in;
						has_temp <= '1';
					end if;
				elsif state = IDLE and flag_delay /='1' and has_temp /= '1' then
					to_do    <= NAN;
				end if;
				
				if flag_delay ='1' then 
					flag_delay <='0';
					delay <= '1';
				end if;
				
				if delay = '1' then 
					delay <= '0';
				end if;
				
				if has_temp = '1' and (state = DONE or state = IDLE) and delay = '0' then
					data_reg <= data_temp;
					to_do    <= SEND;
					has_temp <= '0';
				end if;
				
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
