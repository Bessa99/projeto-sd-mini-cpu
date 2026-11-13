module button_handler(
    input clk,
    input button_pressed,
    output pulse
);
    reg first_signal = 1'b1;
    reg second_signal = 1'b1;

    always @(posedge clk)begin
        first_signal <= button_pressed;
        second_signal <= first_signal;
    end

    reg stable_button = 1'b1;
    reg [19:0] debounce = 20'b0;

    always @(posedge clk)begin
        if (second_signal == stable_button)begin 
            debounce <= 20'b0;
        end 
        else begin 
            if (debounce == 20'd499999)begin
                debounce <= 20'b0;
                stable_button <= second_signal;
            end 
            else begin
                debounce <= debounce + 20'd1;
            end
        end 
    end 

    reg last_button_state = 1'b1;
    reg reg_pulse = 1'b0;

    always @(posedge clk)begin
        last_button_state <= stable_button;
        reg_pulse <= ~stable_button && last_button_state;
        end 

    assign pulse = reg_pulse;

endmodule 