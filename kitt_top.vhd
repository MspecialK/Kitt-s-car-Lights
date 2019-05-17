library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity kitt_top is
    Generic(
        SHIFT_CLK_DIV       :   positive    := 10000000;     -- valore iniziale per il divisore di frequanza per generare l'impulso di shift
        PWM_CLK_DIV         :   positive    := 100000;       -- valore iniziale per il divisore di frequanza per generare il pwm
        KITT_LENGTH         :   positive    := 16;           -- numero di led totali sui quali effettuare il gioco luminoso
        TAIL_LENGTH         :   positive    := 4             -- valore iniziale della lunghezza della coda     
    );
    Port(       
        -- ingresso di clock
        clk     :   IN  STD_LOGIC;
        -- vettore di uscita
        leds    :   OUT STD_LOGIC_VECTOR(0 TO (KITT_LENGTH - 1));
        -- ingresso per aumentare la velocità (mappato sul bottone destro BTNR)
        inc_speed     :   IN STD_LOGIC;
        -- ingresso per diminuire la velocità (mappato sul bottone sinistro BTNL)
        dec_speed     :   IN STD_LOGIC;
        -- ingresso per aumentare la lunghezza della coda (mappato sul bottone alto BTNU)
        inc_tail     :   IN STD_LOGIC;
        -- ingresso per diminuire la lunghezza della coda (mappato sul bottone basso BTND)
        dec_tail     :   IN STD_LOGIC
    );
end kitt_top;

warchitecture Behavioral of kitt_top is
    -- Segnali

    -- registro "circolare" che contiene un solo bit '1' la cui posizione rappresenta il led dal quale
    -- far partire la coda. La lunghezza del registro è doppia rispetto al numero di uscite desiderate: Al posto che cambiare direzione
    -- allo scorrimento, le uscite desiderate sono ottenute facendo lo OR bit per bit tra le due metà del registro (la seconda metà
    -- del registro viene swappata).
    signal first_register   :   STD_LOGIC_VECTOR(0 TO (KITT_LENGTH * 2) - 1) := (0 => '1', others => '0');    
    
    -- registro per la generazione dell'effetto coda: viene inizialmanete caricato con il contenuto di first_register.
    -- Successivamente il bit '1' presente viene copiato, passo dopo passo, nelle X celle antecedenti quella contenente il bit '1' originale.
    -- Raggiunte le X copie (X=lunghezza coda) il registro viene nuovamente caricato col valore di first_register.
    signal kitt_register    :   STD_LOGIC_VECTOR(0 TO (KITT_LENGTH * 2) - 1) := (0 => '1', Others => '0');
    

begin

-- aggiorno le uscite
gen: for i in 0 to (KITT_LENGTH - 1) generate
  leds(i) <= kitt_register(i) or kitt_register(((KITT_LENGTH * 2) - 1) - i);
end generate;

shift_reg  :  process(clk)
    -- contatore del divisore della frequenza di clock per generare l'impulso di shift
    variable shift_clk_div_cnt      :   integer := 0;
    
    -- soglia (threshold) di reset del contatore clk_div_cnt
    variable shift_clk_div_thrs     :   integer := SHIFT_CLK_DIV;
    
    -- contatore del divisore della frequenza di clock per generareil pwm
    variable pwm_clk_div_cnt        :   integer := 0;

    -- contatore lunghezza coda: conta quante volte copiare-traslando il bit nel reistro kitt_register
    variable tail_cnt               :   integer := 0;
    
    -- tiene in memoria la lunghezza della coda attuale
    variable tail_cnt_thrs          :   integer := TAIL_LENGTH;
    
    -- indica che è già stato gestito il segnale inc_speed
    variable inc_speed_done_flag    :   boolean := false;
    
    -- indica che è già stato gestito il segnale dec_speed
    variable dec_speed_done_flag    :   boolean := false;
    
    -- indica che è già stato gestito il segnale inc_tail
    variable inc_tail_done_flag     :   boolean := false;
    
    -- indica che è già stato gestito il segnale dec_tail
    variable dec_tail_done_flag     :   boolean := false;
begin
    
    if rising_edge(clk) then
        -- aggiorno il contatore del divisore della frequenza di clock per generare l'impulso di shift
        shift_clk_div_cnt := shift_clk_div_cnt + 1;
        
        -- controllo se devo shiftare la coda
        if (shift_clk_div_cnt > shift_clk_div_thrs) then
            -- ogni volta che entro in questo if devo shiftare verso destra (ruotando) il registro first_register che contiene il
            -- bit da cui verrà generata la coda...
            first_register <= '0' & first_register(0 TO (KITT_LENGTH*2)-2);
            first_register(0) <= first_register((KITT_LENGTH*2)-1);
            shift_clk_div_cnt := 0;
        end if;
        
        -- aggiorno il contatore del divisore della frequenza di clock per generare il pwm
        pwm_clk_div_cnt := pwm_clk_div_cnt + 1;
        
        -- controllo se devo aggiornare il pwm
        if (pwm_clk_div_cnt > PWM_CLK_DIV)  then
            -- ogni volta che entro in questo if devo ""spalmare"" verso sinistra (ruotando) il registro kitt_register che contiene i
            -- bit che genereranno la coda...
            -- questa operazione va fatta per un numero di volte pari alla lungezza della coda, dopodichè dovrò ricaricare il
            -- registro col valore iniziale
            tail_cnt := tail_cnt + 1;
            if (tail_cnt >= tail_cnt_thrs) then
                -- devo resettare il registro kitt_register
                kitt_register <= first_register;
                tail_cnt := 0;
            else
                -- ""spalmo"" verso sinistra (ruotando) il registro kitt_register
                kitt_register <= kitt_register or (kitt_register(1 TO (KITT_LENGTH*2)-1) & '0');
                kitt_register((KITT_LENGTH*2)-1) <= kitt_register(0);
            end if;
            pwm_clk_div_cnt := 0;
        end if;
        
        -- gestione del segnale inc_speed
        if ((inc_speed = '1') and (inc_speed_done_flag = false)) then
            if (shift_clk_div_thrs > 1000000) then
                shift_clk_div_thrs := shift_clk_div_thrs - 500000; 
            end if;
            inc_speed_done_flag := true;
        elsif (inc_speed = '0') then
            inc_speed_done_flag := false;
        end if;
        
        -- gestione del segnale dec_speed
        if ((dec_speed = '1') and (dec_speed_done_flag = false)) then
            if (shift_clk_div_thrs < 30000000) then
                shift_clk_div_thrs := shift_clk_div_thrs + 500000; 
            end if;
            dec_speed_done_flag := true;
        elsif (dec_speed = '0') then
            dec_speed_done_flag := false;
        end if;
        
        -- gestione del segnale inc_tail
        if ((inc_tail = '1') and (inc_tail_done_flag = false)) then
            if (tail_cnt_thrs < KITT_LENGTH - 1) then
                tail_cnt_thrs := tail_cnt_thrs + 1;
            end if;
            inc_tail_done_flag := true;
        elsif (inc_tail = '0') then
            inc_tail_done_flag := false;
        end if;
        
        -- gestione del segnale dec_tail
        if ((dec_tail = '1') and (dec_tail_done_flag = false)) then
            if (tail_cnt_thrs > 1) then
                tail_cnt_thrs := tail_cnt_thrs - 1;
            end if;
            dec_tail_done_flag := true;
        elsif (dec_tail = '0') then
            dec_tail_done_flag := false;
        end if;
        
    end if;       

end process;

end Behavioral;
