module mini_cpu (
    input  wire        clk,
    input  wire [17:0] SW,
    input  wire        power_pulse,
    input  wire        send_pulse,

    // MEMO
    output reg         mem_wr_en,
    output reg  [3:0]  mem_wr_addr,
    output reg  [15:0] mem_wr_data,
    output reg  [3:0]  mem_rd_addr1,
    output reg  [3:0]  mem_rd_addr2,
    output reg         mem_clear,
    input  wire [15:0] mem_rd_data1,
    input  wire [15:0] mem_rd_data2,

    // ALU
    output reg  [2:0]  alu_op,
    output reg  [15:0] alu_a,
    output reg  [15:0] alu_b,
    input  wire [15:0] alu_result,

    // LCD
    output reg         lcd_on,
    output reg         lcd_update,
    output reg  [2:0]  out_op_code,
    output reg  [3:0]  out_dest_reg,
    output reg  [15:0] out_value,
    output reg         out_show_reg,
    output reg  [1:0]  out_instr_type,
    output reg         out_init_screen
);

    parameter S_OFF       = 0,
              S_IDLE      = 1,
              S_DECODE    = 2,
              S_EXECUTE   = 3,
              S_WRITEBACK = 4,
              S_DISPLAY   = 5;

    localparam OP_LOAD    = 3'b000,
               OP_ADD     = 3'b001,
               OP_ADDI    = 3'b010,
               OP_SUB     = 3'b011,
               OP_SUBI    = 3'b100,
               OP_MUL     = 3'b101,
               OP_CLEAR   = 3'b110,
               OP_DISPLAY = 3'b111;

    reg [2:0]  state = S_OFF;
    reg [17:0] ir    = 18'd0;   

    wire [2:0]  f_op   = ir[17:15];
    wire [3:0]  f_dest = ir[14:11];
    wire [3:0]  f_src1 = ir[10:7];
    wire [3:0]  f_src2 = ir[6:3];
    wire        f_sign = ir[6];
    wire [5:0]  f_mag  = ir[5:0];
    wire [15:0] f_imm  = f_sign ? (~{10'd0, f_mag} + 16'd1) : {10'd0, f_mag};

    initial begin
        lcd_on          = 1'b0;           
        lcd_update      = 1'b0;
        mem_wr_en       = 1'b0;        
        mem_clear       = 1'b0;
        mem_wr_addr     = 4'd0;      
        mem_wr_data     = 16'd0;
        mem_rd_addr1    = 4'd0;     
        mem_rd_addr2    = 4'd0;
        alu_op          = 3'd0;           
        alu_a           = 16'd0;  
        alu_b           = 16'd0;
        out_op_code     = 3'd0;      
        out_dest_reg    = 4'd0;  
        out_value       = 16'd0;
        out_show_reg    = 1'b1;     
        out_instr_type  = 2'd0;
        out_init_screen = 1'b1;
    end

    always @(posedge clk) begin
        lcd_update <= 1'b0;
        mem_wr_en  <= 1'b0;
        mem_clear  <= 1'b0;

        if (power_pulse) begin
            if (state == S_OFF) begin
                state           <= S_IDLE;
                lcd_on          <= 1'b1;
                out_init_screen <= 1'b1;
                lcd_update      <= 1'b1;
                mem_clear       <= 1'b1;
            end else begin
                state  <= S_OFF;
                lcd_on <= 1'b0;
            end
        end else begin
            case (state)
                S_IDLE: begin
                    if (send_pulse && lcd_on) begin
                        ir              <= SW;
                        out_init_screen <= 1'b0;
                        state           <= S_DECODE;
                    end
                end

                S_DECODE: begin
                    out_op_code   <= f_op;
                    out_dest_reg  <= f_dest;
                    out_show_reg  <= (f_op != OP_CLEAR);
                    mem_rd_addr1  <= (f_op == OP_DISPLAY) ? f_dest : f_src1;  
                    mem_rd_addr2  <= f_src2;
                    alu_op        <= f_op;
                    state         <= S_EXECUTE;
                end

                S_EXECUTE: begin
                    alu_a <= mem_rd_data1;
                    alu_b <= (f_op == OP_ADD || f_op == OP_SUB) ? mem_rd_data2 : f_imm;
                    state <= S_WRITEBACK;
                end

                S_WRITEBACK: begin
                    case (f_op)
                        OP_LOAD: begin
                            mem_wr_en   <= 1'b1;
                            mem_wr_addr <= f_dest;
                            mem_wr_data <= f_imm;
                            out_value   <= f_imm;
                        end
                        OP_ADD, OP_ADDI, OP_SUB, OP_SUBI, OP_MUL: begin
                            mem_wr_en   <= 1'b1;
                            mem_wr_addr <= f_dest;
                            mem_wr_data <= alu_result;
                            out_value   <= alu_result;
                        end
                        OP_CLEAR: begin
                            mem_clear <= 1'b1;
                            out_value <= 16'd0;
                        end
                        OP_DISPLAY: begin
                            out_value <= mem_rd_data1;
                        end
                    endcase
                    state <= S_DISPLAY;
                end

                S_DISPLAY: begin
                    lcd_update <= 1'b1;
                    state      <= S_IDLE;
                end

                default: state <= S_OFF;
            endcase
        end
    end
endmodule