library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity uart_tx_tb2 is
-- banco de ensaio não tem portas externas
end uart_tx_tb2;

architecture tb of uart_tx_tb2 is


    signal clk            : std_logic := '0';
    signal rst            : std_logic := '1';
    signal uart_rate_sel  : std_logic_vector(1 downto 0) := "00";  -- menor divisor: ~1040 ciclos
    signal uart_line      : std_logic := '1';  -- idle = '1'
    signal data_p_in      : std_logic_vector(7 downto 0) := (others => '0');
    signal data_p_en_in   : std_logic := '0';
    signal data_p_out     : std_logic_vector(7 downto 0);
    signal data_p_en_out  : std_logic;
    type data_array is array (0 to 3) of std_logic_vector(7 downto 0);
    signal data_vec : data_array := (
        0 => x"EE",
        1 => x"BE",
        2 => x"BB",
        3 => x"11"
    );

begin
      -- GERAÇÃO DE CLOCK DE 10ns (100 MHz)
    clk <= not clk after 5 ns;

    -- RESET
    rst <= '0'after 20 ns;
	
    ------------------------------------------------------------------------
    -- INSTÂNCIAS: TX E RX
    ------------------------------------------------------------------------
    duv: entity work.uart_tx
        port map (
            clock_in         => clk,
            reset_in         => rst,
            data_p_in        => data_p_in,
            data_p_en_in     => data_p_en_in,
            uart_rate_tx_sel => uart_rate_sel,
            uart_data_tx     => uart_line
        );

    rx: entity work.uart_rx
        port map (
            clock_in         => clk,
            reset_in         => rst,
            uart_data_rx     => uart_line,
            uart_rate_rx_sel => uart_rate_sel,
            data_p_out       => data_p_out,
            data_p_en_out    => data_p_en_out
        );

    ------------------------------------------------------------------------
    -- ESTÍMULO: ENVIO SEQUENCIAL DOS 4 BYTES
    ------------------------------------------------------------------------
    stim_proc: process
    begin
        -- aguarda término do reset
        wait for 20000 ns;

        for i in 0 to 3 loop
			report "-";
			wait for 10 ns;
            -- carrega e dispara envio
            data_p_in    <= data_vec(i);			
            data_p_en_in <= '1';
            wait for 10 ns;
            data_p_en_in <= '0';
            -- aguarda tempo suficiente para enviar start+8 bits+stop
            -- com divisor 1040: (1 start + 8 dados + 1 stop) * 1041 ciclos * 10 ns
            wait for (1 + 8 + 1) * 1041 * 10 ns;
        end loop;

        wait;  -- fim da simulação
    end process stim_proc;

    ------------------------------------------------------------------------
    -- CHECKPOINT: IMPRIME NO LOG CADA BYTE RECEBIDO
    ------------------------------------------------------------------------
    -- O Rx ja faz isso

end architecture tb;
