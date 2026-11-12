module lcd_display #(
	parameter CYC = 50000            
)(
	input clk,
	input [1:0] command,
	input [3:0] opcode,
	input [3:0] addr,
	input [15:0] data_addr,
	output reg EN, RS, done_display, 
	output RW,
	output reg [7:0] data
);

assign RW = 1'b0;                    

parameter WRITE = 0, WAIT = 1; 
parameter OFF = 0, UPD = 1, IDLE = 2;
parameter INIT = 1, UPDATE = 2, SHOW = 3, WAIT_UP = 4; 
parameter LOAD = 0, ADD = 1, ADDI = 2, SUB = 3, SUBI = 4, MUL = 5, CLEAR = 6, DISPLAY = 7; 

reg state = WRITE;
reg [5:0] instructions = 0;

reg [7:0] show_opcode [3:0];
reg [7:0] show_addr [3:0];
reg [7:0] show_sign;                 
reg [14:0] num_data = 0;             
reg show_params = 1;                 
reg [2:0] operation = OFF;
reg upd_pending = 0;                 
reg [1:0] cmd_prev = 0;
wire upd_edge = (command == UPD) && (cmd_prev != UPD);   

integer counter = 0;

wire [7:0] dig4 = (num_data / 10000) + 48;
wire [7:0] dig3 = ((num_data / 1000) % 10) + 48;
wire [7:0] dig2 = ((num_data / 100) % 10) + 48;
wire [7:0] dig1 = ((num_data / 10) % 10) + 48;
wire [7:0] dig0 = (num_data % 10) + 48;

function [7:0] p;
	input [7:0] c;
	p = show_params ? c : 8'h20;
endfunction

always @ (posedge clk) begin
	case (state)
		WRITE: begin
			if (counter == CYC - 1) begin
				counter <= 0;
				state <= WAIT;
			end else
				counter <= counter + 1;
		end
		WAIT: begin
			if (counter == CYC - 1) begin
				counter <= 0;
				state <= WRITE;
				if (operation == SHOW) begin
					if (instructions < 41) instructions <= instructions + 1;
					else instructions <= 41;
				end else 
					instructions <= 0;
			end else
				counter <= counter + 1;
		end
	endcase

	if (operation == INIT || operation == UPDATE) begin
		state <= WRITE;
		counter <= 0;
		instructions <= 0;
	end
end

always @(posedge clk) begin 
	cmd_prev <= command;
	if (upd_edge) upd_pending <= 1;         
	case(operation)
		OFF: begin
			upd_pending <= 0;
			operation <= (command == OFF)? operation : INIT;
		end
		INIT: operation <= (command == OFF)? OFF : SHOW;
		SHOW: begin operation <= (command == OFF)? OFF : (done_display)? WAIT_UP : operation; end
		UPDATE: operation <= (command == OFF)? OFF : SHOW; 
		WAIT_UP: begin
			if (command == OFF) operation <= OFF;
			else if (upd_edge || upd_pending) begin
				operation <= UPDATE;
				upd_pending <= 0;
			end
		end
	endcase
end

