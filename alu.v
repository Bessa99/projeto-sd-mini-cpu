module alu(
    input wire [2:0]op,
    input wire [15:0]a,
    input wire [15:0]b,
    output reg [15:0]result
);

    localparam OP_ADD = 3'b001;
    localparam OP_ADDi = 3'b010;
    localparam OP_SUB = 3'b011;
    localparam OP_SUBi = 3'b100;
    localparam OP_MUL = 3'b101;

    always @(*)begin    
        case(op)
            OP_ADD,OP_ADDi : result=a+b;
            OP_SUB,OP_SUBi : result=a-b;
            OP_MUL : result=a*b;
            default : result=16'd0;
        endcase
    end
endmodule