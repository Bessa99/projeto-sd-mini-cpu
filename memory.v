module memory(
    input wire clk,
    input wire wr_en,
    input wire [3:0] wr_addr,
    input wire [15:0] wr_data,
    input wire clear,
    input wire [3:0] rd_addr1,
    input wire [3:0] rd_addr2,
    output wire [15:0] rd_data1,
    output wire [15:0] rd_data2
);
    reg [15:0] regs [0:15];
    integer i;
    initial begin
        for(i = 0 ; i < 16; i=i+1)begin
            regs[i]=16'd0;
        end
    end
    assign rd_data1=regs[rd_addr1];
    assign rd_data2=regs[rd_addr2];
    always@(posedge clk)begin
        if(clear)begin
            for(i=0; i<16 ; i=i+1)begin
                regs[i]<=16'd0;
            end  
        end else if(wr_en)begin
             regs[wr_addr]<=wr_data;
        end
    end
endmodule