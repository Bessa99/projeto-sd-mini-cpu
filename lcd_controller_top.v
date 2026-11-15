// ---------------------------------------------------------------------------
// Módulo: lcd_controller_top
// Função: Controlador principal do LCD.
//         Aguarda o módulo lcd_init_hd44780 terminar a inicialização e,
//         em seguida, escreve uma mensagem fixa na primeira linha do LCD.
//
// Estilo de FSM:
//   - Bloco 1 (sequencial): state, delay_cnt, msg_index
//   - Bloco 2 (combinacional): next_state, next_delay_cnt, next_msg_index
//   - Bloco 3 (combinacional): geração de saídas (Moore)
//
// Dependência: módulo lcd_init_hd44780 (já com sua própria FSM em 3 always).
// ---------------------------------------------------------------------------
module lcd_controller_top (
    input  wire       clk,
    input  wire       lcd_on,

    // Sinais de entrada do processador
    input  wire        update,
    input  wire [2:0]  op_code,
    input  wire [3:0]  dest_reg,
    input  wire [15:0] value,
    input  wire        show_reg,
    input  wire        init_screen,

    // Saídas para o LCD
    output wire  [7:0] lcd_data,
    output wire        lcd_rs,
    output wire        lcd_rw,
    output wire        lcd_e
);

    // -----------------------------------------------------------------------
    // Instância do módulo de inicialização
    // -----------------------------------------------------------------------
    wire [7:0] init_data;
    wire       init_rs;
    wire       init_rw;
    wire       init_e;
    wire       init_done;

    lcd_init_hd44780 lcd_init (
        .clk      (clk),
        .lcd_on   (lcd_on),
        .done     (init_done),
        .lcd_data (init_data),
        .lcd_rs   (init_rs),
        .lcd_rw   (init_rw),
        .lcd_e    (init_e)
    );

    // -----------------------------------------------------------------------
    // MUX: decide quem controla o LCD (init ou controlador principal)
    // -----------------------------------------------------------------------
    wire controller_mode = init_done;
    assign lcd_data = (controller_mode == 1'b0) ? init_data : wr_data;
    assign lcd_rs   = (controller_mode == 1'b0) ? init_rs   : wr_rs;
    assign lcd_rw   = (controller_mode == 1'b0) ? init_rw   : wr_rw;
    assign lcd_e    = (controller_mode == 1'b0) ? init_e    : wr_e;

    // -----------------------------------------------------------------------
    // Formatação Combinacional
    // -----------------------------------------------------------------------
    reg [127:0] fmt_line1;
    reg [127:0] fmt_line2;
    reg [79:0]  fmt_op_name;

    always @(*) begin
        case (op_code)
            3'b000:  fmt_op_name = "LOAD      ";
            3'b001:  fmt_op_name = "ADD       ";
            3'b010:  fmt_op_name = "ADDI      ";
            3'b011:  fmt_op_name = "SUB       ";
            3'b100:  fmt_op_name = "SUBI      ";
            3'b101:  fmt_op_name = "MUL       ";
            3'b110:  fmt_op_name = "CLR       ";
            3'b111:  fmt_op_name = "DPL       ";
            default: fmt_op_name = "          ";
        endcase
    end

    wire [47:0] fmt_reg_name = {"[", 8'h30 + dest_reg[3], 8'h30 + dest_reg[2], 8'h30 + dest_reg[1], 8'h30 + dest_reg[0], "]"};

    wire        fmt_negative  = value[15];
    wire [15:0] fmt_abs_value = fmt_negative ? (~value + 16'd1) : value;

    wire [3:0] fmt_n0 =  fmt_abs_value               % 10;
    wire [3:0] fmt_n1 = (fmt_abs_value / 16'd10)     % 10;
    wire [3:0] fmt_n2 = (fmt_abs_value / 16'd100)    % 10;
    wire [3:0] fmt_n3 = (fmt_abs_value / 16'd1000)   % 10;
    wire [3:0] fmt_n4 = (fmt_abs_value / 16'd10000)  % 10;

    wire [47:0] fmt_n_name = {fmt_negative ? "-" : "+", 8'h30 + fmt_n4, 8'h30 + fmt_n3, 8'h30 + fmt_n2, 8'h30 + fmt_n1, 8'h30 + fmt_n0};

    always @(*) begin
        if (init_screen) begin
            fmt_line1 = "----------[----]";
            fmt_line2 = "          +00000";
        end else if (!show_reg) begin
            fmt_line1 = "CLR             ";
            fmt_line2 = "                ";
        end else begin
            fmt_line1 = {fmt_op_name, fmt_reg_name};
            fmt_line2 = {"          ", fmt_n_name};
        end
    end

    // =======================================================================
    // BLOCO 2: Buffers de Captura
    // =======================================================================
    reg         pending_update = 1'b0;
    reg [127:0] buf_line1      = 128'd0;
    reg [127:0] buf_line2      = 128'd0;

    // -----------------------------------------------------------------------
    // Temporizações para escrita de caracteres (ajustar ao clock real)
    // -----------------------------------------------------------------------
    // Exemplo para 50 MHz:
    localparam [31:0] DELAY_WRITE = 32'd2000; // ~40 us
    localparam [31:0] DELAY_PULSE = 32'd50;   // ~1 us

    // -----------------------------------------------------------------------
    // Estados da FSM principal
    // -----------------------------------------------------------------------
    localparam [2:0]
        S_WAIT_INIT  = 3'd0,
        S_IDLE       = 3'd1,
        S_PREPARE    = 3'd2,
        S_PULSE_E    = 3'd3,
        S_WAIT       = 3'd4;

    reg [2:0]  state, next_state;
    reg [31:0] delay_cnt, next_delay_cnt;
    reg [5:0]  step, next_step;  // vai de 0 a 33
    reg        start_write;

    reg [7:0] cur_data;
    reg       cur_rs;
    always @(*) begin
        cur_data = 8'h00;
        cur_rs   = 1'b0;
        if (step == 6'd0) begin
            cur_data = 8'h80; // Comando: Linha 1
        end else if (step <= 6'd16) begin
            cur_rs   = 1'b1;
            cur_data = buf_line1[127 - 8*(step - 1) -: 8];
        end else if (step == 6'd17) begin
            cur_data = 8'hC0; // Comando: Linha 2
        end else begin
            cur_rs   = 1'b1;
            cur_data = buf_line2[127 - 8*(step - 18) -: 8];
        end
    end

    // =======================================================================
    // 1) BLOCO SEQUENCIAL: registra estado, contador e índice da mensagem
    // =======================================================================
    always @(posedge clk) begin
        if (!lcd_on) begin
            state      <= S_WAIT_INIT;
            delay_cnt  <= 32'd0;
            step           <= 6'd0;
            pending_update <= 1'b0;
        end else begin
            state      <= next_state;
            delay_cnt  <= next_delay_cnt;
            step      <= next_step;

            // Memoriza pedido de update se estiver livre
            if (update && state == S_IDLE)
                pending_update <= 1'b1;
            else if (start_write)
                pending_update <= 1'b0;

            // Tira a foto dos dados
            if (start_write) begin
                buf_line1 <= fmt_line1;
                buf_line2 <= fmt_line2;
            end
        end
    end

    // =======================================================================
    // 2) BLOCO COMBINACIONAL: cálculo do próximo estado/contador/índice
    // =======================================================================
    always @(*) begin
        // valores padrão
        next_state     = state;
        next_delay_cnt = delay_cnt;
        next_step      = step;
        start_write    = 1'b0;

        case (state)
            // ---------------------------------------------------------------
            // Espera a inicialização do LCD ser concluída
            // ---------------------------------------------------------------
            S_WAIT_INIT: begin
                if (init_done) begin
                    next_state     = S_IDLE;
                end
            end

            S_IDLE: begin
                if (pending_update) begin
                    start_write = 1'b1;
                    next_step   = 6'd0;
                    next_state  = S_PREPARE;
                end
            end

            S_PREPARE: begin
                next_delay_cnt = DELAY_PULSE;
                next_state     = S_PULSE_E;
            end

            // ---------------------------------------------------------------
            // Gera pulso de Enable
            // ---------------------------------------------------------------
            S_PULSE_E: begin
                if (delay_cnt > 0) begin
                    next_delay_cnt = delay_cnt - 1;
                end else begin
                    next_state     = S_WAIT;
                    next_delay_cnt = DELAY_WRITE;
                end
            end

            // ---------------------------------------------------------------
            // Espera o tempo de escrita do caractere
            // ---------------------------------------------------------------
            S_WAIT: begin
                if (delay_cnt > 0) begin
                    next_delay_cnt = delay_cnt - 1;
                end else begin
                    if (step == 6'd33) begin
                        next_state = S_IDLE; // Terminou de escrever as duas linhas
                    end else begin
                        next_step  = step + 6'd1;
                        next_state = S_PREPARE;
                    end
                end
            end

            default: next_state = S_WAIT_INIT;
        endcase
    end

    // =======================================================================
    // 3) BLOCO COMBINACIONAL: geração das saídas
    //     - start_init
    //     - sinais de escrita (wr_rs, wr_rw, wr_e, wr_data)
// =======================================================================
    reg [7:0] wr_data;
    reg       wr_rs;
    reg       wr_rw;
    reg       wr_e;

    always @(*) begin
        wr_data = 8'h00;
        wr_rs   = 1'b0;
        wr_rw   = 1'b0;
        wr_e    = 1'b0;

        case (state)
            // Durante a escrita da mensagem, usamos os caracteres da array
            S_PREPARE, S_WAIT: begin
                wr_data = cur_data;
                wr_rs   = cur_rs;
                wr_e    = 1'b0;
            end

            S_PULSE_E: begin
                wr_data = cur_data;
                wr_rs   = cur_rs;
                wr_e    = 1'b1; // Pulso!
            end

            default: begin
            end
        endcase
    end
endmodule
