module top (
    input  wire        clk,
    input  wire [17:0] SW,
    input  wire [1:0]  BUTTON,
    
    output wire [7:0]  LCD_DATA,
    output wire        LCD_RS,
    output wire        LCD_RW,
    output wire        LCD_EN,
    output wire        LCD_ON,
    output wire        LCD_BLON
);

    wire power_pulse;
    wire send_pulse;
    
    button_handler button_power (
        .clk(clk),
        .button_pressed(BUTTON[0]),
        .pulse(power_pulse)
    );

    button_handler button_send (
        .clk(clk),
        .button_pressed(BUTTON[1]),
        .pulse(send_pulse)
    );

    wire        mem_wr_en;
    wire [3:0]  mem_wr_addr;
    wire [15:0] mem_wr_data;
    wire [3:0]  mem_rd_addr1;
    wire [3:0]  mem_rd_addr2;
    wire        mem_clear;
    wire [15:0] mem_rd_data1;
    wire [15:0] mem_rd_data2;

    wire [2:0]  alu_op;
    wire [15:0] alu_a;
    wire [15:0] alu_b;
    wire [15:0] alu_result;

    wire        lcd_on_internal;
    wire        lcd_update;
    wire [2:0]  out_op_code;
    wire [3:0]  out_dest_reg;
    wire [15:0] out_value;
    wire        out_show_reg;
    wire [1:0]  out_instr_type;
    wire        out_init_screen;

    assign LCD_ON = lcd_on_internal;
    assign LCD_BLON = lcd_on_internal;

    mini_cpu usar_cpu (
        .clk(clk),
        .SW(SW),
        .power_pulse(power_pulse),
        .send_pulse(send_pulse),
        
        .mem_wr_en(mem_wr_en),
        .mem_wr_addr(mem_wr_addr),
        .mem_wr_data(mem_wr_data),
        .mem_rd_addr1(mem_rd_addr1),
        .mem_rd_addr2(mem_rd_addr2),
        .mem_clear(mem_clear),
        .mem_rd_data1(mem_rd_data1),
        .mem_rd_data2(mem_rd_data2),
        
        .alu_op(alu_op),
        .alu_a(alu_a),
        .alu_b(alu_b),
        .alu_result(alu_result),
        
        .lcd_on(lcd_on_internal),
        .lcd_update(lcd_update),
        .out_op_code(out_op_code),
        .out_dest_reg(out_dest_reg),
        .out_value(out_value),
        .out_show_reg(out_show_reg),
        .out_instr_type(out_instr_type),
        .out_init_screen(out_init_screen)
    );

    alu usar_alu (
        .op(alu_op),
        .a(alu_a),
        .b(alu_b),
        .result(alu_result)
    );

    memory usar_memo (
        .clk(clk),
        .wr_en(mem_wr_en),
        .wr_addr(mem_wr_addr),
        .wr_data(mem_wr_data),
        .clear(mem_clear),
        .rd_addr1(mem_rd_addr1),
        .rd_addr2(mem_rd_addr2),
        .rd_data1(mem_rd_data1),
        .rd_data2(mem_rd_data2)
    );

    lcd_controller_top usar_lcd (
        .clk(clk),
        .lcd_on(lcd_on_internal),
        .update(lcd_update),
        .op_code(out_op_code),
        .dest_reg(out_dest_reg),
        .value(out_value),
        
        .lcd_data(LCD_DATA),
        .lcd_rs(LCD_RS),
        .lcd_rw(LCD_RW),
        .lcd_e(LCD_EN)
    );

endmodule