always @ (posedge clk) begin
	case (state) 
		WRITE: EN <= 1;
		WAIT: EN <= 0;
	endcase
	
	case (operation)
		OFF: begin
			done_display <= 0;
			data <= 8'h08; RS <= 0;      
		end
		INIT: begin
			show_opcode[3] <= 8'h2D; 
			show_opcode[2] <= 8'h2D; 
			show_opcode[1] <= 8'h2D; 
			show_opcode[0] <= 8'h2D; 
			show_addr[3] <= 8'h2D; 
			show_addr[2] <= 8'h2D; 
			show_addr[1] <= 8'h2D; 
			show_addr[0] <= 8'h2D; 
			show_sign <= 8'h2B;    
			num_data <= 0;         
			show_params <= 1;
		end
		UPDATE: begin
			case (opcode)
				LOAD: begin 
					show_opcode[3] <= 8'h4C; 
					show_opcode[2] <= 8'h4F; 
					show_opcode[1] <= 8'h41; 
					show_opcode[0] <= 8'h44; 
				end
				ADD: begin 
					show_opcode[3] <= 8'h41; 
					show_opcode[2] <= 8'h44; 
					show_opcode[1] <= 8'h44; 
					show_opcode[0] <= 8'h20; 
				end
				ADDI: begin 
					show_opcode[3] <= 8'h41; 
					show_opcode[2] <= 8'h44; 
					show_opcode[1] <= 8'h44; 
					show_opcode[0] <= 8'h49; 
				end
				SUB: begin 
					show_opcode[3] <= 8'h53; 
					show_opcode[2] <= 8'h55; 
					show_opcode[1] <= 8'h42; 
					show_opcode[0] <= 8'h20; 
				end
				SUBI: begin 
					show_opcode[3] <= 8'h53; 
					show_opcode[2] <= 8'h55; 
					show_opcode[1] <= 8'h42; 
					show_opcode[0] <= 8'h49; 
				end
				MUL: begin 
					show_opcode[3] <= 8'h4D; 
					show_opcode[2] <= 8'h55; 
					show_opcode[1] <= 8'h4C; 
					show_opcode[0] <= 8'h20; 
				end
				CLEAR: begin 
					show_opcode[3] <= 8'h43; 
					show_opcode[2] <= 8'h4C; 
					show_opcode[1] <= 8'h52; 
					show_opcode[0] <= 8'h20; 
				end
				DISPLAY: begin 
					show_opcode[3] <= 8'h44; 
					show_opcode[2] <= 8'h50; 
					show_opcode[1] <= 8'h4C; 
					show_opcode[0] <= 8'h20; 
				end
			endcase

			show_params <= (opcode != CLEAR);         

			show_addr[0] <= (addr[0] == 1) ? 8'h31 : 8'h30;
			show_addr[1] <= (addr[1] == 1) ? 8'h31 : 8'h30;  
			show_addr[2] <= (addr[2] == 1) ? 8'h31 : 8'h30;  
			show_addr[3] <= (addr[3] == 1) ? 8'h31 : 8'h30;

			num_data <= data_addr[14:0];
			show_sign <= (data_addr[15] && data_addr[14:0] != 0) ? 8'h2D : 8'h2B;
		end
		
		SHOW: begin
			case (instructions)
				0: begin data <= 8'h38; RS <= 0; end 
				1: begin data <= 8'h0C; RS <= 0; end 
				2: begin data <= 8'h01; RS <= 0; end 
				3: begin data <= 8'h02; RS <= 0; end 
				4: begin data <= 8'h06; RS <= 0; end 
				5: begin data <= show_opcode[3]; RS <= 1; end 
				6: begin data <= show_opcode[2]; RS <= 1; end
				7: begin data <= show_opcode[1]; RS <= 1; end 
				8: begin data <= show_opcode[0]; RS <= 1; end 
				9: begin data <= 8'h14; RS <= 0; end 
				10: begin data <= 8'h14; RS <= 0; end 
				11: begin data <= 8'h14; RS <= 0; end 
				12: begin data <= 8'h14; RS <= 0; end 
				13: begin data <= 8'h14; RS <= 0; end 
				14: begin data <= 8'h14; RS <= 0; end 
				15: begin data <= p(8'h5B); RS <= 1; end 
				16: begin data <= p(show_addr[3]); RS <= 1; end 
				17: begin data <= p(show_addr[2]); RS <= 1; end
				18: begin data <= p(show_addr[1]); RS <= 1; end 
				19: begin data <= p(show_addr[0]); RS <= 1; end 
				20: begin data <= p(8'h5D); RS <= 1; end 
				21: begin data <= 8'hC0; RS <= 0; end 
				22: begin data <= 8'h06; RS <= 0; end 
				23: begin data <= 8'h14; RS <= 0; end 
				24: begin data <= 8'h14; RS <= 0; end 
				25: begin data <= 8'h14; RS <= 0; end 
				26: begin data <= 8'h14; RS <= 0; end 
				27: begin data <= 8'h14; RS <= 0; end 
				28: begin data <= 8'h14; RS <= 0; end 
				29: begin data <= 8'h14; RS <= 0; end 
				30: begin data <= 8'h14; RS <= 0; end 
				31: begin data <= 8'h14; RS <= 0; end 
				32: begin data <= 8'h14; RS <= 0; end 
				33: begin data <= p(show_sign); RS <= 1; end
				34: begin data <= p(dig4); RS <= 1; end
				35: begin data <= p(dig3); RS <= 1; end
				36: begin data <= p(dig2); RS <= 1; end
				37: begin data <= p(dig1); RS <= 1; end
				38: begin data <= p(dig0); RS <= 1; end
				39: begin data <= 8'h02; RS <= 0; end 
				40: begin data <= 8'h06; RS <= 0; end 
				default: done_display <= 1;
			endcase
		end
		WAIT_UP: done_display <= 0;
	endcase
end

endmodule